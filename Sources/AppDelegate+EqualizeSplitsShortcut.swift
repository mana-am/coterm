extension AppDelegate {
    func performEqualizeSplitsShortcut() {
        guard let tabManager, let workspace = tabManager.selectedWorkspace else {
#if DEBUG
            cotermDebugLog("shortcut.action name=equalizeSplits result=noWorkspace")
#endif
            return
        }
#if DEBUG
        cotermDebugLog("shortcut.action name=equalizeSplits workspaceId=\(workspace.id)")
#endif
        if workspace.layoutMode == .canvas {
            let executor = CanvasActionExecutor(workspace: workspace)
            let didEqualizeWidths = executor.perform(.alignment(.equalizeWidths))
            let didEqualizeHeights = executor.perform(.alignment(.equalizeHeights))
#if DEBUG
            if !didEqualizeWidths && !didEqualizeHeights {
                cotermDebugLog("shortcut.action name=equalizeSplits result=noCanvasChange workspaceId=\(workspace.id)")
            }
#endif
            return
        }
        if shouldSuppressSplitShortcutForTransientTerminalFocusState(tabManager: tabManager) {
            return
        }
        let didEqualize = tabManager.equalizeSplits(tabId: workspace.id)
#if DEBUG
        if !didEqualize {
            cotermDebugLog("shortcut.action name=equalizeSplits result=noSplitOrFailed workspaceId=\(workspace.id)")
        }
#endif
    }
}
