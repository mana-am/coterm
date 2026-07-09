public import Foundation

/// A request for the coterm destination profile an import entry should write to.
public enum BrowserImportDestinationRequest: Equatable, Sendable {
    /// Import into the existing coterm profile with this identifier.
    case existing(UUID)
    /// Create a new coterm profile with this display name, then import into it.
    case createNamed(String)
}
