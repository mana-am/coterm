import CotermAuthCore
import CotermAuthRuntime
import AppKit
import Foundation

/// The macOS auth composition root.
///
/// Constructs the de-singletonized auth graph once at app startup, mirroring
/// the iOS `MobileAuthComposition`: the keychain/file fallback token store,
/// the coterm-native Clerk session client,
/// the shared ``CotermAuthRuntime/AuthCoordinator`` bound to the historical mac
/// defaults keys, and the ``HostBrowserSignInFlow``. Replaces
/// `AuthManager.shared`.
@MainActor
struct MacAuthComposition {
    /// The shared auth orchestrator (session state, tokens, teams).
    let coordinator: AuthCoordinator
    /// The hosted-browser sign-in flow (popup + callback URLs + sign-out).
    let browserSignIn: HostBrowserSignInFlow
    /// Recognizes/parses auth callback URLs (AppDelegate URL routing).
    let callbackRouter: AuthCallbackRouter
    /// The token store the native auth client persists through.
    let tokenStore: any StackAuthTokenStoreProtocol

    /// Build the auth graph.
    /// - Parameters:
    ///   - environment: The process environment (UI-test launch options).
    ///   - defaults: Persistence for the cached user / has-tokens flag /
    ///     selected team (historical `coterm.auth.*` keys).
    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults = .standard
    ) {
        let bundleIdentifier = Bundle.main.bundleIdentifier
        let tokenStore = FallbackTokenStore(
            primary: KeychainStackTokenStore(
                service: KeychainStackTokenStore.serviceName(bundleIdentifier: bundleIdentifier)
            ),
            fallback: FileStackTokenStore(directory: Self.credentialsDirectory(bundleIdentifier: bundleIdentifier))
        )
        self.tokenStore = tokenStore

        let client = NativeAuthClient(
            apiBaseURL: AuthEnvironment.apiBaseURL,
            tokenStore: tokenStore
        )

        let userCache = CotermAuthIdentityStore(
            keyValueStore: defaults,
            key: "coterm.auth.cachedUser"
        )
        let sessionCache = CotermAuthSessionCache(
            keyValueStore: defaults,
            key: "coterm.auth.hasTokens"
        )
        // One-time migration: the deleted AuthManager never wrote a has-tokens
        // flag. Prime it from the cached user so the first post-migration
        // launch primes as "restoring" instead of flashing signed-out while
        // the stored session validates.
        if defaults.object(forKey: "coterm.auth.hasTokens") == nil,
           (try? userCache.load()) != nil {
            sessionCache.setHasTokens(true)
        }

        let config = AuthConfig(
            stack: CotermAuthConfig(
                projectId: "clerk",
                publishableClientKey: "clerk"
            ),
            magicLinkCallbackURL: AuthEnvironment.websiteOrigin
                .appendingPathComponent("auth/callback", isDirectory: false)
                .absoluteString,
            apiBaseURL: AuthEnvironment.apiBaseURL.absoluteString
        )
        // DEBUG-only: make a tagged `coterm DEV` build come up already signed in
        // as the dogfood account, mirroring iOS. A tagged build is a separate
        // bundle (separate keychain), so it starts signed out. iOS injects
        // `COTERM_UITEST_STACK_*` into the launch environment; the Mac app needs
        // the same, but a `coterm DEV` opened from Finder / the COTERM Tag Opener
        // does not inherit a shell's environment, so the resolver also reads
        // `~/.secrets/coterm-dev.env` / `~/.secrets/coterm.env` directly. The
        // resolver runs unconditionally and applies dogfood-account-first
        // precedence, so on the dog Mac the human dogfood file wins even when an
        // agent's `COTERM_UITEST_STACK_*` are already in the environment; only the
        // two resolved cred keys are filled in (never the whole file). When the
        // only creds are `COTERM_UITEST_STACK_*` env (a CI UI test with no
        // `~/.secrets` files), the resolver returns that same pair, so the merge
        // is a no-op. The existing `CotermAuthAutoLoginCredentials` +
        // `shouldStartAutoLogin` gate then fires unchanged. Compiled out of
        // release builds.
        let resolvedEnvironment = Self.environmentWithDogfoodAutoSignIn(environment)
        let launch = AuthLaunchOptions(
            clearAuthRequested: resolvedEnvironment["COTERM_UITEST_CLEAR_AUTH"] == "1",
            mockDataEnabled: false,
            environment: resolvedEnvironment,
            includesDevAuth: Self.includesDevAuth
        )

        let anchor = AuthPresentationContextProvider()
        let coordinator = AuthCoordinator(
            client: client,
            sessionCache: sessionCache,
            userCache: userCache,
            teamSelection: CotermAuthTeamSelectionStore(
                keyValueStore: defaults,
                key: "coterm.auth.selectedTeamID"
            ),
            anchor: anchor,
            config: config,
            launch: launch,
            onSignedIn: {
                await CollaborationRuntime.shared.refreshPeerIdentityFromCurrentAuth()
            }
        )
        self.coordinator = coordinator
        let callbackRouter = AuthCallbackRouter(
            extraAllowedScheme: AuthEnvironment.callbackScheme
        )
        self.callbackRouter = callbackRouter
        self.browserSignIn = HostBrowserSignInFlow(
            coordinator: coordinator,
            tokenStore: tokenStore,
            sessionFactory: DefaultBrowserAuthSessionFactory(
                activateApp: {
                    NSApp.activate(ignoringOtherApps: true)
                    AppDelegate.shared?.focusMainWindowAfterAuthReturn()
                }
            ),
            callbackRouter: callbackRouter,
            makeSignInURL: { AuthEnvironment.signInURL(callbackState: $0) },
            callbackScheme: { AuthEnvironment.callbackScheme }
        )
    }

    /// Begin asynchronous session restore. Call once after construction, at
    /// the composition root.
    func start() {
        coordinator.start()
    }

    /// Where the file-fallback token store persists, namespaced by bundle id
    /// (matching the pre-package layout so existing sessions survive).
    private static func credentialsDirectory(bundleIdentifier: String?) -> URL {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return support
            .appendingPathComponent("coterm", isDirectory: true)
            .appendingPathComponent(bundleIdentifier ?? "coterm", isDirectory: true)
    }

    private static var includesDevAuth: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    #if DEBUG
    /// Returns `environment` with the dogfood auto-sign-in credentials filled in
    /// under the `COTERM_UITEST_STACK_*` keys (DEBUG only; the whole method is
    /// compiled out of release, so the auto-sign-in path can never run in
    /// production).
    ///
    /// Always consults ``DebugDogfoodCredentialResolver`` so the resolver's
    /// dogfood-over-agent precedence is honored even when `COTERM_UITEST_STACK_*`
    /// are already present in the environment: on the dog Mac an iOS dogfood
    /// flow can leave the agent's `COTERM_UITEST_STACK_*` in the environment while
    /// the human dogfood creds live only in `~/.secrets/coterm-dev.env`, and
    /// the build must come up as the human account. When only `COTERM_UITEST_STACK_*`
    /// env creds exist (e.g. a CI UI test with no `~/.secrets` files), the
    /// resolver returns that same pair, so the merge is a no-op.
    ///
    /// - Parameters:
    ///   - environment: The launch environment.
    ///   - secretFilePaths: Ordered secret-file candidates for the resolver.
    ///     Defaults to `nil` so the resolver uses `~/.secrets/coterm-dev.env`
    ///     then `~/.secrets/coterm.env`. Injected by tests to exercise the
    ///     dog-Mac precedence without touching real files.
    ///   - readFile: File reader seam for the resolver. Defaults to a real read;
    ///     injected by tests.
    ///
    /// `nonisolated`: a pure transformation over its arguments that touches no
    /// main-actor state, so tests can call it from a nonisolated context.
    nonisolated static func environmentWithDogfoodAutoSignIn(
        _ environment: [String: String],
        secretFilePaths: [String]? = nil,
        readFile: ((String) -> String?)? = nil
    ) -> [String: String] {
        let resolver: DebugDogfoodCredentialResolver
        if let readFile {
            resolver = DebugDogfoodCredentialResolver(
                environment: environment,
                secretFilePaths: secretFilePaths,
                readFile: readFile
            )
        } else {
            resolver = DebugDogfoodCredentialResolver(
                environment: environment,
                secretFilePaths: secretFilePaths
            )
        }
        guard let resolved = resolver.resolve() else {
            return environment
        }
        var merged = environment
        merged["COTERM_UITEST_STACK_EMAIL"] = resolved.email
        merged["COTERM_UITEST_STACK_PASSWORD"] = resolved.password
        return merged
    }
    #else
    /// In release builds the dogfood auto-sign-in path does not exist; this is
    /// the identity function so production never auto-signs-in.
    nonisolated static func environmentWithDogfoodAutoSignIn(
        _ environment: [String: String]
    ) -> [String: String] {
        environment
    }
    #endif
}
