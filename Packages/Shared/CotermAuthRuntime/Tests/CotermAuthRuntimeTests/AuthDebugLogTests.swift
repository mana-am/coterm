import Foundation
import Testing
@testable import CotermAuthRuntime

@Suite struct AuthDebugLogTests {
    @Test func debugLogPathsIncludeTaggedDebugLogWhenConfigured() {
        #if DEBUG && os(macOS)
        let paths = AuthDebugLog.debugLogPaths(environment: [
            "COTERM_DEBUG_LOG": "/tmp/coterm-debug-safari.log",
        ])

        #expect(paths == ["/tmp/coterm-auth-debug.log", "/tmp/coterm-debug-safari.log"])
        #endif
    }

    @Test func redactionCoversCallbackTokenQueryValues() {
        let redacted = AuthDebugLog.redacted(
            "auth.callback.complete url=coterm-dev://auth-callback?coterm_refresh=refresh-secret&coterm_access=access-secret&coterm_auth_state=state-secret"
        )

        #expect(redacted.contains("refresh-secret") == false)
        #expect(redacted.contains("access-secret") == false)
        #expect(redacted.contains("state-secret") == false)
        #expect(redacted.contains("coterm_refresh=<redacted>"))
        #expect(redacted.contains("coterm_access=<redacted>"))
        #expect(redacted.contains("coterm_auth_state=<redacted>"))
    }

    @Test func redactionCoversEncodedNestedCallbackState() {
        let redacted = AuthDebugLog.redacted(
            "auth.browser.session.create signInURL=http://localhost:4577/handler/native-sign-in?after_auth_return_to=http%3A%2F%2Flocalhost%3A4577%2Fhandler%2Fafter-sign-in%3Fnative_app_return_to%3Dcoterm-dev-safauth%253A%252F%252Fauth-callback%253Fcoterm_auth_state%253Dstate-secret"
        )

        #expect(redacted.contains("state-secret") == false)
        #expect(redacted.contains("coterm_auth_state%253D<redacted>"))
    }
}
