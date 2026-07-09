import Foundation
import CotermFoundation
import CoterminalCore

// CotermSurfaceConfigTemplate and the surface runtime probes moved to
// CoterminalCore (SurfaceValues/CotermSurfaceConfigTemplate.swift and
// Interop/GhosttySurfaceRuntimeProbe.swift). The legacy free-function names
// below are shims forwarding existing app callers to the probe.

typealias CotermSurfaceConfigTemplate = CoterminalCore.CotermSurfaceConfigTemplate

func cotermSurfaceContextName(_ context: ghostty_surface_context_e) -> String {
    GhosttySurfaceRuntimeProbe.contextName(context)
}

func cotermSurfacePointerAppearsLive(_ surface: ghostty_surface_t) -> Bool {
    GhosttySurfaceRuntimeProbe.surfacePointerAppearsLive(surface)
}

func cotermCurrentSurfaceFontSizePoints(_ surface: ghostty_surface_t) -> Float? {
    GhosttySurfaceRuntimeProbe.currentSurfaceFontSizePoints(surface)
}

func cotermInheritedSurfaceConfig(
    sourceSurface: ghostty_surface_t,
    context: ghostty_surface_context_e
) -> CotermSurfaceConfigTemplate {
    let inherited = ghostty_surface_inherited_config(sourceSurface, context)
    let percent = GlobalFontMagnification.storedPercent
    var config = CotermSurfaceConfigTemplate(
        cConfig: inherited,
        globalFontMagnificationPercent: percent
    )

    // Make runtime zoom inheritance explicit, even when Ghostty's
    // inherit-font-size config is disabled.
    let runtimePoints = cotermCurrentSurfaceFontSizePoints(sourceSurface)
    if let points = runtimePoints {
        config.fontSize = CotermSurfaceConfigTemplate.baseFontSize(
            fromRuntimePoints: points,
            percent: percent
        )
    }

#if DEBUG
    let inheritedText = String(format: "%.2f", inherited.font_size)
    let runtimeText = runtimePoints.map { String(format: "%.2f", $0) } ?? "nil"
    let finalText = String(format: "%.2f", config.fontSize)
    cotermDebugLog(
        "zoom.inherit context=\(cotermSurfaceContextName(context)) " +
        "inherited=\(inheritedText) runtime=\(runtimeText) final=\(finalText)"
    )
#endif

    return config
}
