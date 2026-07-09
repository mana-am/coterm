import Foundation

/// In-process sidebar provider used by COTERM-owned sidebar presentations.
public protocol CotermSidebarProvider: Sendable {
    /// Stable metadata describing the provider in selection UI.
    var descriptor: CotermSidebarProviderDescriptor { get }

    /// Builds a render model from the latest sidebar snapshot.
    func render(snapshot: CotermSidebarProviderSnapshot) -> CotermSidebarProviderRenderModel
}
