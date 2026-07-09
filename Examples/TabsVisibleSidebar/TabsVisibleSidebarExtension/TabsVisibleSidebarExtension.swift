import CotermExtensionKit
import Observation
import SwiftUI

@main
@Observable
final class TabsVisibleSidebarExtension: @MainActor CotermSidebarExtension {
    static let manifest = CotermExtensionManifest(
        id: "co.emergent.inc.TabsVisibleSidebar.Extension",
        displayName: String(localized: "tabsVisible.manifest.displayName", defaultValue: "Tabs Visible Sidebar"),
        readScopes: [
            .workspaceList,
            .workspaceMetadata,
            .surfaceMetadata,
        ],
        actionScopes: [
            .selectWorkspace,
            .selectSurface,
        ]
    )

    private(set) var snapshot: CotermSidebarSnapshot?
    private(set) var errorText: String?
    var expandedWorkspaceIDs: Set<UUID> = []

    @ObservationIgnored
    private var host: CotermSidebarHost?

    required init() {}

    var body: some View {
        TabsVisibleSidebarView(extensionModel: self)
    }

    func update(context: CotermSidebarContext) {
        snapshot = context.snapshot
        host = context.host
        errorText = nil

        if let selectedWorkspaceID = context.snapshot.selectedWorkspaceID {
            expandedWorkspaceIDs.insert(selectedWorkspaceID)
        }
    }

    func connectionStatusDidChange(_ status: CotermSidebarConnectionStatus) {
        switch status {
        case .connected:
            errorText = nil
        case .waitingForHost:
            errorText = String(localized: "tabsVisible.waitingForHost", defaultValue: "Waiting for coterm")
        case .error(let message):
            errorText = message
        }
    }

    func selectWorkspace(_ workspaceID: UUID) {
        guard let host else { return }
        expandedWorkspaceIDs.insert(workspaceID)
        Task { @MainActor in
            await apply { try await host.selectWorkspace(workspaceID) }
        }
    }

    func selectSurface(workspaceID: UUID, surfaceID: UUID) {
        guard let host else { return }
        expandedWorkspaceIDs.insert(workspaceID)
        Task { @MainActor in
            await apply { try await host.selectSurface(workspaceID: workspaceID, surfaceID: surfaceID) }
        }
    }

    private func apply(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            errorText = nil
        } catch CotermSidebarActionError.rejected(let message) {
            errorText = message
        } catch {
            errorText = String(localized: "tabsVisible.actionDenied", defaultValue: "coterm did not allow that action")
        }
    }
}
