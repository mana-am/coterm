import Foundation

enum AuthEnvironment {
    private static let developmentStackProjectID = "454ecd03-1db2-4050-845e-4ce5b0cd9895"
    private static let developmentStackPublishableClientKey = "pck_xb63160bwe9699vtxfzfj6emmxpafg5mkjrtp6ehzxv5g"
    private static let productionStackProjectID = "9790718f-14cd-4f7e-824d-eaf527a82b82"
    private static let productionStackPublishableClientKey = "pck_kzj80gx4mh2jrzn1cx6y5e8jk0kwa01vkevh2p9zd4twr"
    private static let collaborationGuestIDDefaultsKey = "CotermCollaborationGuestID"
    private static let collaborationGuestAvatarDefaultsKey = "CotermCollaborationGuestAvatarURL"

    static var callbackScheme: String {
        let bundleIdentifier = Bundle.main.bundleIdentifier
        return callbackScheme(
            environment: ProcessInfo.processInfo.environment,
            bundleIdentifier: bundleIdentifier,
            registeredURLSchemes: registeredURLSchemes(in: Bundle.main),
            isDebugBuild: isDebugBundleIdentifier(bundleIdentifier)
        )
    }

    static func callbackScheme(
        environment: [String: String],
        bundleIdentifier: String?
    ) -> String {
        callbackScheme(
            environment: environment,
            bundleIdentifier: bundleIdentifier,
            isDebugBuild: isDebugBundleIdentifier(bundleIdentifier)
        )
    }

    static func callbackScheme(
        environment: [String: String],
        bundleIdentifier: String?,
        isDebugBuild: Bool
    ) -> String {
        callbackScheme(
            environment: environment,
            bundleIdentifier: bundleIdentifier,
            registeredURLSchemes: [],
            isDebugBuild: isDebugBuild
        )
    }

    static func callbackScheme(
        environment: [String: String],
        bundleIdentifier: String?,
        registeredURLSchemes: [String],
        isDebugBuild: Bool
    ) -> String {
        if let overridden = environment["COTERM_AUTH_CALLBACK_SCHEME"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !overridden.isEmpty {
            return overridden
        }
        if isDebugBuild {
            // Untagged Debug builds register coterm-dev:// so they can coexist
            // with the installed stable app. Tagged Debug builds use
            // coterm-dev-<tag>://.
            if let tag = environment["COTERM_TAG"]?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !tag.isEmpty,
               let schemeTag = sanitizedCallbackSchemeTag(tag) {
                return "coterm-dev-\(schemeTag)"
            }
            if let registered = registeredURLSchemes
                .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
                .first(where: { $0.hasPrefix("coterm-dev-") }) {
                return registered
            }
            if let schemeTag = debugSchemeTag(fromBundleIdentifier: bundleIdentifier) {
                return "coterm-dev-\(schemeTag)"
            }
            return "coterm-dev"
        }
        if bundleIdentifier == "cc.coterm.app.nightly" {
            return "coterm-nightly"
        }
        return "coterm"
    }

    private static func debugSchemeTag(fromBundleIdentifier bundleIdentifier: String?) -> String? {
        guard let bundleIdentifier else { return nil }
        let prefix = "cc.coterm.app.debug."
        guard bundleIdentifier.hasPrefix(prefix) else { return nil }
        let suffix = String(bundleIdentifier.dropFirst(prefix.count))
        return sanitizedCallbackSchemeTag(suffix)
    }

    private static func registeredURLSchemes(in bundle: Bundle) -> [String] {
        guard let types = bundle.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return []
        }
        return types.flatMap { type in
            type["CFBundleURLSchemes"] as? [String] ?? []
        }
    }

    private static func isDebugBundleIdentifier(_ bundleIdentifier: String?) -> Bool {
        bundleIdentifier?.hasPrefix("cc.coterm.app.debug") == true
    }

    static func sanitizedCallbackSchemeTag(_ rawTag: String) -> String? {
        let lowercased = rawTag.lowercased()
        var result = ""
        var previousWasHyphen = false
        for scalar in lowercased.unicodeScalars {
            let isAllowed = (scalar.value >= 97 && scalar.value <= 122)
                || (scalar.value >= 48 && scalar.value <= 57)
            if isAllowed {
                result.unicodeScalars.append(scalar)
                previousWasHyphen = false
            } else if !previousWasHyphen {
                result.append("-")
                previousWasHyphen = true
            }
        }
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return result.isEmpty ? nil : result
    }

    static var callbackURL: URL {
        URL(string: "\(callbackScheme)://auth-callback")!
    }

    static func resolvedCallbackURL(
        environment: [String: String],
        bundleIdentifier: String?
    ) -> URL {
        URL(string: "\(callbackScheme(environment: environment, bundleIdentifier: bundleIdentifier))://auth-callback")!
    }

    static var websiteOrigin: URL {
        resolvedURL(
            environmentKey: "COTERM_WWW_ORIGIN",
            fallback: "https://coterm.cc"
        )
    }

    static var signInWebsiteOrigin: URL {
        canonicalizedLoopbackURL(
            resolvedURL(
                environmentKey: "COTERM_AUTH_WWW_ORIGIN",
                fallback: defaultAuthWebOrigin
            )
        )
    }

    /// Hosted browser auth is opt-in for Coterm. The public build is self-host
    /// first and must not generate a coterm.cc/dashboard sign-in URL unless a
    /// developer explicitly points it at an auth-capable self-hosted origin.
    static var hostedAuthEnabled: Bool {
        if hostedAuthEnabled(environment: ProcessInfo.processInfo.environment) {
            return true
        }
        #if DEBUG
        return devOverride(key: "COTERM_AUTH_WWW_ORIGIN") != nil
        #else
        return false
        #endif
    }

    static func hostedAuthEnabled(environment: [String: String]) -> Bool {
        if let origin = environment["COTERM_AUTH_WWW_ORIGIN"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !origin.isEmpty {
            return true
        }
        return false
    }

    static var apiBaseURL: URL {
        // Process env wins; then `~/.coterm-dev.env` (DEBUG only) so a
        // click-launched tagged build can point at a self-hosted backend without
        // a shell; then the production default.
        let fallback = devOverride(key: "COTERM_API_BASE_URL") ?? defaultAPIBaseURL
        return canonicalizedLoopbackURL(
            resolvedURL(
                environmentKey: "COTERM_API_BASE_URL",
                fallback: fallback
            )
        )
    }

    static var selfHostedCollaborationConfigured: Bool {
        if let configured = ProcessInfo.processInfo.environment["COTERM_API_BASE_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !configured.isEmpty {
            return true
        }
        #if DEBUG
        return devOverride(key: "COTERM_API_BASE_URL") != nil
        #else
        return false
        #endif
    }

    /// Offline collaboration "guest" identity. Explicit process env or
    /// `~/.coterm-dev.env` values win. When hosted auth is not enabled, Coterm
    /// automatically falls back to a local guest identity so sharing never opens
    /// the browser sign-in prompt in the self-hosted build.
    static var collaborationGuestID: String? {
        if let configured = collaborationGuestValue(
            "COTERM_COLLAB_GUEST_ID",
            defaultsKey: collaborationGuestIDDefaultsKey
        ) {
            return configured
        }
        guard !hostedAuthEnabled else { return nil }
        return defaultCollaborationGuestID()
    }

    /// Optional avatar (image URL) shown next to the guest id.
    static var collaborationGuestAvatarURL: String? {
        collaborationGuestValue(
            "COTERM_COLLAB_GUEST_AVATAR",
            defaultsKey: collaborationGuestAvatarDefaultsKey
        )
    }

    static func saveCollaborationGuestIdentity(id: String?, avatarURL: String?) {
        saveCollaborationGuestValue(id, defaultsKey: collaborationGuestIDDefaultsKey)
        saveCollaborationGuestValue(avatarURL, defaultsKey: collaborationGuestAvatarDefaultsKey)
    }

    /// Override for the collaboration relay WebSocket base URL. Lets a self-hosted
    /// deployment (or local dev) use its own relay instead of the built-in default.
    static var collaborationRelayURLOverride: String? {
        collaborationGuestValue("COTERM_COLLABORATION_RELAY_URL")
    }

    private static func collaborationGuestValue(_ key: String, defaultsKey: String? = nil) -> String? {
        if let value = ProcessInfo.processInfo.environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }
        if let defaultsKey,
           let value = UserDefaults.standard.string(forKey: defaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }
        return devOverride(key: key)
    }

    private static func saveCollaborationGuestValue(_ value: String?, defaultsKey: String) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: defaultsKey)
        }
    }

    private static func defaultCollaborationGuestID() -> String {
        let displayName = NSFullUserName()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
            ?? NSUserName().trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? "coterm-user"
        let hostName = Host.current().localizedName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
            ?? ProcessInfo.processInfo.hostName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
            ?? "mac"
        return "\(displayName)@\(hostName)"
    }

    /// Base URL for the coterm-owned cloud VM backend (`/api/vm`).
    ///
    /// Resolution order (first hit wins):
    ///   1. process env `COTERM_VM_API_BASE_URL` — works when the app is launched from a shell.
    ///   2. `~/.coterm-dev.env` file `COTERM_VM_API_BASE_URL=...` line — works regardless of how
    ///      the app was launched (click-through, Dock, `open`, etc.). Only honored in DEBUG.
    ///   3. VM backend dev origin (`http://localhost:$COTERM_PORT` in Debug, coterm.cc in Release).
    static var vmAPIBaseURL: URL {
        if let overridden = ProcessInfo.processInfo.environment["COTERM_VM_API_BASE_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !overridden.isEmpty,
           let url = URL(string: overridden) {
            return canonicalizedLoopbackURL(url)
        }
        if let override = devOverride(key: "COTERM_VM_API_BASE_URL"),
           let url = URL(string: override) {
            return canonicalizedLoopbackURL(url)
        }
        return canonicalizedLoopbackURL(URL(string: defaultVMAPIOrigin)!)
    }

    /// Look up `key=value` in `~/.coterm-dev.env` for the DEBUG build. Returns nil in Release.
    /// Kept tiny on purpose — this is a "drop a file, restart the app, it picks up" override,
    /// not a real config system.
    private static func devOverride(key: String) -> String? {
        #if DEBUG
        guard let home = ProcessInfo.processInfo.environment["HOME"] else { return nil }
        let path = (home as NSString).appendingPathComponent(".coterm-dev.env")
        guard let data = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        for raw in data.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.hasPrefix("#"), let eq = line.firstIndex(of: "=") else { continue }
            let k = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            guard k == key else { continue }
            var v = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            if v.hasPrefix("\"") && v.hasSuffix("\"") { v = String(v.dropFirst().dropLast()) }
            if v.hasPrefix("'") && v.hasSuffix("'") { v = String(v.dropFirst().dropLast()) }
            return v.isEmpty ? nil : v
        }
        return nil
        #else
        return nil
        #endif
    }

    private static var cotermPort: String {
        resolvedCotermPort(environment: ProcessInfo.processInfo.environment)
    }

    private static func resolvedCotermPort(environment: [String: String]) -> String {
        environmentPort("COTERM_PORT", environment: environment)
            ?? environmentPort("PORT", environment: environment)
            ?? "3777"
    }

    private static func environmentPort(_ key: String) -> String? {
        environmentPort(key, environment: ProcessInfo.processInfo.environment)
    }

    private static func environmentPort(_ key: String, environment: [String: String]) -> String? {
        guard let port = environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            let value = UInt16(port),
            value > 0
        else {
            return nil
        }
        return port
    }

    private static var defaultWebOrigin: String {
        resolvedDefaultWebOrigin(environment: ProcessInfo.processInfo.environment)
    }

    private static func resolvedDefaultWebOrigin(environment: [String: String]) -> String {
        if let origin = environment["COTERM_WWW_ORIGIN"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !origin.isEmpty {
            return origin
        }
        return "https://coterm.cc"
    }

    private static var defaultAuthWebOrigin: String {
        resolvedDefaultAuthWebOrigin(environment: ProcessInfo.processInfo.environment)
    }

    private static func resolvedDefaultAuthWebOrigin(environment: [String: String]) -> String {
        if let origin = environment["COTERM_AUTH_WWW_ORIGIN"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !origin.isEmpty {
            return origin
        }
        return "https://coterm.cc"
    }

    private static var defaultVMAPIOrigin: String {
        #if DEBUG
        return "http://localhost:\(cotermPort)"
        #else
        return "https://coterm.cc"
        #endif
    }

    private static var defaultAPIBaseURL: String {
        if let url = ProcessInfo.processInfo.environment["COTERM_API_BASE_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !url.isEmpty {
            return url
        }
        return "https://coterm.cc"
    }

    static var stackBaseURL: URL {
        resolvedURL(
            environmentKey: "COTERM_STACK_BASE_URL",
            fallback: "https://api.stack-auth.com"
        )
    }

    static var stackProjectID: String {
        let environment = ProcessInfo.processInfo.environment
        if let projectID = environment["COTERM_STACK_PROJECT_ID"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !projectID.isEmpty {
            return projectID
        }
        #if DEBUG
        return developmentStackProjectID
        #else
        return productionStackProjectID
        #endif
    }

    static var stackPublishableClientKey: String {
        let environment = ProcessInfo.processInfo.environment
        if let clientKey = environment["COTERM_STACK_PUBLISHABLE_CLIENT_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !clientKey.isEmpty {
            return clientKey
        }
        #if DEBUG
        return developmentStackPublishableClientKey
        #else
        return productionStackPublishableClientKey
        #endif
    }

    /// The website origin used for the after-sign-in handler.
    static var afterSignInOrigin: URL {
        resolvedAfterSignInOrigin(environment: ProcessInfo.processInfo.environment)
    }

    static func resolvedAfterSignInOrigin(environment: [String: String]) -> URL {
        resolvedURL(
            environmentKey: "COTERM_AUTH_WWW_ORIGIN",
            fallback: resolvedDefaultAuthWebOrigin(environment: environment),
            environment: environment
        )
    }

    static func signInURL(callbackState: String? = nil) -> URL {
        signInURL(callbackState: callbackState, afterSignInOrigin: afterSignInOrigin, callbackURL: callbackURL)
    }

    static func signInURL(
        callbackState: String? = nil,
        environment: [String: String],
        bundleIdentifier: String? = nil
    ) -> URL {
        signInURL(
            callbackState: callbackState,
            afterSignInOrigin: resolvedAfterSignInOrigin(environment: environment),
            callbackURL: resolvedCallbackURL(environment: environment, bundleIdentifier: bundleIdentifier)
        )
    }

    private static func signInURL(
        callbackState: String?,
        afterSignInOrigin: URL,
        callbackURL: URL
    ) -> URL {
        // Build the after-sign-in callback URL that includes the native app return scheme.
        // The after-sign-in handler exchanges the Clerk browser session for
        // Coterm-native tokens, then redirects to the app callback scheme.
        var afterSignInComponents = URLComponents(
            url: afterSignInOrigin.appendingPathComponent("handler/after-sign-in", isDirectory: false),
            resolvingAgainstBaseURL: false
        )!
        var nativeCallbackComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)!
        if let callbackState {
            nativeCallbackComponents.queryItems = [
                URLQueryItem(name: "coterm_auth_state", value: callbackState),
            ]
        }

        afterSignInComponents.percentEncodedQuery = encodedQuery([
            ("native_app_return_to", nativeCallbackComponents.url!.absoluteString),
        ])

        // Enter through Coterm's native sign-in wrapper, which sets a short-lived
        // server-side handoff nonce before redirecting to Clerk's /sign-in.
        var components = URLComponents(
            url: afterSignInOrigin.appendingPathComponent("handler/native-sign-in", isDirectory: false),
            resolvingAgainstBaseURL: false
        )!
        components.percentEncodedQuery = encodedQuery([
            ("after_auth_return_to", afterSignInComponents.url!.absoluteString),
        ])
        return components.url!
    }

    private static func encodedQuery(_ items: [(String, String)]) -> String {
        items
            .map { name, value in
                "\(strictQueryEncode(name))=\(strictQueryEncode(value))"
            }
            .joined(separator: "&")
    }

    private static func strictQueryEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":/?#[]@!$&'()*+,;=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func resolvedURL(environmentKey: String, fallback: String) -> URL {
        resolvedURL(
            environmentKey: environmentKey,
            fallback: fallback,
            environment: ProcessInfo.processInfo.environment
        )
    }

    private static func resolvedURL(
        environmentKey: String,
        fallback: String,
        environment: [String: String]
    ) -> URL {
        if let overridden = environment[environmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !overridden.isEmpty,
           let url = URL(string: overridden) {
            return url
        }
        return URL(string: fallback)!
    }

    private static func canonicalizedLoopbackURL(_ url: URL) -> URL {
        guard let host = url.host?.lowercased() else {
            return url
        }

        let loopbackHosts = ["127.0.0.1", "::1", "[::1]", "0.0.0.0"]
        guard loopbackHosts.contains(host) else {
            return url
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.host = "localhost"
        return components?.url ?? url
    }
}

/// Offline collaboration "guest" mode.
///
/// When hosted auth is disabled, collaboration runs with no account and no
/// browser sign-in: the explicit or automatically generated guest id is the
/// identity, and the access token is a locally-minted `cotermv1`-shaped token
/// whose payload the self-hosted control-plane can decode in `noauth` mode.
enum CollaborationGuestSession {
    /// Whether offline guest mode is active.
    static var isEnabled: Bool { AuthEnvironment.collaborationGuestID != nil }

    /// The chosen guest id (display name + participant id), or nil when disabled.
    static var guestID: String? { AuthEnvironment.collaborationGuestID }

    /// The chosen guest avatar image URL, if any.
    static var avatarURL: String? { AuthEnvironment.collaborationGuestAvatarURL }

    /// Mint an unsigned `cotermv1`-shaped access token carrying `id` as the user
    /// id. Shape: `cotermv1.<base64url(JSON payload)>.<placeholder-signature>`.
    static func accessToken(id: String, now: Date = Date()) -> String {
        let iat = Int(now.timeIntervalSince1970)
        let payload: [String: Any] = [
            "kind": "access",
            "userId": id,
            "teamIds": [String](),
            "selectedTeamId": NSNull(),
            "exp": iat + 86_400,
            "iat": iat,
            "nonce": UUID().uuidString,
        ]
        let data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
        let base64url = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "cotermv1.\(base64url).guest"
    }
}
