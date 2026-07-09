import Foundation

/// Row rendered inside a provider section.
public struct CotermSidebarProviderRow: Identifiable, Codable, Equatable, Sendable {
    /// Stable row id.
    public var id: UUID
    /// Primary row title.
    public var title: String
    /// Workspace represented by the row.
    public var workspaceId: UUID
    /// Optional trailing accessory.
    public var accessory: CotermSidebarProviderRowAccessory?
    /// Optional subtitle.
    public var subtitle: CotermSidebarProviderText?
    /// Optional trailing text.
    public var trailingText: CotermSidebarProviderText?
    /// Optional leading icon.
    public var leadingIcon: CotermSidebarProviderIcon?

    /// Creates a provider row.
    public init(
        id: UUID,
        title: String,
        workspaceId: UUID,
        accessory: CotermSidebarProviderRowAccessory?,
        subtitle: CotermSidebarProviderText? = nil,
        trailingText: CotermSidebarProviderText? = nil,
        leadingIcon: CotermSidebarProviderIcon? = nil
    ) {
        self.id = id
        self.title = title
        self.workspaceId = workspaceId
        self.accessory = accessory
        self.subtitle = subtitle
        self.trailingText = trailingText
        self.leadingIcon = leadingIcon
    }
}
