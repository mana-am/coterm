import Darwin
import XCTest

#if canImport(Coterm_DEV)
@testable import Coterm_DEV
#elseif canImport(Coterm)
@testable import Coterm
#endif

final class CotermTopProcessCPUTests: XCTestCase {
    func testOverflowSentinelReportsZeroCPUPercent() {
        let previous = CotermTopProcessCPUSample(
            totalTimeTicks: 100,
            sampledAtNanoseconds: 1_000
        )
        let current = CotermTopProcessCPUSample(
            totalTimeTicks: UInt64.max,
            sampledAtNanoseconds: 2_000
        )

        XCTAssertEqual(CotermTopProcessSnapshot.cpuPercent(current: current, previous: previous), 0)
    }

    func testCPUPercentagesHoldPreviousValueUntilFixedWindowElapses() {
        let key = CotermTopProcessScopeCacheKey(
            pid: 4_129_001,
            startSeconds: 1_000,
            startMicroseconds: 0
        )
        let activeKeys: Set<CotermTopProcessScopeCacheKey> = [key]

        _ = CotermTopProcessSnapshot.cpuPercentages(
            for: [
                key: CotermTopProcessCPUSample(
                    totalTimeTicks: 1_000,
                    sampledAtNanoseconds: 1_000_000_000
                )
            ],
            activeKeys: activeKeys,
            sampledAtNanoseconds: 1_000_000_000
        )

        let rapidPercentages = CotermTopProcessSnapshot.cpuPercentages(
            for: [
                key: CotermTopProcessCPUSample(
                    totalTimeTicks: 1_000_001_000,
                    sampledAtNanoseconds: 1_100_000_000
                )
            ],
            activeKeys: activeKeys,
            sampledAtNanoseconds: 1_100_000_000
        )

        XCTAssertEqual(rapidPercentages[key], 0)

        let fixedWindowPercentages = CotermTopProcessSnapshot.cpuPercentages(
            for: [
                key: CotermTopProcessCPUSample(
                    totalTimeTicks: 1_000_002_000,
                    sampledAtNanoseconds: 2_000_000_000
                )
            ],
            activeKeys: activeKeys,
            sampledAtNanoseconds: 2_000_000_000
        )

        XCTAssertGreaterThan(fixedWindowPercentages[key] ?? 0, 0)
    }

    func testExitedChildCPUPercentCarriesIntoActiveParentForOneSample() {
        let parentKey = CotermTopProcessScopeCacheKey(
            pid: 4_129_100,
            startSeconds: 1_000,
            startMicroseconds: 0
        )
        let childKey = CotermTopProcessScopeCacheKey(
            pid: 4_129_101,
            startSeconds: 1_000,
            startMicroseconds: 1
        )
        let activeParentAndChild: Set<CotermTopProcessScopeCacheKey> = [parentKey, childKey]

        _ = CotermTopProcessSnapshot.cpuPercentages(
            for: [
                parentKey: CotermTopProcessCPUSample(totalTimeTicks: 1_000, sampledAtNanoseconds: 10_000_000_000),
                childKey: CotermTopProcessCPUSample(totalTimeTicks: 1_000, sampledAtNanoseconds: 10_000_000_000),
            ],
            activeKeys: activeParentAndChild,
            parentKeysByKey: [childKey: parentKey],
            sampledAtNanoseconds: 10_000_000_000
        )
        let activePercentages = CotermTopProcessSnapshot.cpuPercentages(
            for: [
                parentKey: CotermTopProcessCPUSample(totalTimeTicks: 1_000, sampledAtNanoseconds: 11_000_000_000),
                childKey: CotermTopProcessCPUSample(totalTimeTicks: 1_000_001_000, sampledAtNanoseconds: 11_000_000_000),
            ],
            activeKeys: activeParentAndChild,
            parentKeysByKey: [childKey: parentKey],
            sampledAtNanoseconds: 11_000_000_000
        )

        XCTAssertGreaterThan(activePercentages[childKey] ?? 0, 0)

        let parentOnlyPercentages = CotermTopProcessSnapshot.cpuPercentages(
            for: [
                parentKey: CotermTopProcessCPUSample(totalTimeTicks: 1_000, sampledAtNanoseconds: 12_000_000_000),
            ],
            activeKeys: [parentKey],
            sampledAtNanoseconds: 12_000_000_000
        )

        XCTAssertGreaterThan(parentOnlyPercentages[parentKey] ?? 0, 0)
        XCTAssertNil(parentOnlyPercentages[childKey])
    }

    func testExitedChildCPUPercentDoesNotInflateHeldParentSample() {
        let parentKey = CotermTopProcessScopeCacheKey(
            pid: 4_129_200,
            startSeconds: 1_000,
            startMicroseconds: 0
        )
        let childKey = CotermTopProcessScopeCacheKey(
            pid: 4_129_201,
            startSeconds: 1_000,
            startMicroseconds: 1
        )
        let activeParentAndChild: Set<CotermTopProcessScopeCacheKey> = [parentKey, childKey]

        _ = CotermTopProcessSnapshot.cpuPercentages(
            for: [
                parentKey: CotermTopProcessCPUSample(totalTimeTicks: 1_000, sampledAtNanoseconds: 20_000_000_000),
                childKey: CotermTopProcessCPUSample(totalTimeTicks: 1_000, sampledAtNanoseconds: 20_000_000_000),
            ],
            activeKeys: activeParentAndChild,
            parentKeysByKey: [childKey: parentKey],
            sampledAtNanoseconds: 20_000_000_000
        )
        let activePercentages = CotermTopProcessSnapshot.cpuPercentages(
            for: [
                parentKey: CotermTopProcessCPUSample(totalTimeTicks: 1_000, sampledAtNanoseconds: 21_000_000_000),
                childKey: CotermTopProcessCPUSample(totalTimeTicks: 1_000_001_000, sampledAtNanoseconds: 21_000_000_000),
            ],
            activeKeys: activeParentAndChild,
            parentKeysByKey: [childKey: parentKey],
            sampledAtNanoseconds: 21_000_000_000
        )

        XCTAssertEqual(activePercentages[parentKey], 0)
        XCTAssertGreaterThan(activePercentages[childKey] ?? 0, 0)

        let heldParentOnlyPercentages = CotermTopProcessSnapshot.cpuPercentages(
            for: [
                parentKey: CotermTopProcessCPUSample(totalTimeTicks: 1_000, sampledAtNanoseconds: 21_100_000_000),
            ],
            activeKeys: [parentKey],
            sampledAtNanoseconds: 21_100_000_000
        )

        XCTAssertEqual(heldParentOnlyPercentages[parentKey], 0)
        XCTAssertNil(heldParentOnlyPercentages[childKey])
    }

    func testBusyChildProcessReportsNonZeroCPUPercent() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "while :; do :; done"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        defer { terminate(process) }

        let pid = Int(process.processIdentifier)
        _ = CotermTopProcessSnapshot.capture(includeProcessDetails: false).summary(for: [pid])

        let observedCPU = waitForCPUPercent(pid: pid, timeout: 5)

        XCTAssertGreaterThan(observedCPU, 0.1)
    }

    private func waitForCPUPercent(pid: Int, timeout: TimeInterval) -> Double {
        let deadline = Date.now.addingTimeInterval(timeout)
        var maxCPU = 0.0

        while Date.now < deadline {
            let cpu = CotermTopProcessSnapshot.capture(includeProcessDetails: false)
                .summary(for: [pid])
                .cpuPercent
            maxCPU = max(maxCPU, cpu)
            if cpu > 0.1 {
                return cpu
            }

            _ = RunLoop.current.run(mode: .default, before: Date.now.addingTimeInterval(0.2))
        }

        return maxCPU
    }

    private func terminate(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()

        let deadline = Date.now.addingTimeInterval(2)
        while process.isRunning, Date.now < deadline {
            _ = RunLoop.current.run(mode: .default, before: Date.now.addingTimeInterval(0.05))
        }

        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
            process.waitUntilExit()
        }
    }
}
