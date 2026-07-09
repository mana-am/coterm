import CoterminalCore

/// Lets `CotermConfigStoreReloadCoordinator` drive per-window config reloads through a
/// protocol seam. `CotermConfigStore`'s existing `loadAll()` already satisfies the
/// requirement, so this conformance is empty.
extension CotermConfigStore: CotermConfigStoreReloading {}
