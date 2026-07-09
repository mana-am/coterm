import Foundation
import Testing

#if canImport(Coterm_DEV)
@testable import Coterm_DEV
#elseif canImport(Coterm)
@testable import Coterm
#endif

@Suite("Auth environment")
struct AuthEnvironmentTests {
    @Test("debug callback scheme uses sanitized tag")
    func debugCallbackSchemeUsesSanitizedTag() {
        #expect(
            AuthEnvironment.callbackScheme(
                environment: ["COTERM_TAG": "Safari Auth!"],
                bundleIdentifier: "coterm.com.emergent.app.debug.safari-auth",
                isDebugBuild: true
            ) == "coterm-dev-safari-auth"
        )
    }

    @Test("debug callback scheme falls back to tagged bundle id")
    func debugCallbackSchemeFallsBackToTaggedBundleID() {
        #expect(
            AuthEnvironment.callbackScheme(
                environment: [:],
                bundleIdentifier: "coterm.com.emergent.app.debug.clerk.auth",
                isDebugBuild: true
            ) == "coterm-dev-clerk-auth"
        )
    }

    @Test("callback scheme treats tagged debug bundle as debug build")
    func callbackSchemeTreatsTaggedDebugBundleAsDebugBuild() {
        #expect(
            AuthEnvironment.callbackScheme(
                environment: [:],
                bundleIdentifier: "coterm.com.emergent.app.debug.clerk.auth"
            ) == "coterm-dev-clerk-auth"
        )
    }

    @Test("debug callback scheme can come from registered URL scheme")
    func debugCallbackSchemeCanComeFromRegisteredURLScheme() {
        #expect(
            AuthEnvironment.callbackScheme(
                environment: [:],
                bundleIdentifier: "coterm.com.emergent.app.debug",
                registeredURLSchemes: ["http", "https", "coterm-dev-clerk-auth"],
                isDebugBuild: true
            ) == "coterm-dev-clerk-auth"
        )
    }

    @Test("release callback scheme ignores ambient tag")
    func releaseCallbackSchemeIgnoresAmbientTag() {
        #expect(
            AuthEnvironment.callbackScheme(
                environment: ["COTERM_TAG": "safari-auth"],
                bundleIdentifier: "coterm.com.emergent.app",
                isDebugBuild: false
            ) == "coterm"
        )
        #expect(
            AuthEnvironment.callbackScheme(
                environment: ["COTERM_TAG": "safari-auth"],
                bundleIdentifier: "coterm.com.emergent.app.nightly",
                isDebugBuild: false
            ) == "coterm-nightly"
        )
    }

    @Test("sign-in URL enters native wrapper for explicit auth origin")
    func signInURLEntersNativeWrapper() {
        // Regression coverage for #5720: the client must not derive auth URL
        // path segments from the user's system locale, such as /ru/.
        let url = AuthEnvironment.signInURL(
            callbackState: "state-1",
            environment: [
                "AppleLanguages": "(ru)",
                "LANG": "ru_RU.UTF-8",
                "LC_ALL": "ru_RU.UTF-8",
                "COTERM_AUTH_WWW_ORIGIN": "https://auth.example.test",
                "COTERM_AUTH_CALLBACK_SCHEME": "coterm",
            ],
            bundleIdentifier: "coterm.com.emergent.app"
        )

        assertNativeSignInURL(url, host: "auth.example.test")
    }

    @Test("hosted auth is disabled unless an auth origin is explicitly configured")
    func hostedAuthIsDisabledUnlessOriginIsExplicit() {
        #expect(AuthEnvironment.hostedAuthEnabled(
            environment: [
                "COTERM_TAG": "pair-auth",
                "COTERM_PORT": "4123",
            ]
        ) == false)
        #expect(AuthEnvironment.hostedAuthEnabled(
            environment: [
                "COTERM_AUTH_WWW_ORIGIN": "https://auth.example.test",
            ]
        ))
    }

    @Test("tagged debug explicit auth origin uses tag callback scheme")
    func taggedDebugExplicitAuthOriginUsesTagCallbackScheme() throws {
        let url = AuthEnvironment.signInURL(
            callbackState: "state-1",
            environment: [
                "COTERM_TAG": "pair-auth",
                "COTERM_AUTH_WWW_ORIGIN": "https://auth.example.test",
            ],
            bundleIdentifier: "coterm.com.emergent.app.debug.pair-auth"
        )

        #expect(url.scheme == "https")
        #expect(url.host == "auth.example.test")
        #expect(url.port == nil)
        #expect(url.path == "/handler/native-sign-in")

        let afterAuthReturnTo = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "after_auth_return_to" })?
            .value)
        let afterSignInURL = try #require(URL(string: afterAuthReturnTo))
        #expect(afterSignInURL.scheme == "https")
        #expect(afterSignInURL.host == "auth.example.test")
        #expect(afterSignInURL.port == nil)

        let nativeReturnTo = try #require(URLComponents(url: afterSignInURL, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "native_app_return_to" })?
            .value)
        let nativeCallbackURL = try #require(URL(string: nativeReturnTo))
        #expect(nativeCallbackURL.scheme == "coterm-dev-pair-auth")
        #expect(nativeCallbackURL.host == "auth-callback")
    }

    @Test("explicit auth origin override supports local www testing")
    func explicitAuthOriginOverrideSupportsLocalWWWTesting() throws {
        let url = AuthEnvironment.signInURL(
            callbackState: "state-1",
            environment: [
                "COTERM_TAG": "pair-auth",
                "COTERM_AUTH_WWW_ORIGIN": "http://localhost:4123",
            ],
            bundleIdentifier: "coterm.com.emergent.app.debug.pair-auth"
        )

        #expect(url.scheme == "http")
        #expect(url.host == "localhost")
        #expect(url.port == 4123)
        #expect(url.path == "/handler/native-sign-in")

        let afterAuthReturnTo = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "after_auth_return_to" })?
            .value)
        let afterSignInURL = try #require(URL(string: afterAuthReturnTo))
        #expect(afterSignInURL.scheme == "http")
        #expect(afterSignInURL.host == "localhost")
        #expect(afterSignInURL.port == 4123)
    }

    @Test("sign-in URL ignores locale-like environment values")
    func signInURLIgnoresLocaleLikeEnvironmentValues() {
        let englishURL = AuthEnvironment.signInURL(
            callbackState: "state-1",
            environment: [
                "AppleLanguages": "(en)",
                "LANG": "en_US.UTF-8",
                "LC_ALL": "en_US.UTF-8",
                "COTERM_AUTH_WWW_ORIGIN": "https://auth.example.test",
                "COTERM_AUTH_CALLBACK_SCHEME": "coterm",
            ],
            bundleIdentifier: "coterm.com.emergent.app"
        )
        let russianURL = AuthEnvironment.signInURL(
            callbackState: "state-1",
            environment: [
                "AppleLanguages": "(ru)",
                "LANG": "ru_RU.UTF-8",
                "LC_ALL": "ru_RU.UTF-8",
                "COTERM_AUTH_WWW_ORIGIN": "https://auth.example.test",
                "COTERM_AUTH_CALLBACK_SCHEME": "coterm",
            ],
            bundleIdentifier: "coterm.com.emergent.app"
        )

        #expect(russianURL == englishURL)
    }
}

private func assertNativeSignInURL(_ url: URL, host: String) {
    #expect(url.scheme == "https")
    #expect(url.host == host)
    #expect(url.path == "/handler/native-sign-in")
    #expect(!urlHasLeadingLocaleSegment(url))

    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let afterAuthReturnTo = components.queryItems?.first(where: { $0.name == "after_auth_return_to" })?.value,
          let afterSignInURL = URL(string: afterAuthReturnTo)
    else {
        Issue.record("sign-in URL must include an after_auth_return_to URL")
        return
    }

    #expect(afterSignInURL.scheme == "https")
    #expect(afterSignInURL.host == host)
    #expect(afterSignInURL.path == "/handler/after-sign-in")
    #expect(!urlHasLeadingLocaleSegment(afterSignInURL))

    guard let afterSignInComponents = URLComponents(url: afterSignInURL, resolvingAgainstBaseURL: false),
          let nativeReturnTo = afterSignInComponents.queryItems?.first(where: { $0.name == "native_app_return_to" })?.value,
          let nativeCallbackURL = URL(string: nativeReturnTo)
    else {
        Issue.record("after-sign-in URL must include a native_app_return_to URL")
        return
    }

    #expect(nativeCallbackURL.scheme == "coterm")
    #expect(nativeCallbackURL.host == "auth-callback")

    let nativeCallbackComponents = URLComponents(url: nativeCallbackURL, resolvingAgainstBaseURL: false)
    #expect(nativeCallbackComponents?.queryItems?.first { $0.name == "coterm_auth_state" }?.value == "state-1")
}

private func urlHasLeadingLocaleSegment(_ url: URL) -> Bool {
    guard let firstSegment = url.pathComponents.dropFirst().first else {
        return false
    }
    return isLocalePathSegment(firstSegment)
}

private func isLocalePathSegment(_ segment: String) -> Bool {
    let parts = segment.split(separator: "-")
    guard let language = parts.first,
          (2...3).contains(language.count),
          language.allSatisfy(\.isLetter)
    else {
        return false
    }
    return parts.dropFirst().allSatisfy { subtag in
        (2...4).contains(subtag.count) && subtag.allSatisfy(\.isLetter)
    }
}
