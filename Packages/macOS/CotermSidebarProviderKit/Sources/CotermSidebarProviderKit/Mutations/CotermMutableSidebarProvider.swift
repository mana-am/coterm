import Foundation

/// Provider that can both render sidebar state and handle host mutations.
public protocol CotermMutableSidebarProvider: CotermContextualSidebarProvider {
    /// Handles a mutation against the latest sidebar snapshot.
    func handle(
        _ mutation: CotermSidebarProviderMutation,
        snapshot: CotermSidebarProviderSnapshot
    ) throws -> CotermSidebarProviderCommandResult
}
