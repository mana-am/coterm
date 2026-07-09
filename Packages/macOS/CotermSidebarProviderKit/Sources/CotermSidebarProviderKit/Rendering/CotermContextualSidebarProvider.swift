import Foundation

/// Provider that renders with explicit render context.
public protocol CotermContextualSidebarProvider: CotermSidebarProvider {
    /// Builds a render model from a sidebar snapshot and render context.
    func render(snapshot: CotermSidebarProviderSnapshot, context: CotermSidebarProviderRenderContext) -> CotermSidebarProviderRenderModel
}
