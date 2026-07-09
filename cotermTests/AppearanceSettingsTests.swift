import XCTest
import AppKit
import SwiftUI

#if canImport(Coterm_DEV)
@testable import Coterm_DEV
#elseif canImport(Coterm)
@testable import Coterm
#endif

@MainActor
final class AppearanceSettingsTests: XCTestCase {
    func testBundleIconPersistenceAllowsStableReleaseBundle() {
        XCTAssertTrue(
            AppBundleIconPersistencePolicy.shouldPersist(
                bundleIdentifier: "coterm.com.emergent.app",
                appBundleLastPathComponent: "Coterm.app",
                persistenceDisabled: false
            )
        )
    }

    func testBundleIconPersistenceSkipsNightlyBundles() {
        XCTAssertFalse(
            AppBundleIconPersistencePolicy.shouldPersist(
                bundleIdentifier: "coterm.com.emergent.app.nightly",
                appBundleLastPathComponent: "Coterm NIGHTLY.app",
                persistenceDisabled: false
            )
        )
        XCTAssertFalse(
            AppBundleIconPersistencePolicy.shouldPersist(
                bundleIdentifier: "coterm.com.emergent.app.nightly.issue-4350",
                appBundleLastPathComponent: "Coterm NIGHTLY issue-4350.app",
                persistenceDisabled: false
            )
        )
    }

    func testBundleIconPersistenceRejectsMismatchedStableIdentifierAndPath() {
        XCTAssertFalse(
            AppBundleIconPersistencePolicy.shouldPersist(
                bundleIdentifier: "coterm.com.emergent.app",
                appBundleLastPathComponent: "Coterm NIGHTLY.app",
                persistenceDisabled: false
            )
        )
    }

    func testBundleIconPersistenceSkipsDebugBundles() {
        XCTAssertFalse(
            AppBundleIconPersistencePolicy.shouldPersist(
                bundleIdentifier: "coterm.com.emergent.app.debug",
                appBundleLastPathComponent: "Coterm DEV.app",
                persistenceDisabled: false
            )
        )
        XCTAssertFalse(
            AppBundleIconPersistencePolicy.shouldPersist(
                bundleIdentifier: "coterm.com.emergent.app.debug.issue-4350",
                appBundleLastPathComponent: "Coterm DEV issue-4350.app",
                persistenceDisabled: false
            )
        )
    }

    func testBundleIconPersistenceHonorsDisableDefault() {
        XCTAssertFalse(
            AppBundleIconPersistencePolicy.shouldPersist(
                bundleIdentifier: "coterm.com.emergent.app",
                appBundleLastPathComponent: "Coterm.app",
                persistenceDisabled: true
            )
        )
    }

    func testBundleIconPersistenceMirrorsSmokeLaunchArgumentToDefaults() {
        let suiteName = "AppearanceSettingsTests.BundleIconPersistence.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        AppBundleIconPersistencePolicy.updateDisableDefault(
            defaults: defaults,
            launchArguments: [AppBundleIconPersistencePolicy.disablePersistenceArgument]
        )
        XCTAssertEqual(
            defaults.object(forKey: AppBundleIconPersistencePolicy.disablePersistenceDefaultsKey) as? Bool,
            true
        )

        AppBundleIconPersistencePolicy.updateDisableDefault(
            defaults: defaults,
            launchArguments: []
        )
        XCTAssertEqual(
            defaults.object(forKey: AppBundleIconPersistencePolicy.disablePersistenceDefaultsKey) as? Bool,
            false
        )
    }

    func testAppConfigReloadRefreshUpdatesSurfaceConfigBeforeRedraw() throws {
        let fakeSurface = try XCTUnwrap(UnsafeMutableRawPointer(bitPattern: 0x3851))
        var events: [String] = []

        GhosttySurfaceConfigurationRefresh.applyAfterAppConfigReload(
            to: fakeSurface,
            source: "appearanceSync:test",
            reloadSurfaceConfiguration: { surface, soft, source in
                XCTAssertEqual(surface, fakeSurface)
                XCTAssertTrue(soft)
                events.append("reload:\(source)")
            },
            applySurfaceColorScheme: {
                events.append("color-scheme")
            },
            refreshHostBackground: {
                events.append("host-background")
            },
            forceRefresh: { reason in
                events.append("force-refresh:\(reason)")
            }
        )

        XCTAssertEqual(events, [
            "color-scheme",
            "reload:appearanceSync:test",
            "host-background",
            "force-refresh:\(GhosttySurfaceConfigurationRefresh.forceRefreshReason)"
        ])
    }

    func testAppConfigReloadRefreshSkipsSurfaceConfigUpdateWhenSurfaceIsUnavailable() {
        var events: [String] = []

        GhosttySurfaceConfigurationRefresh.applyAfterAppConfigReload(
            to: nil,
            source: "appearanceSync:teardown",
            reloadSurfaceConfiguration: { _, _, _ in
                events.append("reload")
            },
            applySurfaceColorScheme: {
                events.append("color-scheme")
            },
            refreshHostBackground: {
                events.append("host-background")
            },
            forceRefresh: { reason in
                events.append("force-refresh:\(reason)")
            }
        )

        XCTAssertEqual(events, [
            "host-background",
            "force-refresh:\(GhosttySurfaceConfigurationRefresh.forceRefreshReason)"
        ])
    }

    func testAppConfigReloadRefreshAppliesSurfaceColorSchemeForPreviewReload() throws {
        let fakeSurface = try XCTUnwrap(UnsafeMutableRawPointer(bitPattern: 0x3852))
        var events: [String] = []

        GhosttySurfaceConfigurationRefresh.applyAfterAppConfigReload(
            to: fakeSurface,
            source: GhosttySurfaceConfigurationRefresh.cotermThemeReloadPreviewSource,
            reloadSurfaceConfiguration: { _, soft, source in
                XCTAssertTrue(soft)
                events.append("reload:\(source)")
            },
            applySurfaceColorScheme: {
                events.append("color-scheme")
            },
            refreshHostBackground: {
                events.append("host-background")
            },
            forceRefresh: { reason in
                events.append("force-refresh:\(reason)")
            }
        )

        XCTAssertEqual(events, [
            "color-scheme",
            "reload:\(GhosttySurfaceConfigurationRefresh.cotermThemeReloadPreviewSource)",
            "host-background",
            "force-refresh:\(GhosttySurfaceConfigurationRefresh.forceRefreshReason)"
        ])
    }

    func testCotermThemeFinalReloadUsesFinalSource() {
        XCTAssertEqual(
            GhosttySurfaceConfigurationRefresh.cotermThemeReloadSource(phase: "final"),
            GhosttySurfaceConfigurationRefresh.cotermThemeReloadFinalSource
        )
    }

    func testCotermThemePreviewReloadIsDebounced() {
        XCTAssertEqual(
            GhosttySurfaceConfigurationRefresh.cotermThemeReloadSource(phase: "preview"),
            GhosttySurfaceConfigurationRefresh.cotermThemeReloadPreviewSource
        )
        XCTAssertTrue(
            GhosttySurfaceConfigurationRefresh.shouldDebounceCotermThemeReload(
                source: GhosttySurfaceConfigurationRefresh.cotermThemeReloadPreviewSource
            )
        )
        XCTAssertTrue(
            GhosttySurfaceConfigurationRefresh.shouldDebounceCotermThemeReload(
                source: GhosttySurfaceConfigurationRefresh.cotermThemeReloadLegacySource
            )
        )
        XCTAssertFalse(
            GhosttySurfaceConfigurationRefresh.shouldDebounceCotermThemeReload(
                source: GhosttySurfaceConfigurationRefresh.cotermThemeReloadFinalSource
            )
        )
    }

    func testApplyFixedAppearancePinsDarkAqua() {
        AppearanceSettings.applyFixedAppearance()
        XCTAssertEqual(
            NSApplication.shared.appearance?.bestMatch(from: [.darkAqua, .aqua]),
            .darkAqua
        )
    }

    func testCurrentColorSchemePreferenceIsAlwaysDarkRegardlessOfSystemStyle() {
        withTemporaryAppearanceDefaults(
            appearanceMode: "light",
            appleInterfaceStyle: nil
        ) {
            XCTAssertEqual(GhosttyConfig.currentColorSchemePreference(), .dark)
        }
        withTemporaryAppearanceDefaults(
            appearanceMode: "system",
            appleInterfaceStyle: nil
        ) {
            XCTAssertEqual(GhosttyConfig.currentColorSchemePreference(), .dark)
        }
        withTemporaryAppearanceDefaults(
            appearanceMode: "dark",
            appleInterfaceStyle: "Dark"
        ) {
            XCTAssertEqual(GhosttyConfig.currentColorSchemePreference(), .dark)
        }
    }

    func testSplitGhosttyThemeAlwaysResolvesDarkSide() {
        let preferredColorScheme = GhosttyConfig.currentColorSchemePreference()
        let resolvedTheme = GhosttyConfig.resolveThemeName(
            from: "light:Catppuccin Latte,dark:Apple System Colors",
            preferredColorScheme: preferredColorScheme
        )

        XCTAssertEqual(preferredColorScheme, .dark)
        XCTAssertEqual(resolvedTheme, "Apple System Colors")
    }

    /// Legacy `appearanceMode` UserDefaults values left over from before the
    /// fixed-dark change must not influence resolution.
    private func withTemporaryAppearanceDefaults(
        appearanceMode: String,
        appleInterfaceStyle: String?,
        body: () -> Void
    ) {
        let defaults = UserDefaults.standard
        let appearanceModeKey = "appearanceMode"
        let originalAppearanceMode = defaults.object(forKey: appearanceModeKey)
        let originalAppleInterfaceStyle = defaults.object(forKey: "AppleInterfaceStyle")
        defer {
            restoreDefaultsValue(
                originalAppearanceMode,
                key: appearanceModeKey,
                defaults: defaults
            )
            restoreDefaultsValue(
                originalAppleInterfaceStyle,
                key: "AppleInterfaceStyle",
                defaults: defaults
            )
        }

        defaults.set(appearanceMode, forKey: appearanceModeKey)
        if let appleInterfaceStyle {
            defaults.set(appleInterfaceStyle, forKey: "AppleInterfaceStyle")
        } else {
            defaults.removeObject(forKey: "AppleInterfaceStyle")
        }
        body()
    }

    private func restoreDefaultsValue(_ value: Any?, key: String, defaults: UserDefaults) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

}
