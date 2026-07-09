public import Foundation

/// The managed coterm context identity exported to a spawned terminal process.
///
/// These values become the `COTERM_WORKSPACE_ID` / `COTERM_SURFACE_ID` /
/// `COTERM_SOCKET_PATH` (and legacy tab/panel alias) environment variables.
public struct TerminalSurfaceCotermContextEnvironment: Equatable, Sendable {
    /// The owning workspace id (exported as `COTERM_WORKSPACE_ID` / `COTERM_TAB_ID`).
    public let workspaceId: UUID

    /// The surface id (exported as `COTERM_SURFACE_ID` / `COTERM_PANEL_ID`).
    public let surfaceId: UUID

    /// The control socket path (exported as `COTERM_SOCKET_PATH`).
    public let socketPath: String

    /// Creates the managed context identity.
    ///
    /// - Parameters:
    ///   - workspaceId: The owning workspace id.
    ///   - surfaceId: The surface id.
    ///   - socketPath: The control socket path.
    public init(workspaceId: UUID, surfaceId: UUID, socketPath: String) {
        self.workspaceId = workspaceId
        self.surfaceId = surfaceId
        self.socketPath = socketPath
    }
}
