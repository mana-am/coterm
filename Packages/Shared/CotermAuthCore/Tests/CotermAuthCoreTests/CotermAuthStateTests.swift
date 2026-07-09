import CotermAuthCore
import Foundation
import Testing

@Suite("CotermAuthCore")
struct CotermAuthStateTests {
    @Test("Config resolves development defaults and overrides")
    func configResolvesDevelopmentDefaultsAndOverrides() {
        let defaults = CotermAuthConfig(
            environment: .development,
            developmentProjectId: "dev-project",
            productionProjectId: "prod-project",
            developmentPublishableClientKey: "dev-key",
            productionPublishableClientKey: "prod-key"
        )
        #expect(defaults == CotermAuthConfig(projectId: "dev-project", publishableClientKey: "dev-key"))

        let overrides = CotermAuthConfig(
            environment: .development,
            overrides: [
                "STACK_PROJECT_ID_DEV": "override-project",
                "STACK_PUBLISHABLE_CLIENT_KEY_DEV": "override-key",
            ],
            developmentProjectId: "dev-project",
            productionProjectId: "prod-project",
            developmentPublishableClientKey: "dev-key",
            productionPublishableClientKey: "prod-key"
        )
        #expect(overrides == CotermAuthConfig(projectId: "override-project", publishableClientKey: "override-key"))
    }

    @Test("Config resolves production defaults and overrides")
    func configResolvesProductionDefaultsAndOverrides() {
        let defaults = CotermAuthConfig(
            environment: .production,
            developmentProjectId: "dev-project",
            productionProjectId: "prod-project",
            developmentPublishableClientKey: "dev-key",
            productionPublishableClientKey: "prod-key"
        )
        #expect(defaults == CotermAuthConfig(projectId: "prod-project", publishableClientKey: "prod-key"))

        let overrides = CotermAuthConfig(
            environment: .production,
            overrides: [
                "STACK_PROJECT_ID_PROD": "override-project",
                "STACK_PUBLISHABLE_CLIENT_KEY_PROD": "override-key",
            ],
            developmentProjectId: "dev-project",
            productionProjectId: "prod-project",
            developmentPublishableClientKey: "dev-key",
            productionPublishableClientKey: "prod-key"
        )
        #expect(overrides == CotermAuthConfig(projectId: "override-project", publishableClientKey: "override-key"))
    }

    @Test("Launch config returns credentials only when enabled")
    func launchConfigReturnsCredentialsOnlyWhenEnabled() {
        let environment = [
            "COTERM_UITEST_STACK_EMAIL": "test@example.com",
            "COTERM_UITEST_STACK_PASSWORD": "pass123",
        ]

        #expect(
            CotermAuthAutoLoginCredentials(
                environment: environment,
                clearAuth: false,
                mockDataEnabled: false
            ) == CotermAuthAutoLoginCredentials(email: "test@example.com", password: "pass123")
        )
        #expect(
            CotermAuthAutoLoginCredentials(
                environment: environment,
                clearAuth: true,
                mockDataEnabled: false
            ) == nil
        )
        #expect(
            CotermAuthAutoLoginCredentials(
                environment: environment,
                clearAuth: false,
                mockDataEnabled: true
            ) == nil
        )
    }

    @Test("Launch config returns fixture user only when enabled")
    func launchConfigReturnsFixtureUserOnlyWhenEnabled() {
        let environment = [
            "COTERM_UITEST_AUTH_FIXTURE": "1",
            "COTERM_UITEST_AUTH_USER_ID": "fixture-user",
            "COTERM_UITEST_AUTH_EMAIL": "fixture@example.com",
            "COTERM_UITEST_AUTH_NAME": "Fixture User",
        ]

        #expect(
            CotermAuthUser(
                uiTestFixtureEnvironment: environment,
                clearAuth: false,
                mockDataEnabled: false
            ) == CotermAuthUser(
                id: "fixture-user",
                primaryEmail: "fixture@example.com",
                displayName: "Fixture User"
            )
        )
        #expect(
            CotermAuthUser(
                uiTestFixtureEnvironment: environment,
                clearAuth: true,
                mockDataEnabled: false
            ) == nil
        )
        #expect(
            CotermAuthUser(
                uiTestFixtureEnvironment: environment,
                clearAuth: false,
                mockDataEnabled: true
            ) == nil
        )
    }

    @Test("Primed state authenticates cached user while validating tokens")
    func primedStateAuthenticatesCachedUserWhileValidatingTokens() {
        let user = CotermAuthUser(id: "user_123", primaryEmail: "user@example.com", displayName: "Test User")
        let state = CotermAuthState.primed(
            clearAuthRequested: false,
            mockDataEnabled: false,
            fixtureUser: nil,
            autoLoginCredentials: nil,
            cachedUser: user,
            hasTokens: true,
            mockUser: CotermAuthUser(id: "mock", primaryEmail: "mock@example.com", displayName: "Mock")
        )

        #expect(state.isAuthenticated)
        #expect(state.currentUser == user)
        #expect(!state.isRestoringSession)
    }

    @Test("Primed state restores when tokens exist without a cached user")
    func primedStateRestoresWhenTokensExistWithoutCachedUser() {
        let state = CotermAuthState.primed(
            clearAuthRequested: false,
            mockDataEnabled: false,
            fixtureUser: nil,
            autoLoginCredentials: nil,
            cachedUser: nil,
            hasTokens: true,
            mockUser: CotermAuthUser(id: "mock", primaryEmail: "mock@example.com", displayName: "Mock")
        )

        #expect(!state.isAuthenticated)
        #expect(state.currentUser == nil)
        #expect(state.isRestoringSession)
    }

    @Test("Primed state does not authenticate from auto-login credentials before sign-in")
    func primedStateDoesNotAuthenticateFromAutoLoginCredentialsBeforeSignIn() {
        let user = CotermAuthUser(id: "user_123", primaryEmail: "user@example.com", displayName: "Test User")
        let state = CotermAuthState.primed(
            clearAuthRequested: false,
            mockDataEnabled: false,
            fixtureUser: nil,
            autoLoginCredentials: CotermAuthAutoLoginCredentials(email: "user@example.com", password: "password"),
            cachedUser: user,
            hasTokens: false,
            mockUser: CotermAuthUser(id: "mock", primaryEmail: "mock@example.com", displayName: "Mock")
        )

        #expect(!state.isAuthenticated)
        #expect(state.currentUser == user)
        #expect(state.isRestoringSession)
    }

    @Test("Primed state ignores auto-login credentials when cached tokens exist")
    func primedStateIgnoresAutoLoginCredentialsWhenCachedTokensExist() {
        let user = CotermAuthUser(id: "user_123", primaryEmail: "user@example.com", displayName: "Test User")
        let state = CotermAuthState.primed(
            clearAuthRequested: false,
            mockDataEnabled: false,
            fixtureUser: nil,
            autoLoginCredentials: CotermAuthAutoLoginCredentials(email: "user@example.com", password: "password"),
            cachedUser: user,
            hasTokens: true,
            mockUser: CotermAuthUser(id: "mock", primaryEmail: "mock@example.com", displayName: "Mock")
        )

        #expect(state.isAuthenticated)
        #expect(state.currentUser == user)
        #expect(!state.isRestoringSession)
    }

    @Test("Primed state does not authenticate from cached user alone")
    func primedStateDoesNotAuthenticateFromCachedUserAlone() {
        let user = CotermAuthUser(id: "user_123", primaryEmail: "user@example.com", displayName: "Test User")
        let state = CotermAuthState.primed(
            clearAuthRequested: false,
            mockDataEnabled: false,
            fixtureUser: nil,
            autoLoginCredentials: nil,
            cachedUser: user,
            hasTokens: false,
            mockUser: CotermAuthUser(id: "mock", primaryEmail: "mock@example.com", displayName: "Mock")
        )

        #expect(!state.isAuthenticated)
        #expect(state.currentUser == user)
        #expect(!state.isRestoringSession)
    }

    @Test("Primed state uses fixture user")
    func primedStateUsesFixtureUser() {
        let fixtureUser = CotermAuthUser(id: "fixture", primaryEmail: "fixture@example.com", displayName: "Fixture")
        let state = CotermAuthState.primed(
            clearAuthRequested: false,
            mockDataEnabled: false,
            fixtureUser: fixtureUser,
            autoLoginCredentials: nil,
            cachedUser: nil,
            hasTokens: false,
            mockUser: CotermAuthUser(id: "mock", primaryEmail: "mock@example.com", displayName: "Mock")
        )

        #expect(state.isAuthenticated)
        #expect(state.currentUser == fixtureUser)
        #expect(!state.isRestoringSession)
    }

    @Test("Cleared state clears auth")
    func clearedStateClearsAuth() {
        #expect(CotermAuthState.cleared() == CotermAuthState(isAuthenticated: false, currentUser: nil, isRestoringSession: false))
    }

    @Test("Identity store and session cache round trip")
    func identityStoreAndSessionCacheRoundTrip() throws {
        let store = TestKeyValueStore()
        let identityStore = CotermAuthIdentityStore(keyValueStore: store, key: "auth_cached_user")
        let sessionCache = CotermAuthSessionCache(keyValueStore: store, key: "auth_has_tokens")
        let user = CotermAuthUser(id: "user_123", primaryEmail: "user@example.com", displayName: "Test User")

        try identityStore.save(user)
        #expect(try identityStore.load() == user)

        sessionCache.setHasTokens(true)
        #expect(sessionCache.hasTokens)

        identityStore.clear()
        sessionCache.clear()

        #expect(try identityStore.load() == nil)
        #expect(!sessionCache.hasTokens)
    }
}

private final class TestKeyValueStore: CotermAuthKeyValueStore {
    private var storage: [String: Any] = [:]

    func bool(forKey defaultName: String) -> Bool {
        storage[defaultName] as? Bool ?? false
    }

    func data(forKey defaultName: String) -> Data? {
        storage[defaultName] as? Data
    }

    func string(forKey defaultName: String) -> String? {
        storage[defaultName] as? String
    }

    func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }

    func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }
}
