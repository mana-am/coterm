import Foundation
import Observation
import SwiftUI
import CotermExtensionKit

@Observable
@MainActor
final class SidebarConnectionModel {
    private(set) var snapshot: CotermSidebarSnapshot?
    private(set) var errorText: String?

    @ObservationIgnored
    private var host: CotermSidebarHost?

    func update(context: CotermSidebarContext) {
        snapshot = context.snapshot
        host = context.host
        errorText = nil
    }

    func connectionStatusDidChange(_ status: CotermSidebarConnectionStatus) {
        switch status {
        case .connected:
            errorText = nil
        case .waitingForHost:
            errorText = String(localized: "sampleSidebar.waitingForHost", defaultValue: "Waiting for coterm")
        case .error(let message):
            errorText = message
        }
    }

    var insights: SidebarInsightModel? {
        snapshot.map(SidebarInsightModel.init(snapshot:))
    }

    func refreshSnapshot() {
        host?.refresh()
    }

    func selectWorkspace(_ id: UUID) async {
        guard let host else { return }
        await apply { try await host.selectWorkspace(id) }
    }

    func selectSurface(workspaceID: UUID, surfaceID: UUID) async {
        guard let host else { return }
        await apply { try await host.selectSurface(workspaceID: workspaceID, surfaceID: surfaceID) }
    }

    func selectPreviousWorkspace() async {
        guard let host else { return }
        await apply { try await host.selectPreviousWorkspace() }
    }

    func selectNextWorkspace() async {
        guard let host else { return }
        await apply { try await host.selectNextWorkspace() }
    }

    func selectPreviousSurface() async {
        guard let host else { return }
        await apply { try await host.selectPreviousSurface() }
    }

    func selectNextSurface() async {
        guard let host else { return }
        await apply { try await host.selectNextSurface() }
    }

    func createTerminalSurface(in workspaceID: UUID?) async {
        guard let host else { return }
        await apply { try await host.createTerminalSurface(in: workspaceID) }
    }

    private func apply(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            errorText = nil
        } catch CotermSidebarActionError.rejected(let message) {
            errorText = message
        } catch CotermSidebarActionError.cancelled {
            errorText = nil
        } catch {
            errorText = String(localized: "sampleSidebar.actionDenied", defaultValue: "coterm did not allow that action")
        }
    }

}
