import Foundation

extension CotermAuthUser {
    /// Parse a UI-test fixture user from the launch environment, or `nil`
    /// when no fixture was requested.
    ///
    /// UI tests opt in with `COTERM_UITEST_AUTH_FIXTURE=1` and may override the
    /// id/email/name fields; a cleared-auth or mock-data launch always wins
    /// over a fixture.
    /// - Parameters:
    ///   - environment: The process launch environment.
    ///   - clearAuth: Whether the launch requested a cleared auth state.
    ///   - mockDataEnabled: Whether mock-data mode is active.
    public init?(
        uiTestFixtureEnvironment environment: [String: String],
        clearAuth: Bool,
        mockDataEnabled: Bool
    ) {
        if clearAuth || mockDataEnabled {
            return nil
        }
        guard environment["COTERM_UITEST_AUTH_FIXTURE"] == "1" else {
            return nil
        }
        self.init(
            id: environment["COTERM_UITEST_AUTH_USER_ID"] ?? "uitest_user",
            primaryEmail: environment["COTERM_UITEST_AUTH_EMAIL"] ?? "uitest@coterm.local",
            displayName: environment["COTERM_UITEST_AUTH_NAME"] ?? "UI Test"
        )
    }
}
