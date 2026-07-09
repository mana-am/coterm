import Foundation
import Darwin
import os

nonisolated struct CotermTopProcessScopeCacheKey: Hashable {
    let pid: Int
    let startSeconds: Int
    let startMicroseconds: Int
}

private nonisolated struct CotermTopProcessScopeCacheValue {
    // nil means "this process was probed and has no coterm scope". A negative entry
    // is honored as a hit only until `negativeExpiresAtNanos`, so a non-coterm
    // process is re-probed at most once per TTL window instead of on every
    // system.top poll. Positive entries never expire (`negativeExpiresAtNanos` is
    // ignored when `scope != nil`): a coterm scope comes from inherited environment
    // or a stable argv and does not disappear for the process lifetime.
    let scope: CotermTopProcessScope?
    let negativeExpiresAtNanos: UInt64
}

// How long a "no coterm scope" result stays cached before the process is probed
// again. The scope is derived from argv/environment, which an `exec` can change
// without changing the pid or process start time (the cache key), so a process
// first sampled in its fork-before-exec window, or one that execs into a
// `coterm hooks … monitor` later, must be re-probed eventually or it would never
// be attributed. The TTL bounds that attribution latency while still collapsing
// the per-poll sysctl storm for the steady-state majority of non-coterm processes.
private nonisolated let cotermTopNegativeScopeTTLNanoseconds: UInt64 = 15 * 1_000_000_000

// Result of probing a single process for its coterm scope. `resolved` means the
// probe completed (the scope may legitimately be absent) and is safe to cache.
// `unavailable` means a transient failure (process exited mid-probe, pid reuse,
// or a failed sysctl) and must NOT be cached so the next poll retries.
nonisolated enum CotermTopProcessScopeProbeResult: Equatable {
    case resolved(CotermTopProcessScope?)
    case unavailable
}

// CotermTopProcessSnapshot.capture is intentionally synchronous because it backs
// both async task-manager sampling and sync v2 system.top socket handling. Keep
// this tiny lock isolated to dictionary reads/writes; procargs/sysctl work must
// happen outside the critical section.
private nonisolated let cotermTopScopeCache = OSAllocatedUnfairLock(
    initialState: [CotermTopProcessScopeCacheKey: CotermTopProcessScopeCacheValue]()
)

nonisolated extension CotermTopProcessSnapshot {
    static func scopeCacheKey(from kinfo: kinfo_proc) -> CotermTopProcessScopeCacheKey {
        let startTime = kinfo.kp_proc.p_un.__p_starttime
        return CotermTopProcessScopeCacheKey(
            pid: Int(kinfo.kp_proc.p_pid),
            startSeconds: Int(startTime.tv_sec),
            startMicroseconds: Int(startTime.tv_usec)
        )
    }

    static func scopeCacheKey(from bsdInfo: proc_bsdinfo) -> CotermTopProcessScopeCacheKey {
        CotermTopProcessScopeCacheKey(
            pid: Int(bsdInfo.pbi_pid),
            startSeconds: Int(bsdInfo.pbi_start_tvsec),
            startMicroseconds: Int(bsdInfo.pbi_start_tvusec)
        )
    }

    static func cachedCotermScope(
        for pid: Int,
        cacheKey: CotermTopProcessScopeCacheKey,
        nowNanoseconds: UInt64,
        probe: (Int, CotermTopProcessScopeCacheKey) -> CotermTopProcessScopeProbeResult = CotermTopProcessSnapshot.cotermScopeProbe
    ) -> CotermTopProcessScope? {
        if let cached = cotermTopScopeCache.withLock({ cache in cache[cacheKey] }) {
            if let scope = cached.scope {
                // Positive results never expire: a discovered coterm scope is stable.
                return scope
            }
            if nowNanoseconds < cached.negativeExpiresAtNanos {
                // Negative result still within its TTL: honor the cached miss.
                return nil
            }
            // Negative TTL expired: fall through and re-probe in case the process
            // execed into a coterm-scoped command since it was last sampled.
        }

        switch probe(pid, cacheKey) {
        case .resolved(let scope):
            // Cache the resolved result. Positive scopes are kept indefinitely;
            // negative scopes are kept only until the TTL elapses so a later exec
            // is eventually attributed. The key is pruned to live pids each
            // capture, so a recycled pid gets a fresh key.
            //
            // capture() runs concurrently (async task-manager sampling and sync
            // system.top socket handling), and the probe happened outside the
            // lock. Never let a stale negative from an older capture clobber a
            // positive scope a newer capture already discovered for the same
            // process: if we probed nil but a positive entry now exists, keep and
            // return it.
            return cotermTopScopeCache.withLock { cache -> CotermTopProcessScope? in
                if scope == nil, let existing = cache[cacheKey], let existingScope = existing.scope {
                    return existingScope
                }
                cache[cacheKey] = CotermTopProcessScopeCacheValue(
                    scope: scope,
                    negativeExpiresAtNanos: nowNanoseconds &+ cotermTopNegativeScopeTTLNanoseconds
                )
                return scope
            }
        case .unavailable:
            // Transient failure: do not cache, retry on the next poll.
            return nil
        }
    }

    static func pruneCotermScopeCache(activeKeys: Set<CotermTopProcessScopeCacheKey>) {
        cotermTopScopeCache.withLock { cache in
            cache = cache.filter { activeKeys.contains($0.key) }
        }
    }

    // Probes a single process for its coterm scope via sysctl.
    //
    // `KERN_PROCARGS2` can fail two very different ways: transiently, because the
    // process exited mid-probe or its pid was reused (then `kinfoProc` no longer
    // matches the expected start-time key), or permanently, because the process
    // belongs to another user / is protected (the kernel denies procargs for the
    // process's whole life). We must cache the permanent case as a definitive
    // "no readable coterm scope" — those processes are not coterm-scoped and stay in
    // `activeKeys`, so leaving them uncached would re-run this sysctl fan-out on
    // every poll. We must NOT cache the transient case, so a process that is
    // simply mid-exec is retried.
    //
    // The discriminator is liveness: if a procargs read fails but the process is
    // still alive with the same start time, the failure is a permanent denial and
    // resolves to nil; otherwise it raced with exit/reuse and is `.unavailable`.
    static func cotermScopeProbe(
        for pid: Int,
        expectedCacheKey: CotermTopProcessScopeCacheKey
    ) -> CotermTopProcessScopeProbeResult {
        guard processMatchesKey(pid, expectedCacheKey) else {
            return .unavailable
        }

        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, Int32(pid)]
        var size: size_t = 0
        guard sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0,
              size > MemoryLayout<Int32>.size else {
            // Sizing failed: permanent denial if still alive, else exit race.
            return processMatchesKey(pid, expectedCacheKey) ? .resolved(nil) : .unavailable
        }

        var buffer = [UInt8](repeating: 0, count: size)
        let success = buffer.withUnsafeMutableBytes { rawBuffer in
            sysctl(&mib, u_int(mib.count), rawBuffer.baseAddress, &size, nil, 0) == 0
        }
        guard success else {
            return processMatchesKey(pid, expectedCacheKey) ? .resolved(nil) : .unavailable
        }
        guard processMatchesKey(pid, expectedCacheKey) else {
            return .unavailable
        }

        return .resolved(cotermScope(fromKernProcArgs: Array(buffer.prefix(Int(size)))))
    }

    // True when `pid` is still the same process (same start time) as the key.
    private static func processMatchesKey(
        _ pid: Int,
        _ expectedCacheKey: CotermTopProcessScopeCacheKey
    ) -> Bool {
        guard let process = kinfoProc(for: pid) else { return false }
        return scopeCacheKey(from: process) == expectedCacheKey
    }

    static func cotermScope(fromKernProcArgs bytes: [UInt8]) -> CotermTopProcessScope? {
        guard let process = processArgumentsAndEnvironment(fromKernProcArgs: bytes) else {
            return nil
        }
        return cotermScope(arguments: process.arguments, environment: process.environment)
    }

    static func cotermScope(arguments: [String], environment: [String: String]) -> CotermTopProcessScope? {
        if let environmentScope = cotermScopeFromEnvironment(environment) {
            return environmentScope
        }
        if let hookScope = cotermHookMonitorScope(arguments: arguments) {
            return hookScope
        }
        return nil
    }

    private static func cotermScopeFromEnvironment(_ environment: [String: String]) -> CotermTopProcessScope? {
        let workspaceID = uuidValue(in: environment, keys: ["COTERM_WORKSPACE_ID", "COTERM_TAB_ID"])
        let surfaceID = uuidValue(in: environment, keys: ["COTERM_SURFACE_ID", "COTERM_PANEL_ID"])
        guard workspaceID != nil || surfaceID != nil else { return nil }
        return CotermTopProcessScope(
            workspaceID: workspaceID,
            surfaceID: surfaceID,
            attributionReason: "coterm-environment"
        )
    }

    private static func cotermHookMonitorScope(arguments: [String]) -> CotermTopProcessScope? {
        guard containsSubcommandPath(["hooks", "codex", "monitor"], in: arguments) else {
            return nil
        }
        let workspaceID = uuidOptionValue(in: arguments, names: ["--workspace"])
        let surfaceID = uuidOptionValue(in: arguments, names: ["--surface", "--panel"])
        guard workspaceID != nil || surfaceID != nil else { return nil }
        return CotermTopProcessScope(
            workspaceID: workspaceID,
            surfaceID: surfaceID,
            attributionReason: "coterm-hook-arguments"
        )
    }

    private static func containsSubcommandPath(_ path: [String], in arguments: [String]) -> Bool {
        let normalizedPath = path.map { $0.lowercased() }
        guard !normalizedPath.isEmpty, arguments.count >= normalizedPath.count + 1 else { return false }
        let executableName = URL(fileURLWithPath: arguments[0])
            .lastPathComponent
            .lowercased()
        guard executableName == "coterm" else { return false }
        let subcommands = arguments
            .dropFirst()
            .prefix(normalizedPath.count)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return Array(subcommands) == normalizedPath
    }

    private static func uuidValue(in environment: [String: String], keys: [String]) -> UUID? {
        for key in keys {
            guard let raw = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty,
                  let uuid = UUID(uuidString: raw) else {
                continue
            }
            return uuid
        }
        return nil
    }

    private static func uuidOptionValue(in arguments: [String], names: Set<String>) -> UUID? {
        for index in arguments.indices {
            let argument = arguments[index].trimmingCharacters(in: .whitespacesAndNewlines)
            for name in names {
                let prefix = "\(name)="
                guard argument.hasPrefix(prefix) else { continue }
                let raw = String(argument.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !raw.isEmpty, let uuid = UUID(uuidString: raw) else { continue }
                return uuid
            }

            guard names.contains(argument) else { continue }
            let valueIndex = arguments.index(after: index)
            guard valueIndex < arguments.endIndex else { continue }
            let raw = arguments[valueIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty, let uuid = UUID(uuidString: raw) else { continue }
            return uuid
        }
        return nil
    }

    private static func kinfoProc(for pid: Int) -> kinfo_proc? {
        guard pid > 0, pid <= Int(Int32.max) else { return nil }

        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, Int32(pid)]
        var process = kinfo_proc()
        var length = MemoryLayout<kinfo_proc>.stride
        let result = sysctl(&mib, u_int(mib.count), &process, &length, nil, 0)
        guard result == 0,
              length >= MemoryLayout<kinfo_proc>.stride,
              process.kp_proc.p_pid == pid_t(pid) else {
            return nil
        }
        return process
    }
}

nonisolated extension CotermTopProcessArguments {
    func matchesCotermScope(workspaceId: UUID, surfaceId: UUID) -> Bool {
        guard let scope = CotermTopProcessSnapshot.cotermScope(arguments: arguments, environment: environment) else {
            return false
        }
        return scope.workspaceID == workspaceId && scope.surfaceID == surfaceId
    }
}
