import Foundation

@_spi(CotermHostTransport)
/// Host-side callbacks used by the sidebar XPC bridge.
public struct CotermSidebarHostClient: Sendable {
    /// Returns the latest host snapshot that should be sent to an extension.
    public var snapshot: @Sendable () async throws -> CotermSidebarSnapshot

    /// Dispatches a sidebar action from an extension into COTERM.
    public var dispatch: @Sendable (CotermSidebarAction) async throws -> CotermSidebarActionResult

    /// Creates a host client from snapshot and action-dispatch closures.
    public init(
        snapshot: @escaping @Sendable () async throws -> CotermSidebarSnapshot,
        dispatch: @escaping @Sendable (CotermSidebarAction) async throws -> CotermSidebarActionResult
    ) {
        self.snapshot = snapshot
        self.dispatch = dispatch
    }
}
