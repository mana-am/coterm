import CotermSidebarProviderKit
import Foundation

public enum SidebarExamples {
    public static let providers: [any CotermSidebarProvider] = [
        ProjectWorktreeSidebar(),
        AttentionQueueSidebar(),
        DevServerSidebar(),
        LastPromptSidebar(),
        SuperCompactSidebar(),
        BrowserStackSidebar(onAsyncStateLoaded: {
            BrowserStackSidebar.postStateDidLoadNotification()
        }),
    ]
}

struct ExampleSidebarSection {
    var id: String
    var title: CotermSidebarProviderLocalizedText
    var systemImageName: String
    var projectRootPath: String?
    var workspaces: [CotermSidebarProviderWorkspace]

    func render(
        rowTitle: (CotermSidebarProviderWorkspace) -> String = { $0.title },
        accessory: CotermSidebarProviderRowAccessory? = .inspector,
        subtitle: (CotermSidebarProviderWorkspace) -> CotermSidebarProviderText? = { _ in nil },
        trailingText: (CotermSidebarProviderWorkspace) -> CotermSidebarProviderText? = { _ in nil },
        leadingIcon: (CotermSidebarProviderWorkspace) -> CotermSidebarProviderIcon? = { _ in nil }
    ) -> CotermSidebarProviderSection {
        CotermSidebarProviderSection(
            id: id,
            treeSection: CotermSidebarProviderTreeSection(
                id: id,
                title: title.defaultValue,
                titleText: title,
                subtitle: nil,
                systemImageName: systemImageName,
                projectRootPath: projectRootPath,
                workspaceIds: workspaces.map(\.id)
            ),
            rows: workspaces.map { workspace in
                CotermSidebarProviderRow(
                    id: workspace.id,
                    title: rowTitle(workspace),
                    workspaceId: workspace.id,
                    accessory: accessory,
                    subtitle: subtitle(workspace),
                    trailingText: trailingText(workspace),
                    leadingIcon: leadingIcon(workspace)
                )
            }
        )
    }
}

func localized(_ key: String, _ defaultValue: String) -> CotermSidebarProviderLocalizedText {
    CotermSidebarProviderLocalizedText(key: key, defaultValue: defaultValue)
}

func renderModel(
    providerId: String,
    snapshot: CotermSidebarProviderSnapshot,
    sections: [CotermSidebarProviderSection],
    presentation: CotermSidebarProviderPresentation = .tree
) -> CotermSidebarProviderRenderModel {
    CotermSidebarProviderRenderModel(
        providerId: providerId,
        snapshotSequence: snapshot.sequence,
        sections: presentation == .browserStack ? sections : sections.filter { !$0.rows.isEmpty },
        presentation: presentation
    )
}

func trimmed(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}

func projectRoot(for workspace: CotermSidebarProviderWorkspace) -> String? {
    trimmed(workspace.projectRootPath)
}

func displayName(for path: String) -> String {
    let url = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    let name = url.lastPathComponent
    return name.isEmpty ? path : name
}
