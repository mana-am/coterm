import Foundation

/// Stable metadata COTERM uses to identify and present an in-process sidebar provider.
public struct CotermSidebarProviderDescriptor: Identifiable, Codable, Equatable, Sendable {
    /// Provider id for the built-in workspace sidebar.
    public static let defaultWorkspacesID = "coterm.sidebar.default"

    /// Stable provider identifier persisted in user selection state.
    public var id: String
    /// Localized provider title shown in sidebar provider menus.
    public var title: CotermSidebarProviderLocalizedText
    /// Optional localized detail text shown under the provider title.
    public var subtitle: CotermSidebarProviderLocalizedText?
    /// SF Symbols name used for this provider in menus.
    public var systemImageName: String
    /// Whether the provider is supplied by COTERM rather than a package example.
    public var isHostProvided: Bool

    /// Creates sidebar provider metadata.
    public init(
        id: String,
        title: CotermSidebarProviderLocalizedText,
        subtitle: CotermSidebarProviderLocalizedText? = nil,
        systemImageName: String,
        isHostProvided: Bool
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImageName = systemImageName
        self.isHostProvided = isHostProvided
    }

    /// Descriptor for COTERM's built-in workspace sidebar.
    public static let defaultWorkspaces = CotermSidebarProviderDescriptor(
        id: defaultWorkspacesID,
        title: CotermSidebarProviderLocalizedText(key: "sidebar.provider.default.title", defaultValue: "Default Workspaces"),
        subtitle: CotermSidebarProviderLocalizedText(key: "sidebar.provider.default.subtitle", defaultValue: "coterm"),
        systemImageName: "list.bullet",
        isHostProvided: true
    )
}
