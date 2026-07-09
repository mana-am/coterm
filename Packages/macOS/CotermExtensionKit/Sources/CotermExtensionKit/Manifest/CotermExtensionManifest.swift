import Foundation

/// Metadata and permission request declared by a COTERM extension.
public struct CotermExtensionManifest: Codable, Equatable, Identifiable, Sendable {
    /// Stable reverse-DNS style identifier for the extension.
    public var id: String

    /// Human-readable extension name shown by COTERM permission and management UI.
    public var displayName: String

    /// Minimum COTERM extension API version required by this extension.
    @_spi(CotermHostTransport) public var minimumAPIVersion: CotermExtensionAPIVersion

    /// Sidebar data scopes the extension asks COTERM to include in snapshots.
    public var readScopes: [CotermExtensionScope]

    /// Host action scopes the extension asks COTERM to allow.
    public var actionScopes: [CotermExtensionActionScope]

    /// Creates a sidebar extension manifest.
    public init(
        id: String,
        displayName: String,
        readScopes: [CotermExtensionScope] = [],
        actionScopes: [CotermExtensionActionScope] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.minimumAPIVersion = .sidebarV2
        self.readScopes = readScopes
        self.actionScopes = actionScopes
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case minimumAPIVersion
        case readScopes
        case actionScopes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        minimumAPIVersion = try container.decodeIfPresent(CotermExtensionAPIVersion.self, forKey: .minimumAPIVersion) ?? .sidebarV2
        readScopes = try container.decode([CotermExtensionScope].self, forKey: .readScopes)
        actionScopes = try container.decodeIfPresent(
            [CotermExtensionActionScope].self,
            forKey: .actionScopes
        ) ?? []
    }
}
