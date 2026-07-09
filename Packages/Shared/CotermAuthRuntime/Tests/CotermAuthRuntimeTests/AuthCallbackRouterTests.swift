import Foundation
import Testing
@testable import CotermAuthRuntime

@Suite
struct AuthCallbackRouterTests {
    @Test
    func parsesCotermNativeCallbackTokensAndPreservesFirstDuplicateValue() throws {
        let router = AuthCallbackRouter(extraAllowedScheme: "coterm-dev-test")
        let url = try #require(URL(string: "coterm-dev-test://auth-callback?coterm_refresh=refresh-real&coterm_access=access-real&coterm_refresh=refresh-attacker"))

        let payload = try #require(router.callbackPayload(from: url))

        #expect(payload.refreshToken == "refresh-real")
        #expect(payload.accessToken == "access-real")
    }

    @Test
    func rejectsLegacyStackTokenNamesAndUnknownSchemes() throws {
        let router = AuthCallbackRouter(extraAllowedScheme: "coterm-dev-test")

        let legacyURL = try #require(URL(string: "coterm-dev-test://auth-callback?stack_refresh=refresh&stack_access=access"))
        #expect(router.callbackPayload(from: legacyURL) == nil)

        let unknownSchemeURL = try #require(URL(string: "other-app://auth-callback?coterm_refresh=refresh&coterm_access=access"))
        #expect(router.isAuthCallbackURL(unknownSchemeURL) == false)
        #expect(router.callbackPayload(from: unknownSchemeURL) == nil)
    }

    @Test
    func rejectsMissingOrBlankNativeTokens() throws {
        let router = AuthCallbackRouter(extraAllowedScheme: "coterm-dev-test")
        let missingAccess = try #require(URL(string: "coterm-dev-test://auth-callback?coterm_refresh=refresh"))
        let blankRefresh = try #require(URL(string: "coterm-dev-test://auth-callback?coterm_refresh=%20%20&coterm_access=access"))

        #expect(router.callbackPayload(from: missingAccess) == nil)
        #expect(router.callbackPayload(from: blankRefresh) == nil)
    }
}
