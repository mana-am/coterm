import Foundation

@_spi(CotermHostTransport)
public enum CotermExtensionValidationError: Error, Equatable, Sendable {
    case unsupportedAPIVersion(requested: CotermExtensionAPIVersion, supported: CotermExtensionAPIVersion)
    case emptyIdentifier
    case emptyDisplayName
    case payloadTooLarge(kind: String, actualBytes: Int, maximumBytes: Int)
}
