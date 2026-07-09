import Foundation

/// Accessory control displayed at the trailing edge of a provider row.
public struct CotermSidebarProviderRowAccessory: Codable, Equatable, Sendable {
    /// Accessory behavior.
    public var kind: CotermSidebarProviderRowAccessoryKind
    /// SF Symbols name for the accessory icon.
    public var systemImageName: String
    /// Default popover tab when the accessory opens workspace details.
    public var defaultTab: CotermSidebarProviderWorkspacePopoverTab

    /// Creates a row accessory.
    public init(
        kind: CotermSidebarProviderRowAccessoryKind,
        systemImageName: String,
        defaultTab: CotermSidebarProviderWorkspacePopoverTab
    ) {
        self.kind = kind
        self.systemImageName = systemImageName
        self.defaultTab = defaultTab
    }

    /// Standard workspace inspector accessory.
    public static let inspector = CotermSidebarProviderRowAccessory(
        kind: .workspaceInspector,
        systemImageName: "ellipsis.circle",
        defaultTab: .notes
    )
}
