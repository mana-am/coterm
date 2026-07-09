import CotermAuthCore
import Testing
@testable import CotermAuthRuntime

@Suite struct AuthConfigTests {
    @Test func productionUsesStackWhitelistedCotermDomain() {
        let config = AuthConfig(environment: .production)

        #expect(config.magicLinkCallbackURL == "https://dashboard.coterm.cc/auth/callback")
        #expect(config.apiBaseURL == "https://dashboard.coterm.cc")
    }
}
