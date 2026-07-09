@MainActor
enum GhosttySurfaceConfigurationRefresh {
    nonisolated static let forceRefreshReason = "appDelegate.refreshAfterGhosttyConfigReload"
    nonisolated static let cotermThemeReloadLegacySource = "distributed.coterm.themes"
    nonisolated static let cotermThemeReloadPreviewSource = "distributed.coterm.themes.preview"
    nonisolated static let cotermThemeReloadFinalSource = "distributed.coterm.themes.final"
    nonisolated static let cotermThemePreviewReloadDebounceMilliseconds = 180

    nonisolated static func cotermThemeReloadSource(phase: String?) -> String {
        switch phase {
        case "final", "apply":
            return cotermThemeReloadFinalSource
        case "preview":
            return cotermThemeReloadPreviewSource
        default:
            return cotermThemeReloadLegacySource
        }
    }

    nonisolated static func shouldDebounceCotermThemeReload(source: String) -> Bool {
        switch source {
        case cotermThemeReloadLegacySource, cotermThemeReloadPreviewSource:
            return true
        default:
            return false
        }
    }

    nonisolated static func isCotermThemeReloadSource(_ source: String) -> Bool {
        switch source {
        case cotermThemeReloadLegacySource, cotermThemeReloadPreviewSource, cotermThemeReloadFinalSource:
            return true
        default:
            return false
        }
    }

    static func applyAfterAppConfigReload(
        to surface: ghostty_surface_t?,
        source: String,
        reloadSurfaceConfiguration: (ghostty_surface_t, Bool, String) -> Void,
        applySurfaceColorScheme: () -> Void,
        refreshHostBackground: () -> Void,
        forceRefresh: (String) -> Void
    ) {
        if let surface {
            applySurfaceColorScheme()
            reloadSurfaceConfiguration(surface, true, source)
        }
        refreshHostBackground()
        forceRefresh(forceRefreshReason)
    }
}
