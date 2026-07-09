import Foundation
@testable import CotermControlSocket

#if DEBUG
@MainActor
final class FakeDebugCanvasControlCommandContext: ControlCommandContext {
    var resolution: ControlCanvasActionResolution = .ok(mode: "canvas")
    var lastRouting: ControlRoutingSelectors?

    func controlDebugShowCanvasCommandScrollHint(
        routing: ControlRoutingSelectors
    ) -> ControlCanvasActionResolution {
        lastRouting = routing
        return resolution
    }
}
#endif
