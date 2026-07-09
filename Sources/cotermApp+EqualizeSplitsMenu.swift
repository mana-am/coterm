import SwiftUI

extension cotermApp {
    func equalizeSplitsCommandButton() -> some View {
        splitCommandButton(title: String(localized: "command.equalizeSplits.title", defaultValue: "Equalize Splits"), shortcut: menuShortcut(for: .equalizeSplits)) {
            let manager = activeTabManager
            if let workspace = manager.selectedWorkspace {
                let didEqualize = manager.equalizeSplits(tabId: workspace.id)
#if DEBUG
                if !didEqualize {
                    cotermDebugLog("menu.equalizeSplits result=noSplitOrFailed workspaceId=\(workspace.id)")
                }
#endif
            }
        }
    }
}
