import Foundation

/// Result returned after COTERM handles a provider mutation.
public struct CotermSidebarProviderCommandResult: Codable, Equatable, Sendable {
    /// Whether COTERM accepted and completed the command.
    public var ok: Bool

    /// Creates a command result.
    public init(ok: Bool) {
        self.ok = ok
    }
}
