import Foundation
import AppKit
import CotermSettings
import Testing

#if canImport(Coterm_DEV)
@testable import Coterm_DEV
#elseif canImport(Coterm)
@testable import Coterm
#endif

@Suite(.serialized)
struct WindowTitleTemplateTests {
    private let backupsDefaultsKey = "coterm.settingsFile.backups.v1"
    private let importedManagedDefaultsKey = "coterm.settingsFile.importedManagedDefaults.v1"

    @Test func resolvesWindowPlaceholdersAndPreservesUnknownPlaceholders() throws {
        let windowId = try #require(UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF"))
        let template = WindowTitleTemplate(
            rawValue: "[coterm:{windowToken}] {activeWorkspace} {activeDirectory} {windowId} {defaultTitle} {appName} {unknown}"
        )

        let resolved = template.resolved(context: WindowTitleTemplateContext(
            defaultTitle: "Fallback",
            activeWorkspace: "Build",
            activeDirectory: "/tmp/project",
            windowId: windowId,
            appName: "coterm"
        ))

        #expect(resolved == "[coterm:01234567] Build /tmp/project 01234567-89ab-cdef-0123-456789abcdef Fallback coterm {unknown}")
    }

    @Test func configuredTemplateTreatsBlankDefaultsValueAsDisabled() throws {
        let defaults = try isolatedDefaults()
        defaults.set("   \n", forKey: WindowTitleTemplate.userDefaultsKey)

        #expect(WindowTitleTemplate.configured(defaults: defaults) == nil)
    }

    @Test func resolverDoesNotExpandPlaceholdersInsideReplacementValues() throws {
        let windowId = try #require(UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF"))
        let template = WindowTitleTemplate(rawValue: "{activeWorkspace} {appName}")

        let resolved = template.resolved(context: WindowTitleTemplateContext(
            defaultTitle: "Fallback",
            activeWorkspace: "{windowId}",
            activeDirectory: "{windowToken}",
            windowId: windowId,
            appName: "coterm"
        ))

        #expect(resolved == "{windowId} coterm")
    }

    @Test func settingsFileStoreAppliesAppWindowTitleTemplate() throws {
        let defaults = UserDefaults.standard
        let keys = [
            WindowTitleTemplate.userDefaultsKey,
            backupsDefaultsKey,
            importedManagedDefaultsKey,
        ]
        let previousValues: [String: Any?] = Dictionary(
            uniqueKeysWithValues: keys.map { ($0, defaults.object(forKey: $0)) }
        )
        defer {
            restore(previousValues, defaults: defaults)
        }
        keys.forEach { defaults.removeObject(forKey: $0) }

        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("coterm-window-title-template-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let settingsFileURL = directoryURL.appendingPathComponent("coterm.json", isDirectory: false)
        try """
        {
          "app": {
            "windowTitleTemplate": "[coterm:{windowToken}] {activeWorkspace}"
          }
        }
        """.write(to: settingsFileURL, atomically: true, encoding: .utf8)

        _ = KeyboardShortcutSettingsFileStore(
            primaryPath: settingsFileURL.path,
            fallbackPath: nil,
            additionalFallbackPaths: [],
            startWatching: false
        )

        #expect(defaults.string(forKey: WindowTitleTemplate.userDefaultsKey) == "[coterm:{windowToken}] {activeWorkspace}")
    }

    @Test func settingsFileStoreAppliesWorkspaceAutoNamingAutomationSetting() throws {
        let defaults = UserDefaults.standard
        let workspaceAutoNamingKey = AutomationCatalogSection().workspaceAutoNaming.userDefaultsKey
        let keys = [
            workspaceAutoNamingKey,
            backupsDefaultsKey,
            importedManagedDefaultsKey,
        ]
        let previousValues: [String: Any?] = Dictionary(
            uniqueKeysWithValues: keys.map { ($0, defaults.object(forKey: $0)) }
        )
        defer {
            restore(previousValues, defaults: defaults)
        }
        keys.forEach { defaults.removeObject(forKey: $0) }

        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("coterm-workspace-auto-naming-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let settingsFileURL = directoryURL.appendingPathComponent("coterm.json", isDirectory: false)
        try """
        {
          "automation": {
            "workspaceAutoNaming": true
          }
        }
        """.write(to: settingsFileURL, atomically: true, encoding: .utf8)

        _ = KeyboardShortcutSettingsFileStore(
            primaryPath: settingsFileURL.path,
            fallbackPath: nil,
            additionalFallbackPaths: [],
            startWatching: false
        )

        #expect(defaults.bool(forKey: workspaceAutoNamingKey))
    }

    @Test func settingsFileStoreAppliesAutoNamingAgentAutomationSetting() throws {
        let defaults = UserDefaults.standard
        let autoNamingAgentKey = AutomationCatalogSection().autoNamingAgent.userDefaultsKey
        let keys = [
            autoNamingAgentKey,
            backupsDefaultsKey,
            importedManagedDefaultsKey,
        ]
        let previousValues: [String: Any?] = Dictionary(
            uniqueKeysWithValues: keys.map { ($0, defaults.object(forKey: $0)) }
        )
        defer {
            restore(previousValues, defaults: defaults)
        }
        keys.forEach { defaults.removeObject(forKey: $0) }

        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("coterm-auto-naming-agent-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let settingsFileURL = directoryURL.appendingPathComponent("coterm.json", isDirectory: false)
        try """
        {
          "automation": {
            "autoNamingAgent": "codex"
          }
        }
        """.write(to: settingsFileURL, atomically: true, encoding: .utf8)

        _ = KeyboardShortcutSettingsFileStore(
            primaryPath: settingsFileURL.path,
            fallbackPath: nil,
            additionalFallbackPaths: [],
            startWatching: false
        )

        #expect(defaults.string(forKey: autoNamingAgentKey) == "codex")
    }

    @MainActor
    @Test func selectedWorkspaceDirectoryChangeRefreshesActiveDirectoryTitle() throws {
        let defaults = UserDefaults.standard
        let previousValues: [String: Any?] = [
            WindowTitleTemplate.userDefaultsKey: defaults.object(forKey: WindowTitleTemplate.userDefaultsKey),
        ]
        defer {
            restore(previousValues, defaults: defaults)
        }
        defaults.set("[coterm:{windowToken}] {activeDirectory}", forKey: WindowTitleTemplate.userDefaultsKey)

        let windowId = try #require(UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF"))
        let manager = TabManager(
            initialWorkspaceTitle: "Build",
            initialWorkingDirectory: "/tmp/old",
            autoWelcomeIfNeeded: false
        )
        manager.windowId = windowId

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        manager.window = window
        defer {
            manager.window = nil
            window.close()
        }

        manager.refreshWindowTitle()
        #expect(window.title == "[coterm:01234567] /tmp/old")

        let workspace = try #require(manager.tabs.first)
        let panelId = try #require(workspace.focusedPanelId)
        #expect(workspace.updatePanelDirectory(panelId: panelId, directory: "/tmp/new"))
        manager.workspaceCurrentDirectoryDidChange(workspaceId: workspace.id)
        #expect(window.title == "[coterm:01234567] /tmp/new")
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let suiteName = "coterm.WindowTitleTemplateTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func restore(_ values: [String: Any?], defaults: UserDefaults) {
        for (key, value) in values {
            if let value {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
