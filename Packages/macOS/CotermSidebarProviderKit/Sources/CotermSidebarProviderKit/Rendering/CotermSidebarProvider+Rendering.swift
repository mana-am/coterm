import Foundation

public extension CotermSidebarProvider {
    /// Builds the default empty render model for providers that do not implement rendering.
    func render(snapshot: CotermSidebarProviderSnapshot) -> CotermSidebarProviderRenderModel {
        CotermSidebarProviderRenderModel(
            providerId: descriptor.id,
            snapshotSequence: snapshot.sequence,
            sections: []
        )
    }

    /// Builds a render model using contextual rendering when available.
    func render(
        snapshot: CotermSidebarProviderSnapshot,
        context: CotermSidebarProviderRenderContext
    ) -> CotermSidebarProviderRenderModel {
        render(snapshot: snapshot)
    }
}
