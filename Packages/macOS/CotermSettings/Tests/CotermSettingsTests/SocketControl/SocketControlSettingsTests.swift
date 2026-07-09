import Testing

import CotermSettings

@Suite struct SocketControlSettingsTests {
    @Test func migrateModeMapsLegacyAndUnknownValues() {
        #expect(SocketControlSettings.migrateMode("off") == .off)
        #expect(SocketControlSettings.migrateMode("coterm_only") == .cotermOnly)
        #expect(SocketControlSettings.migrateMode("ALLOW-ALL") == .allowAll)
        // Legacy aliases.
        #expect(SocketControlSettings.migrateMode("notifications") == .automation)
        #expect(SocketControlSettings.migrateMode("full") == .allowAll)
        // Unknown falls back to the default.
        #expect(SocketControlSettings.migrateMode("bogus") == .cotermOnly)
    }

    @Test func effectiveModeHonorsEnableOverride() {
        #expect(
            SocketControlSettings.effectiveMode(
                userMode: .password,
                environment: ["COTERM_SOCKET_ENABLE": "0"]
            ) == .off
        )
        #expect(
            SocketControlSettings.effectiveMode(
                userMode: .off,
                environment: ["COTERM_SOCKET_ENABLE": "1"]
            ) == .cotermOnly
        )
    }

    @Test func effectiveModeHonorsModeOverride() {
        #expect(
            SocketControlSettings.effectiveMode(
                userMode: .cotermOnly,
                environment: ["COTERM_SOCKET_MODE": "allowall"]
            ) == .allowAll
        )
    }

    @Test func effectiveModeFallsBackToUserMode() {
        #expect(
            SocketControlSettings.effectiveMode(userMode: .automation, environment: [:]) == .automation
        )
    }

    @Test func truthyParsing() {
        for value in ["1", "true", "YES", "on"] {
            #expect(SocketControlSettings.isTruthy(value))
        }
        for value in ["0", "false", "", "nope"] {
            #expect(!SocketControlSettings.isTruthy(value))
        }
    }

    @Test func taggedDevBuildDetection() {
        #expect(SocketControlSettings.isTaggedDevBuild(bundleIdentifier: "coterm.com.emergent.app.debug.my-tag"))
        #expect(!SocketControlSettings.isTaggedDevBuild(bundleIdentifier: "coterm.com.emergent.app.debug"))
        #expect(!SocketControlSettings.isTaggedDevBuild(bundleIdentifier: "coterm.com.emergent.app"))
    }

    @Test func untaggedDebugLaunchIsBlockedOnlyForBareDebugBundle() {
        // Bare debug bundle, no tag, not under test => blocked.
        #expect(
            SocketControlSettings.shouldBlockUntaggedDebugLaunch(
                environment: [:],
                bundleIdentifier: "coterm.com.emergent.app.debug",
                isDebugBuild: true
            )
        )
        // XCUITest launches the app as a separate process without XCTest env vars,
        // so any COTERM_UI_TEST_ marker must bypass blocking for a bare debug bundle.
        #expect(
            !SocketControlSettings.shouldBlockUntaggedDebugLaunch(
                environment: ["COTERM_UI_TEST_RUN": "1"],
                bundleIdentifier: "coterm.com.emergent.app.debug",
                isDebugBuild: true
            )
        )
        // Tagged debug bundle => allowed.
        #expect(
            !SocketControlSettings.shouldBlockUntaggedDebugLaunch(
                environment: [:],
                bundleIdentifier: "coterm.com.emergent.app.debug.tag",
                isDebugBuild: true
            )
        )
        // Release build => never blocked.
        #expect(
            !SocketControlSettings.shouldBlockUntaggedDebugLaunch(
                environment: [:],
                bundleIdentifier: "coterm.com.emergent.app",
                isDebugBuild: false
            )
        )
    }

    @Test func socketPathHonorsOverrideForTaggedDevWhenAllowed() {
        let path = SocketControlSettings.socketPath(
            environment: [
                "COTERM_SOCKET_PATH": "/tmp/coterm-custom.sock",
                "COTERM_ALLOW_SOCKET_OVERRIDE": "1",
            ],
            bundleIdentifier: "coterm.com.emergent.app.debug.tag",
            isDebugBuild: true,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .missing }
        )
        #expect(path == "/tmp/coterm-custom.sock")
    }

    @Test func bareDebugXCTestLaunchUsesScopedSocketFallback() {
        let environment = [
            "XCTestConfigurationFilePath": "/tmp/Test-coterm-unit-2026.06.17.xctestconfiguration",
        ]
        let path = SocketControlSettings.socketPath(
            environment: environment,
            bundleIdentifier: "coterm.com.emergent.app.debug",
            isDebugBuild: true,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .missing }
        )
        let defaultPath = SocketControlSettings.defaultSocketPath(
            bundleIdentifier: "coterm.com.emergent.app.debug",
            environment: environment,
            isDebugBuild: true,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .missing }
        )
        #expect(path.hasPrefix("/tmp/coterm-xctest-"))
        #expect(path.hasSuffix(".sock"))
        #expect(path != "/tmp/coterm-debug.sock")
        #expect(path == defaultPath)
    }

    @Test func explicitSocketOverrideStillWinsUnderXCTest() {
        let path = SocketControlSettings.socketPath(
            environment: [
                "COTERM_SOCKET_PATH": "/tmp/coterm-forced.sock",
                "XCTestConfigurationFilePath": "/tmp/Test-coterm-unit-2026.06.17.xctestconfiguration",
            ],
            bundleIdentifier: "coterm.com.emergent.app.debug",
            isDebugBuild: true,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .missing }
        )
        #expect(path == "/tmp/coterm-forced.sock")
    }

    @Test func dyldOnlyXCTestLaunchUsesScopedSocketFallback() {
        let path = SocketControlSettings.socketPath(
            environment: [
                "DYLD_INSERT_LIBRARIES": "/Applications/Xcode.app/Contents/Developer/usr/lib/libXCTestSwiftSupport.dylib",
            ],
            bundleIdentifier: "coterm.com.emergent.app.debug",
            isDebugBuild: true,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .missing }
        )
        #expect(path.hasPrefix("/tmp/coterm-xctest-"))
        #expect(path.hasSuffix(".sock"))
        #expect(path != "/tmp/coterm-debug.sock")
    }

    @Test func xctestSocketFallbackHashesFullPath() {
        let first = SocketControlSettings.socketPath(
            environment: [
                "XCTestConfigurationFilePath": "/tmp/first/Test-coterm-unit.xctestconfiguration",
            ],
            bundleIdentifier: "coterm.com.emergent.app.debug",
            isDebugBuild: true,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .missing }
        )
        let second = SocketControlSettings.socketPath(
            environment: [
                "XCTestConfigurationFilePath": "/tmp/second/Test-coterm-unit.xctestconfiguration",
            ],
            bundleIdentifier: "coterm.com.emergent.app.debug",
            isDebugBuild: true,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .missing }
        )
        #expect(first.hasPrefix("/tmp/coterm-xctest-"))
        #expect(second.hasPrefix("/tmp/coterm-xctest-"))
        #expect(first != second)
    }

    @Test func taggedDebugXCTestLaunchStillUsesTaggedSocket() {
        let path = SocketControlSettings.socketPath(
            environment: [
                "COTERM_TAG": "ci-split-theme",
                "XCTestConfigurationFilePath": "/tmp/Test-coterm-unit-2026.06.17.xctestconfiguration",
            ],
            bundleIdentifier: "coterm.com.emergent.app.debug",
            isDebugBuild: true,
            currentUserID: 501,
            probeStableDefaultPathEntry: { _ in .missing }
        )
        #expect(path == "/tmp/coterm-debug-ci-split-theme.sock")
    }
}
