@testable import Coterminal

final class FakeRendererRealizationScheduler: TerminalRendererRealizationScheduling {
    @MainActor
    func scheduleImmediatePass() {}
}
