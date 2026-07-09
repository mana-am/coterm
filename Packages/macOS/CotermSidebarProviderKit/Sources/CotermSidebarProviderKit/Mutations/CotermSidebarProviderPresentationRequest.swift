import Foundation

/// Presentation command a provider can request from the COTERM sidebar host.
public enum CotermSidebarProviderPresentationRequest: Codable, Equatable, Sendable {
    /// Open the workspace popover on a preferred tab.
    case openWorkspacePopover(workspaceId: UUID, preferredTab: CotermSidebarProviderWorkspacePopoverTab)
    /// Open a detached workspace window on a preferred tab.
    case openWorkspaceWindow(workspaceId: UUID, preferredTab: CotermSidebarProviderWorkspacePopoverTab)
    /// Ask COTERM to open a URL.
    case openURL(String)
}
