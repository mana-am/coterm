import Foundation

/// User-selected language for the coterm UI. Raw values match the
/// `AppleLanguages` BCP-47 identifiers coterm uses on disk.
public enum AppLanguage: String, CaseIterable, Sendable, SettingCodable {
    case system, en
}
