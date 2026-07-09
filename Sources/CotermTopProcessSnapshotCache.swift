import Foundation
import os

private nonisolated struct CotermTopProcessSnapshotCacheState {
    var snapshot: CotermTopProcessSnapshot?
    var includeProcessDetails = false
    var includeCotermScope = true
}

// libproc snapshots are a short-lived platform bridge shared by the CLI, socket,
// and Task Manager paths; keep the cache here so ownership stays with capture().
private nonisolated let cotermTopProcessSnapshotCache = OSAllocatedUnfairLock(
    initialState: CotermTopProcessSnapshotCacheState()
)

nonisolated extension CotermTopProcessSnapshot {
    static func captureCached(
        includeProcessDetails: Bool = false,
        includeCotermScope: Bool = true,
        maximumAge: TimeInterval
    ) -> CotermTopProcessSnapshot {
        let now = Date()
        if let cached = cotermTopProcessSnapshotCache.withLock({ state -> CotermTopProcessSnapshot? in
            guard let snapshot = state.snapshot,
                  Self.cachedSnapshotDetailsSatisfy(
                      state.includeProcessDetails,
                      requested: includeProcessDetails
                  ),
                  Self.cachedSnapshotCotermScopeSatisfies(
                      state.includeCotermScope,
                      requested: includeCotermScope
                  ),
                  now.timeIntervalSince(snapshot.sampledAt) <= maximumAge else {
                return nil
            }
            return snapshot
        }) {
            return cached
        }

        let snapshot = capture(
            includeProcessDetails: includeProcessDetails,
            includeCotermScope: includeCotermScope
        )
        return cotermTopProcessSnapshotCache.withLock { state in
            let storeTime = Date()
            if let cached = state.snapshot,
               Self.cachedSnapshotDetailsSatisfy(
                   state.includeProcessDetails,
                   requested: includeProcessDetails
               ),
               Self.cachedSnapshotCotermScopeSatisfies(
                   state.includeCotermScope,
                   requested: includeCotermScope
               ),
               storeTime.timeIntervalSince(cached.sampledAt) <= maximumAge {
                return cached
            }
            state.snapshot = snapshot
            state.includeProcessDetails = includeProcessDetails
            state.includeCotermScope = includeCotermScope
            return snapshot
        }
    }

    private static func cachedSnapshotDetailsSatisfy(
        _ cachedIncludesProcessDetails: Bool,
        requested: Bool
    ) -> Bool {
        cachedIncludesProcessDetails || !requested
    }

    private static func cachedSnapshotCotermScopeSatisfies(
        _ cachedIncludesCotermScope: Bool,
        requested: Bool
    ) -> Bool {
        cachedIncludesCotermScope || !requested
    }
}
