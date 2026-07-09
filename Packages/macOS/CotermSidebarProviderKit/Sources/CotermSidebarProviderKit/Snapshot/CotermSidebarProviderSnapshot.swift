import Foundation

/// Snapshot of COTERM workspace state consumed by in-process sidebar providers.
public struct CotermSidebarProviderSnapshot: Codable, Equatable, Sendable {
    /// Monotonic snapshot sequence.
    public var sequence: UInt64
    /// Currently selected workspace id, if any.
    public var selectedWorkspaceId: UUID?
    /// Workspaces visible to providers.
    public var workspaces: [CotermSidebarProviderWorkspace]
    /// Host window id that produced this snapshot, if window-scoped.
    public var windowId: UUID?

    /// Creates a provider snapshot.
    public init(
        sequence: UInt64,
        selectedWorkspaceId: UUID?,
        workspaces: [CotermSidebarProviderWorkspace],
        windowId: UUID? = nil
    ) {
        self.sequence = sequence
        self.selectedWorkspaceId = selectedWorkspaceId
        self.workspaces = workspaces
        self.windowId = windowId
    }

    /// Workspace ids in snapshot order.
    public var workspaceIds: [UUID] {
        workspaces.map(\.id)
    }
}
