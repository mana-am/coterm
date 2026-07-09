import Foundation

/// The token pair carried by a Coterm auth callback URL
/// (`coterm://auth-callback?coterm_refresh=…&coterm_access=…`).
public struct AuthCallbackPayload: Equatable, Sendable {
    /// The Coterm-native refresh token from the callback.
    public let refreshToken: String
    /// The Coterm-native access token from the callback.
    public let accessToken: String

    /// Creates a payload from its parts.
    public init(refreshToken: String, accessToken: String) {
        self.refreshToken = refreshToken
        self.accessToken = accessToken
    }
}
