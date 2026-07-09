import Foundation

/// Validates a sidebar extension manifest before COTERM trusts it.
@_spi(CotermHostTransport)
public func validateSidebarManifest(
    _ manifest: CotermExtensionManifest,
    supportedAPIVersion: CotermExtensionAPIVersion = .sidebarV2
) throws {
    guard manifest.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
        throw CotermExtensionValidationError.emptyIdentifier
    }
    guard manifest.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
        throw CotermExtensionValidationError.emptyDisplayName
    }
    guard manifest.minimumAPIVersion.major == supportedAPIVersion.major,
          manifest.minimumAPIVersion <= supportedAPIVersion else {
        throw CotermExtensionValidationError.unsupportedAPIVersion(
            requested: manifest.minimumAPIVersion,
            supported: supportedAPIVersion
        )
    }
}
