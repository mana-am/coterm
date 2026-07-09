import Foundation
@testable import Coterminal

final class FakeHibernationRecorder: AgentHibernationRecording {
    func recordTerminalInput(workspaceId: UUID, panelId: UUID) {}
}
