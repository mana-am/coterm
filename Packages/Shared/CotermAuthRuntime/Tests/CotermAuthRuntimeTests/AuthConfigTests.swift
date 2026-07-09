import CotermAuthCore
import Testing
@testable import CotermAuthRuntime

@Suite struct AuthConfigTests {
    @Test func productionUsesPublicCotermOriginWithoutDashboardAuth() {
        let config = AuthConfig(environment: .production)

        #expect(config.magicLinkCallbackURL == "https://coterm.cc/auth/callback")
        #expect(config.apiBaseURL == "https://coterm.cc")
    }
}
