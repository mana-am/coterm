import Testing

#if canImport(Coterm_DEV)
@testable import Coterm_DEV
#elseif canImport(Coterm)
@testable import Coterm
#endif

@Suite
struct TabManagerAutomaticWelcomeTests {
    @Test
    @MainActor
    func automaticWelcomeIsSentWhenWorkspaceQualifies() {
        #expect(TabManager.shouldSendAutomaticWelcome(
            autoWelcomeIfNeeded: true,
            select: true,
            startsWithTerminal: true,
            welcomeAlreadyShown: false
        ) == true)
    }

    @Test(arguments: [
        (autoWelcomeIfNeeded: false, select: true, startsWithTerminal: true, welcomeAlreadyShown: false),
        (autoWelcomeIfNeeded: true, select: false, startsWithTerminal: true, welcomeAlreadyShown: false),
        (autoWelcomeIfNeeded: true, select: true, startsWithTerminal: false, welcomeAlreadyShown: false),
        (autoWelcomeIfNeeded: true, select: true, startsWithTerminal: true, welcomeAlreadyShown: true),
    ])
    @MainActor
    func automaticWelcomeIsSuppressedForNonQualifyingWorkspaceInputs(
        autoWelcomeIfNeeded: Bool,
        select: Bool,
        startsWithTerminal: Bool,
        welcomeAlreadyShown: Bool
    ) {
        #expect(TabManager.shouldSendAutomaticWelcome(
            autoWelcomeIfNeeded: autoWelcomeIfNeeded,
            select: select,
            startsWithTerminal: startsWithTerminal,
            welcomeAlreadyShown: welcomeAlreadyShown
        ) == false)
    }
}
