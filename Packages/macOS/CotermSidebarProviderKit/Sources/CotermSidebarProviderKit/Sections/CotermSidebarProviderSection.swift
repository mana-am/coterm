import Foundation

/// Rendered section with tree metadata and concrete rows.
public struct CotermSidebarProviderSection: Identifiable, Codable, Equatable, Sendable {
    /// Stable section id.
    public var id: String
    /// Tree/list section metadata.
    public var treeSection: CotermSidebarProviderTreeSection
    /// Rows rendered in this section.
    public var rows: [CotermSidebarProviderRow]

    /// Creates a provider section.
    public init(
        id: String,
        treeSection: CotermSidebarProviderTreeSection,
        rows: [CotermSidebarProviderRow]
    ) {
        self.id = id
        self.treeSection = treeSection
        self.rows = rows
    }
}
