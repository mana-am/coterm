import CoterminalCore

/// App-target alias for ``CoterminalCore/GhosttyConfig``, lifted into
/// CoterminalCore in stack D tranche A. Keeps every `GhosttyConfig` call site
/// (and `GhosttyConfig.ColorSchemePreference` / `GhosttyConfig.UserAppearanceConfigSummary`
/// member lookups) byte-identical across the app target.
typealias GhosttyConfig = CoterminalCore.GhosttyConfig
