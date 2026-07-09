import CotermExtensionKit
import SwiftUI

@main
final class SampleSidebarExtension: @MainActor CotermSidebarExtension {
    static let manifest = CotermExtensionManifest(
        id: "co.emergent.inc.CotermExtKitSampleSidebarApp.Extension",
        displayName: String(localized: "sampleSidebar.manifest.displayName", defaultValue: "COTERM Sample Sidebar Extension"),
        readScopes: [
            .workspaceList,
            .workspaceMetadata,
            .surfaceMetadata,
            .notifications,
            .networkPorts,
            .pullRequests,
        ],
        actionScopes: [
            .createSurface,
            .selectWorkspace,
            .selectSurface,
            .navigateWorkspace,
            .navigateSurface,
        ]
    )

    private let model = SidebarConnectionModel()

    required init() {}

    var body: some View {
        SampleSidebarView(model: model)
    }

    func update(context: CotermSidebarContext) {
        model.update(context: context)
    }

    func connectionStatusDidChange(_ status: CotermSidebarConnectionStatus) {
        model.connectionStatusDidChange(status)
    }
}
