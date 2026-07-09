import XCTest
import Foundation
import CotermFoundation

#if canImport(Coterm_DEV)
@testable import Coterm_DEV
#elseif canImport(Coterm)
@testable import Coterm
#endif

final class GhosttyConfigPathResolverTests: XCTestCase {
    func testCotermAppSupportConfigURLsUseReleaseConfigForDebugBundleWithoutCurrentConfig() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            let releaseConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "coterm.com.emergent.app",
                filename: "config",
                contents: "font-size = 13\n"
            )

            XCTAssertEqual(
                GhosttyApp.cotermAppSupportConfigURLs(
                    currentBundleIdentifier: "coterm.com.emergent.app.debug",
                    appSupportDirectory: appSupportDirectory
                ),
                [releaseConfigURL]
            )
        }
    }

    func testCotermAppSupportConfigURLsPreferConfigGhosttyOverLegacyConfigWhenBothExist() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            _ = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "coterm.com.emergent.app",
                filename: "config",
                contents: "background = #000000\n"
            )
            let preferredConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "coterm.com.emergent.app",
                filename: "config.ghostty",
                contents: "theme = light:3024 Day,dark:3024 Night\n"
            )

            XCTAssertEqual(
                GhosttyApp.cotermAppSupportConfigURLs(
                    currentBundleIdentifier: "coterm.com.emergent.app.debug.issue-3478",
                    appSupportDirectory: appSupportDirectory
                ),
                [preferredConfigURL]
            )
        }
    }

    func testCotermAppSupportConfigURLsPreferCurrentBundleConfigWhenPresent() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            _ = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "coterm.com.emergent.app",
                filename: "config",
                contents: "font-size = 13\n"
            )
            let currentConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "coterm.com.emergent.app.debug.issue-829",
                filename: "config.ghostty",
                contents: "font-size = 14\n"
            )

            XCTAssertEqual(
                GhosttyApp.cotermAppSupportConfigURLs(
                    currentBundleIdentifier: "coterm.com.emergent.app.debug.issue-829",
                    appSupportDirectory: appSupportDirectory
                ),
                [currentConfigURL]
            )
        }
    }

    func testCotermAppSupportConfigURLsPreserveSymlinkedConfigURL() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            let fileManager = FileManager.default
            let bundleDirectory = appSupportDirectory
                .appendingPathComponent("coterm.com.emergent.app.debug.issue-3518", isDirectory: true)
            try fileManager.createDirectory(at: bundleDirectory, withIntermediateDirectories: true)

            let dotfilesDirectory = appSupportDirectory
                .appendingPathComponent("dotfiles", isDirectory: true)
                .appendingPathComponent("ghostty", isDirectory: true)
            try fileManager.createDirectory(at: dotfilesDirectory, withIntermediateDirectories: true)
            let targetConfigURL = dotfilesDirectory.appendingPathComponent("config.ghostty", isDirectory: false)
            try "font-size = 16\n".write(to: targetConfigURL, atomically: true, encoding: .utf8)

            let symlinkedConfigURL = bundleDirectory.appendingPathComponent("config.ghostty", isDirectory: false)
            try fileManager.createSymbolicLink(
                atPath: symlinkedConfigURL.path,
                withDestinationPath: targetConfigURL.path
            )

            XCTAssertEqual(
                GhosttyApp.cotermAppSupportConfigURLs(
                    currentBundleIdentifier: "coterm.com.emergent.app.debug.issue-3518",
                    appSupportDirectory: appSupportDirectory
                ),
                [symlinkedConfigURL]
            )
        }
    }

    func testConfigSourceEnvironmentSaveWritesThroughSymlinkedCotermConfig() throws {
        try withTemporaryHomeDirectory { homeDirectory in
            let fileManager = FileManager.default
            let appSupportDirectory = homeDirectory
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
            let bundleDirectory = appSupportDirectory
                .appendingPathComponent("coterm.com.emergent.app.debug.issue-3518", isDirectory: true)
            try fileManager.createDirectory(at: bundleDirectory, withIntermediateDirectories: true)

            let dotfilesDirectory = homeDirectory
                .appendingPathComponent("dotfiles", isDirectory: true)
                .appendingPathComponent("ghostty", isDirectory: true)
            try fileManager.createDirectory(at: dotfilesDirectory, withIntermediateDirectories: true)
            let targetConfigURL = dotfilesDirectory.appendingPathComponent("config.ghostty", isDirectory: false)
            try "font-size = 16\n".write(to: targetConfigURL, atomically: true, encoding: .utf8)

            let symlinkedConfigURL = bundleDirectory.appendingPathComponent("config.ghostty", isDirectory: false)
            try fileManager.createSymbolicLink(
                atPath: symlinkedConfigURL.path,
                withDestinationPath: targetConfigURL.path
            )

            let environment = ConfigSourceEnvironment(
                homeDirectoryURL: homeDirectory,
                currentBundleIdentifier: "coterm.com.emergent.app.debug.issue-3518"
            )
            try environment.writeCotermConfigContents("theme = light:Andromeda,dark:3024 Day\n")

            XCTAssertEqual(
                try String(contentsOf: targetConfigURL, encoding: .utf8),
                "theme = light:Andromeda,dark:3024 Day\n"
            )
            XCTAssertEqual(
                try symlinkedConfigURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink,
                true
            )
            XCTAssertEqual(environment.cotermConfigURL, symlinkedConfigURL)
        }
    }

    func testMaterializeWritesSelectedEditableConfigWhenLegacyConfigAppearsDuringCheck() throws {
        try withTemporaryHomeDirectory { homeDirectory in
            let fileManager = RaceCreatingFileManager()
            let appSupportDirectory = homeDirectory
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
            let bundleDirectory = appSupportDirectory
                .appendingPathComponent("coterm.com.emergent.app.debug.issue-3518", isDirectory: true)
            let configGhosttyURL = bundleDirectory.appendingPathComponent("config.ghostty", isDirectory: false)
            let legacyConfigURL = bundleDirectory.appendingPathComponent("config", isDirectory: false)

            fileManager.onFirstMissingPlainExistenceCheck = { path in
                guard path == configGhosttyURL.path else { return }
                try FileManager.default.createDirectory(at: bundleDirectory, withIntermediateDirectories: true)
                try "background = #000000\n".write(to: legacyConfigURL, atomically: true, encoding: .utf8)
            }

            let environment = ConfigSourceEnvironment(
                homeDirectoryURL: homeDirectory,
                currentBundleIdentifier: "coterm.com.emergent.app.debug.issue-3518",
                fileManager: fileManager
            )

            let materializedURL = try environment.materializeCotermConfigFileIfNeeded()

            XCTAssertEqual(materializedURL, configGhosttyURL)
            XCTAssertTrue(FileManager.default.fileExists(atPath: configGhosttyURL.path))
            XCTAssertEqual(try String(contentsOf: configGhosttyURL, encoding: .utf8), "")
            XCTAssertEqual(try String(contentsOf: legacyConfigURL, encoding: .utf8), "background = #000000\n")
            XCTAssertNil(fileManager.creationError)
        }
    }

    func testSyncedConfigPreviewIncludesSymlinkedStandaloneGhosttyConfig() throws {
        try withTemporaryHomeDirectory { homeDirectory in
            let fileManager = FileManager.default
            let ghosttyConfigDirectory = homeDirectory
                .appendingPathComponent(".config", isDirectory: true)
                .appendingPathComponent("ghostty", isDirectory: true)
            try fileManager.createDirectory(at: ghosttyConfigDirectory, withIntermediateDirectories: true)

            let dotfilesDirectory = homeDirectory
                .appendingPathComponent("dotfiles", isDirectory: true)
                .appendingPathComponent("ghostty", isDirectory: true)
            try fileManager.createDirectory(at: dotfilesDirectory, withIntermediateDirectories: true)
            let targetConfigURL = dotfilesDirectory.appendingPathComponent("config", isDirectory: false)
            try "font-size = 17\n".write(to: targetConfigURL, atomically: true, encoding: .utf8)

            let symlinkedConfigURL = ghosttyConfigDirectory.appendingPathComponent("config", isDirectory: false)
            try fileManager.createSymbolicLink(
                atPath: symlinkedConfigURL.path,
                withDestinationPath: targetConfigURL.path
            )

            let snapshot = ConfigSource.synced.snapshot(
                environment: ConfigSourceEnvironment(
                    homeDirectoryURL: homeDirectory,
                    currentBundleIdentifier: "coterm.com.emergent.app"
                )
            )

            XCTAssertTrue(snapshot.hasStandaloneGhosttyConfig)
            XCTAssertTrue(snapshot.contents.contains("font-size = 17"))
            XCTAssertEqual(snapshot.displayPaths, [
                homeDirectory
                    .appendingPathComponent("Library", isDirectory: true)
                    .appendingPathComponent("Application Support", isDirectory: true)
                    .appendingPathComponent("coterm.com.emergent.app", isDirectory: true)
                    .appendingPathComponent("config.synced-preview", isDirectory: false)
                    .path,
            ])
        }
    }

    func testCotermAppSupportConfigURLsUseNightlyConfigWhenPresent() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            _ = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "coterm.com.emergent.app",
                filename: "config.ghostty",
                contents: "font-size = 13\n"
            )
            let nightlyConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "coterm.com.emergent.app.nightly",
                filename: "config.ghostty",
                contents: "font-size = 15\n"
            )

            XCTAssertEqual(
                GhosttyApp.cotermAppSupportConfigURLs(
                    currentBundleIdentifier: "coterm.com.emergent.app.nightly",
                    appSupportDirectory: appSupportDirectory
                ),
                [nightlyConfigURL]
            )
        }
    }

    func testCotermAppSupportConfigURLsUseReleaseConfigForNightlyWithoutCurrentConfig() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            let releaseConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "coterm.com.emergent.app",
                filename: "config.ghostty",
                contents: "font-size = 13\n"
            )

            XCTAssertEqual(
                GhosttyApp.cotermAppSupportConfigURLs(
                    currentBundleIdentifier: "coterm.com.emergent.app.nightly",
                    appSupportDirectory: appSupportDirectory
                ),
                [releaseConfigURL]
            )
        }
    }

    func testCotermAppSupportConfigURLsUseStagingConfigWhenPresent() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            _ = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "coterm.com.emergent.app",
                filename: "config.ghostty",
                contents: "font-size = 13\n"
            )
            let stagingConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "coterm.com.emergent.app.staging",
                filename: "config.ghostty",
                contents: "font-size = 15\n"
            )

            XCTAssertEqual(
                GhosttyApp.cotermAppSupportConfigURLs(
                    currentBundleIdentifier: "coterm.com.emergent.app.staging",
                    appSupportDirectory: appSupportDirectory
                ),
                [stagingConfigURL]
            )
        }
    }

    func testCotermAppSupportConfigURLsUseReleaseConfigForStagingWithoutCurrentConfig() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            let releaseConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "coterm.com.emergent.app",
                filename: "config.ghostty",
                contents: "font-size = 13\n"
            )

            XCTAssertEqual(
                GhosttyApp.cotermAppSupportConfigURLs(
                    currentBundleIdentifier: "coterm.com.emergent.app.staging",
                    appSupportDirectory: appSupportDirectory
                ),
                [releaseConfigURL]
            )
        }
    }

    func testLoadedGhosttyConfigScanPathsOmitsReleaseLegacyConfigWhenPreferredConfigGhosttyExists() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            let legacyConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "coterm.com.emergent.app",
                filename: "config",
                contents: "background = #000000\n"
            )
            let preferredConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "coterm.com.emergent.app",
                filename: "config.ghostty",
                contents: "theme = light:3024 Day,dark:3024 Night\n"
            )

            let paths = GhosttyApp.loadedGhosttyConfigScanPaths(
                currentBundleIdentifier: "coterm.com.emergent.app.debug.issue-3478",
                appSupportDirectory: appSupportDirectory
            )

            XCTAssertTrue(paths.contains(preferredConfigURL.path))
            XCTAssertFalse(paths.contains(legacyConfigURL.path))
        }
    }

    func testCotermAppSupportConfigURLsSkipReleaseFallbackForNonDebugBundle() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            _ = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "coterm.com.emergent.app",
                filename: "config",
                contents: "font-size = 13\n"
            )

            XCTAssertTrue(
                GhosttyApp.cotermAppSupportConfigURLs(
                    currentBundleIdentifier: "com.example.other-app",
                    appSupportDirectory: appSupportDirectory
                ).isEmpty
            )
        }
    }

    func testCotermConfigPathResolverOpensLegacyConfigWhenConfigGhosttyIsEmpty() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            let legacyConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "coterm.com.emergent.app",
                filename: "config",
                contents: "background = #000000\n"
            )
            _ = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "coterm.com.emergent.app",
                filename: "config.ghostty",
                contents: ""
            )

            XCTAssertEqual(
                CotermGhosttyConfigPathResolver().activeOrEditableConfigURL(
                    currentBundleIdentifier: "coterm.com.emergent.app",
                    appSupportDirectory: appSupportDirectory
                ),
                legacyConfigURL
            )
        }
    }

    func testCotermConfigPathResolverTargetsCurrentConfigGhosttyWhenNoActiveConfigExists() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            let expectedURL = appSupportDirectory
                .appendingPathComponent("coterm.com.emergent.app.debug.issue-3518", isDirectory: true)
                .appendingPathComponent("config.ghostty", isDirectory: false)

            XCTAssertEqual(
                CotermGhosttyConfigPathResolver().activeOrEditableConfigURL(
                    currentBundleIdentifier: "coterm.com.emergent.app.debug.issue-3518",
                    appSupportDirectory: appSupportDirectory
                ),
                expectedURL
            )
        }
    }

    func testCotermAppSupportConfigURLsIgnoreMissingOrEmptyFiles() throws {
        try withTemporaryAppSupportDirectory { appSupportDirectory in
            _ = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: "coterm.com.emergent.app",
                filename: "config.ghostty",
                contents: ""
            )

            XCTAssertTrue(
                GhosttyApp.cotermAppSupportConfigURLs(
                    currentBundleIdentifier: "coterm.com.emergent.app.debug",
                    appSupportDirectory: appSupportDirectory
                ).isEmpty
            )
        }
    }

    func testGhosttySettingsEditorURLsMaterializeCotermConfigWhenNoConfigExists() throws {
        try withTemporaryHomeDirectory { homeDirectory in
            let environment = ConfigSourceEnvironment(
                homeDirectoryURL: homeDirectory,
                currentBundleIdentifier: "coterm.com.emergent.app.debug.empty"
            )

            let urls = try environment.materializedGhosttySettingsEditorURLs()
            let expectedConfigURL = homeDirectory
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
                .appendingPathComponent("coterm.com.emergent.app.debug.empty", isDirectory: true)
                .appendingPathComponent("config.ghostty", isDirectory: false)
            let expectedPreviewURL = expectedConfigURL
                .deletingLastPathComponent()
                .appendingPathComponent("config.synced-preview", isDirectory: false)

            XCTAssertEqual(urls.map(\.path), [expectedConfigURL.path])
            XCTAssertTrue(FileManager.default.fileExists(atPath: expectedConfigURL.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: expectedPreviewURL.path))
        }
    }

    func testGhosttySettingsEditorURLsIncludeStandaloneAppSupportAndRecursiveConfigFiles() throws {
        try withTemporaryHomeDirectory { homeDirectory in
            let fileManager = FileManager.default
            let appSupportDirectory = homeDirectory
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)

            let bundleIdentifier = "coterm.com.emergent.app.debug.includes"
            let cotermConfigURL = try writeAppSupportConfig(
                appSupportDirectory: appSupportDirectory,
                bundleIdentifier: bundleIdentifier,
                filename: "config.ghostty",
                contents: "theme = coterm\nconfig-file = coterm-include.conf\n"
            )
            let cotermIncludeURL = cotermConfigURL
                .deletingLastPathComponent()
                .appendingPathComponent("coterm-include.conf", isDirectory: false)
            try "font-size = 16\n".write(to: cotermIncludeURL, atomically: true, encoding: .utf8)

            let ghosttyDirectory = homeDirectory
                .appendingPathComponent(".config", isDirectory: true)
                .appendingPathComponent("ghostty", isDirectory: true)
            let ghosttyIncludeDirectory = ghosttyDirectory.appendingPathComponent("includes", isDirectory: true)
            try fileManager.createDirectory(at: ghosttyIncludeDirectory, withIntermediateDirectories: true)

            let standaloneConfigURL = ghosttyDirectory.appendingPathComponent("config", isDirectory: false)
            try """
            font-size = 14
            config-file = includes/font.conf # shared font config
            config-file = ?missing.conf
            """.write(to: standaloneConfigURL, atomically: true, encoding: .utf8)

            let standaloneIncludeURL = ghosttyIncludeDirectory.appendingPathComponent("font.conf", isDirectory: false)
            try "font-family = Test\n".write(to: standaloneIncludeURL, atomically: true, encoding: .utf8)

            let ghosttyAppSupportDirectory = appSupportDirectory
                .appendingPathComponent("com.mitchellh.ghostty", isDirectory: true)
            try fileManager.createDirectory(at: ghosttyAppSupportDirectory, withIntermediateDirectories: true)
            let ghosttyAppSupportConfigURL = ghosttyAppSupportDirectory
                .appendingPathComponent("config.ghostty", isDirectory: false)
            try "background = #101010\n".write(
                to: ghosttyAppSupportConfigURL,
                atomically: true,
                encoding: .utf8
            )

            let environment = ConfigSourceEnvironment(
                homeDirectoryURL: homeDirectory,
                currentBundleIdentifier: bundleIdentifier
            )

            let urls = try environment.materializedGhosttySettingsEditorURLs()
            XCTAssertEqual(
                urls.map(\.path),
                [
                    cotermConfigURL.path,
                    standaloneConfigURL.path,
                    ghosttyAppSupportConfigURL.path,
                    cotermIncludeURL.path,
                    standaloneIncludeURL.path,
                ]
            )
        }
    }

    private func withTemporaryAppSupportDirectory(
        _ body: (URL) throws -> Void
    ) throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("coterm-app-support-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }
        try body(directory)
    }

    private func withTemporaryHomeDirectory(
        _ body: (URL) throws -> Void
    ) throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("coterm-home-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }
        try body(directory)
    }

    private func writeAppSupportConfig(
        appSupportDirectory: URL,
        bundleIdentifier: String,
        filename: String,
        contents: String
    ) throws -> URL {
        let fileManager = FileManager.default
        let bundleDirectory = appSupportDirectory
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
        try fileManager.createDirectory(at: bundleDirectory, withIntermediateDirectories: true)

        let configURL = bundleDirectory.appendingPathComponent(filename, isDirectory: false)
        try contents.write(to: configURL, atomically: true, encoding: .utf8)
        return configURL
    }

    private final class RaceCreatingFileManager: FileManager {
        var onFirstMissingPlainExistenceCheck: ((String) throws -> Void)?
        var creationError: Error?
        private var hasRunPlainExistenceHook = false

        override func fileExists(atPath path: String) -> Bool {
            let exists = super.fileExists(atPath: path)
            guard !exists, !hasRunPlainExistenceHook else {
                return exists
            }
            hasRunPlainExistenceHook = true
            do {
                try onFirstMissingPlainExistenceCheck?(path)
            } catch {
                creationError = error
            }
            return exists
        }
    }
}
