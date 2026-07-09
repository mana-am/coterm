import Foundation

/// Settings under the dotted-id prefix `account.*` — account-related
/// preferences that persist locally regardless of whether the user is
/// signed in to the coterm backend.
///
/// The sign-in flow, token storage, and `CotermAuthUser` model itself
/// live in the host app's auth package and reach the package's
/// ``AccountSection`` via an injected delegate (see ``AccountFlow``
/// in CotermSettingsUI), not through this catalog.
public struct AccountCatalogSection: SettingCatalogSection {
    public let piiDisplayMode = DefaultsKey<PIIDisplayMode>(
        id: "account.piiDisplayMode",
        defaultValue: .visible,
        userDefaultsKey: "coterm.settings.piiDisplayMode"
    )

    public let selectedTeamID = DefaultsKey<String>(
        id: "account.selectedTeamID",
        defaultValue: "",
        userDefaultsKey: "coterm.auth.selectedTeamID"
    )

    public let welcomeShown = DefaultsKey<Bool>(
        id: "account.welcomeShown",
        defaultValue: false,
        userDefaultsKey: "cotermWelcomeShown"
    )

    public init() {}
}
