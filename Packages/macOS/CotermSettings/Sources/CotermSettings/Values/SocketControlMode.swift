import Foundation

/// Controls which clients may connect to the coterm automation socket.
///
/// Stored under the catalog entry ``SettingCatalog/automationSocketControlMode``.
/// The cases mirror the on-disk strings used by `~/.config/coterm/coterm.json` and
/// the legacy UserDefaults value, so the raw values must not be renamed without
/// a migration.
public enum SocketControlMode: String, CaseIterable, Sendable, SettingCodable {
    /// The automation socket is not exposed.
    case off
    /// Only the bundled `coterm` CLI may connect.
    case cotermOnly
    /// Automation tools (e.g. hooks for Claude, Cursor, Gemini) may connect.
    case automation
    /// Clients must present a password configured under
    /// ``SettingCatalog/automationSocketPassword``.
    case password
    /// Any local client may connect. Treat as developer-only.
    case allowAll
}
