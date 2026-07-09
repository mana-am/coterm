import Foundation

/// Complete render model emitted by an in-process sidebar provider.
public struct CotermSidebarProviderRenderModel: Codable, Equatable, Sendable {
    /// Provider id that produced this model.
    public var providerId: String
    /// Snapshot sequence this model was rendered from.
    public var snapshotSequence: UInt64
    /// Sidebar sections to display.
    public var sections: [CotermSidebarProviderSection]
    /// Layout COTERM should use for the sections.
    public var presentation: CotermSidebarProviderPresentation

    /// Creates a provider render model.
    public init(
        providerId: String,
        snapshotSequence: UInt64,
        sections: [CotermSidebarProviderSection],
        presentation: CotermSidebarProviderPresentation = .tree
    ) {
        self.providerId = providerId
        self.snapshotSequence = snapshotSequence
        self.sections = sections
        self.presentation = presentation
    }
}
