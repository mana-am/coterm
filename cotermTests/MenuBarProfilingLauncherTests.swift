import Testing

#if canImport(Coterm_DEV)
@testable import Coterm_DEV
#elseif canImport(Coterm)
@testable import Coterm
#endif

struct MenuBarProfilingLauncherTests {
    @Test
    func testMenuBarProfilingLaunchesCurrentProcessForFifteenSecondsWithoutOpeningOutput() {
        let arguments = MenuBarProfilingLauncher.arguments(pid: 1234)
        #expect(arguments == ["--pid", "1234", "--duration", "15"])
    }

    @Test
    func testMenuBarProfilingCanDeferSubmissionToProgressWindow() {
        let arguments = MenuBarProfilingLauncher.arguments(pid: 1234, submitProfile: false)
        #expect(arguments == ["--pid", "1234", "--duration", "15", "--no-submit"])
    }

    @Test
    func testMenuBarProfilingEstimatesDefaultCaptureSeconds() {
        #expect(MenuBarProfilingLauncher.estimatedCaptureSeconds() == 60)
    }
}
