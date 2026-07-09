import AppKit
import CotermFoundation
import CotermSettings
import Bonsplit
import Foundation
import UniformTypeIdentifiers

extension Notification.Name {
    static let defaultTerminalRegistrationDidChange = Notification.Name("DefaultTerminalRegistration.didChange")
}

struct DefaultTerminalRegistrationStatus: Equatable {
    let matchedTargetCount: Int
    let targetCount: Int

    var isDefault: Bool {
        matchedTargetCount == targetCount
    }
}

enum DefaultTerminalRegistrationError: Error, LocalizedError {
    case launchServicesRegistrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .launchServicesRegistrationFailed:
            return String(
                localized: "error.defaultTerminal.registrationFailed",
                defaultValue: "coterm could not register as the default terminal app."
            )
        }
    }
}

enum DefaultTerminalRegistration {
    static let urlSchemes = ["ssh"]
    static let contentTypeIdentifiers = [
        "com.apple.terminal.shell-script",
        "public.unix-executable"
    ]

    static func contentType(forIdentifier identifier: String) -> UTType {
        UTType(identifier) ?? UTType(importedAs: identifier)
    }

    static var targetCount: Int {
        urlSchemes.count + contentTypeIdentifiers.count
    }

    static func currentStatus(
        bundleURL: URL = Bundle.main.bundleURL,
        workspace: NSWorkspace = .shared
    ) -> DefaultTerminalRegistrationStatus {
        let normalizedBundleURL = normalizedApplicationURL(bundleURL)
        let matchedURLSchemes = urlSchemes.filter { scheme in
            guard let url = URL(string: "\(scheme)://coterm-default-terminal-check") else {
                return false
            }
            return normalizedApplicationURL(workspace.urlForApplication(toOpen: url)) == normalizedBundleURL
        }.count

        let matchedContentTypes = contentTypeIdentifiers.filter { identifier in
            let contentType = contentType(forIdentifier: identifier)
            return normalizedApplicationURL(workspace.urlForApplication(toOpen: contentType)) == normalizedBundleURL
        }.count

        return DefaultTerminalRegistrationStatus(
            matchedTargetCount: matchedURLSchemes + matchedContentTypes,
            targetCount: targetCount
        )
    }

    static func setAsDefault(bundleURL: URL = Bundle.main.bundleURL) async throws {
        let normalizedBundleURL = normalizedApplicationURL(bundleURL) ?? bundleURL.standardizedFileURL.resolvingSymlinksInPath()
        var didAttemptHandlerUpdate = false
        defer {
            if didAttemptHandlerUpdate {
                Task { @MainActor in
                    NotificationCenter.default.post(name: .defaultTerminalRegistrationDidChange, object: nil)
                }
            }
        }

        let registerStatus = LSRegisterURL(normalizedBundleURL as CFURL, true)
        guard registerStatus == noErr else {
            throw DefaultTerminalRegistrationError.launchServicesRegistrationFailed(registerStatus)
        }
        didAttemptHandlerUpdate = true

        for scheme in urlSchemes {
            try await NSWorkspace.shared.setDefaultApplication(
                at: normalizedBundleURL,
                toOpenURLsWithScheme: scheme
            )
        }

        for identifier in contentTypeIdentifiers {
            let contentType = contentType(forIdentifier: identifier)
            try await NSWorkspace.shared.setDefaultApplication(
                at: normalizedBundleURL,
                toOpen: contentType
            )
        }
    }

    private static func normalizedApplicationURL(_ url: URL?) -> URL? {
        url?.standardizedFileURL.resolvingSymlinksInPath()
    }
}

@MainActor
enum DefaultTerminalUserAction {
    private struct RegistrationOperation {
        let id: UUID
        let task: Task<Void, Error>
    }

    private static var inFlightRegistration: RegistrationOperation?

    @discardableResult
    static func registerAsDefault() async throws -> Bool {
        if let operation = inFlightRegistration {
            do {
                try await operation.task.value
            } catch {
                return false
            }
            return false
        }

        let operation = RegistrationOperation(
            id: UUID(),
            task: Task {
                try await DefaultTerminalRegistration.setAsDefault()
            }
        )
        inFlightRegistration = operation

        do {
            try await operation.task.value
            if inFlightRegistration?.id == operation.id {
                inFlightRegistration = nil
            }
            return true
        } catch {
            if inFlightRegistration?.id == operation.id {
                inFlightRegistration = nil
            }
            throw error
        }
    }

    static func setAsDefault(debugSource: String) {
#if DEBUG
        cotermDebugLog("defaultTerminal.setAsDefault source=\(debugSource)")
#endif
        Task {
            do {
                try await registerAsDefault()
            } catch {
#if DEBUG
                cotermDebugLog("defaultTerminal.setAsDefault.failed source=\(debugSource) error=\(error)")
#endif
                presentSetAsDefaultError(error)
            }
        }
    }

    private static func presentSetAsDefaultError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(
            localized: "dialog.defaultTerminal.setFailed.title",
            defaultValue: "Could Not Set Default Terminal"
        )
        alert.informativeText = (error as? DefaultTerminalRegistrationError)?.errorDescription ?? String(
            localized: "defaultTerminal.updateFailed.message",
            defaultValue: "macOS could not update every default terminal handler."
        )
        alert.addButton(withTitle: String(localized: "common.ok", defaultValue: "OK"))
        alert.window.identifier = NSUserInterfaceItemIdentifier("coterm.defaultTerminalRegistrationError")
        alert.runModal()
    }
}

struct TerminalDefaultFileOpenRequest: Equatable {
    let fileURL: URL
    let workingDirectory: String
    let initialInput: String

    init?(fileURL: URL, contentType: UTType? = nil, isExecutable: Bool? = nil) {
        guard fileURL.isFileURL else { return nil }
        let standardizedURL = fileURL.standardizedFileURL
        let directoryCheckURL = standardizedURL.resolvingSymlinksInPath()
        guard !SessionPersistencePolicy.isCotermCrashStorageURL(standardizedURL) else { return nil }
        guard !SessionPersistencePolicy.isCotermCrashStorageURL(directoryCheckURL) else { return nil }
        let resourceValues = try? directoryCheckURL.resourceValues(forKeys: [.isDirectoryKey])
        guard resourceValues?.isDirectory != true else { return nil }
        let resolvedContentType = contentType ?? Self.contentType(for: standardizedURL)
        let resolvedIsExecutable = isExecutable ?? Self.isExecutableFile(directoryCheckURL)
        guard Self.shouldRunInTerminal(
            fileURL: standardizedURL,
            contentType: resolvedContentType,
            isExecutable: resolvedIsExecutable
        ) else {
            return nil
        }

        self.fileURL = standardizedURL
        self.workingDirectory = standardizedURL.deletingLastPathComponent().path(percentEncoded: false)
        self.initialInput = "\(Self.shellSingleQuoted(standardizedURL.path(percentEncoded: false)))\n"
    }

    static func requests(from urls: [URL]) -> [TerminalDefaultFileOpenRequest] {
        var seen: Set<String> = []
        var requests: [TerminalDefaultFileOpenRequest] = []
        for url in urls {
            guard let request = TerminalDefaultFileOpenRequest(fileURL: url) else { continue }
            let path = request.fileURL.path(percentEncoded: false)
            guard seen.insert(path).inserted else { continue }
            requests.append(request)
        }
        return requests
    }

    private static func contentType(for fileURL: URL) -> UTType? {
        try? fileURL.resourceValues(forKeys: [.contentTypeKey]).contentType
    }

    private static func isExecutableFile(_ fileURL: URL) -> Bool {
        if (try? fileURL.resourceValues(forKeys: [.isExecutableKey]).isExecutable) == true {
            return true
        }
        return FileManager.default.isExecutableFile(atPath: fileURL.path(percentEncoded: false))
    }

    private static func shouldRunInTerminal(fileURL: URL, contentType: UTType?, isExecutable: Bool) -> Bool {
        if isTerminalShellScript(fileURL: fileURL, contentType: contentType) {
            return true
        }
        return contentType?.conforms(to: .unixExecutable) == true || isExecutable
    }

    private static func isTerminalShellScript(fileURL: URL, contentType: UTType?) -> Bool {
        if contentType?.identifier == "com.apple.terminal.shell-script" {
            return true
        }
        switch fileURL.pathExtension.lowercased() {
        case "command", "tool":
            return true
        default:
            return false
        }
    }

    private static func shellSingleQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

@MainActor
final class CotermSSHURLProcessLauncher {
    static let shared = CotermSSHURLProcessLauncher()

    private var processes: [Int32: Process] = [:]
    private var isShuttingDown = false

    private init() {}

    func terminateAll() {
        isShuttingDown = true
        for process in processes.values where process.isRunning {
            process.terminate()
        }
        processes.removeAll()
    }

    @discardableResult
    func start(request: CotermSSHURLRequest, preferredWindow: NSWindow?) -> Bool {
        let cliURL = Bundle.main.resourceURL?.appendingPathComponent("bin/coterm")
        guard let cliURL,
              FileManager.default.isExecutableFile(atPath: cliURL.path) else {
            presentLaunchFailure(
                summary: String(
                    localized: "dialog.sshURL.launchFailed.missingCLI",
                    defaultValue: "The bundled CLI is missing from this coterm build."
                ),
                output: "",
                preferredWindow: preferredWindow
            )
            return false
        }

        let socketPath = resolvedSocketPath()
        let process = Process()
        process.executableURL = cliURL
        process.arguments = ["--socket", socketPath] + request.cliArguments
        var environment = ProcessInfo.processInfo.environment
        environment["COTERM_SOCKET_PATH"] = socketPath
        environment["COTERM_BUNDLED_CLI_PATH"] = cliURL.path
        environment.removeValue(forKey: "COTERM_SOCKET")
        process.environment = environment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        let outputCollector = ProcessOutputCollector(stdout: outputPipe, stderr: errorPipe)
        outputCollector.start()
        process.terminationHandler = { [weak preferredWindow] terminatedProcess in
            let output = outputCollector.finish()
            let processIdentifier = terminatedProcess.processIdentifier
            let terminationStatus = terminatedProcess.terminationStatus
            Task { @MainActor in
                Self.shared.processes.removeValue(forKey: processIdentifier)
                guard terminationStatus != 0, !Self.shared.isShuttingDown else { return }
                let format = String(
                    localized: "dialog.sshURL.launchFailed.exit",
                    defaultValue: "`coterm ssh` exited with status %d."
                )
                Self.shared.presentLaunchFailure(
                    summary: String(format: format, Int(terminationStatus)),
                    output: output,
                    preferredWindow: preferredWindow
                )
            }
        }

        do {
            try process.run()
            processes[process.processIdentifier] = process
#if DEBUG
            cotermDebugLog("sshURL.launchCLI pid=\(process.processIdentifier) socket=\(socketPath) targetLength=\(request.destination.count)")
#endif
            return true
        } catch {
            outputCollector.cancel()
            presentLaunchFailure(
                summary: String(
                    localized: "dialog.sshURL.launchFailed.launch",
                    defaultValue: "`coterm ssh` could not be launched."
                ),
                output: error.localizedDescription,
                preferredWindow: preferredWindow
            )
            return false
        }
    }

    func resolvedSocketPath() -> String {
        TerminalController.shared.activeSocketPath(
            preferredPath: SocketControlSettings.socketPath()
        )
    }

    private func presentLaunchFailure(summary: String, output: String, preferredWindow: NSWindow?) {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let limitedOutput = String(trimmedOutput.prefix(2000))
        let informativeText = limitedOutput.isEmpty
            ? summary
            : "\(summary)\n\n\(limitedOutput)"

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(
            localized: "dialog.sshURL.launchFailed.title",
            defaultValue: "Couldn't Open SSH Link"
        )
        alert.informativeText = informativeText
        alert.addButton(withTitle: String(localized: "common.ok", defaultValue: "OK"))
        if let preferredWindow {
            alert.beginSheetModal(for: preferredWindow, completionHandler: nil)
        } else if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }
}

@MainActor
private final class CotermSSHURLConfirmationGate: NSObject {
    weak var connectButton: NSButton?

    @objc func checkboxChanged(_ sender: NSButton) {
        connectButton?.isEnabled = sender.state == .on
    }
}

extension AppDelegate {
    func deferInitialMainWindowBootstrapForExternalConfirmation() {
        guard !didAttemptStartupSessionRestore, !didHandleExplicitOpenIntentAtStartup else { return }
        shouldDeferInitialMainWindowBootstrapForExternalConfirmation = true
    }

    func resumeInitialMainWindowBootstrapAfterExternalConfirmation(debugSource: String) {
        guard shouldDeferInitialMainWindowBootstrapForExternalConfirmation else { return }
        shouldDeferInitialMainWindowBootstrapForExternalConfirmation = false
        scheduleInitialMainWindowBootstrap(debugSource: debugSource)
    }

    func bootstrapInitialMainWindowAfterAcceptedExternalOpen(
        debugSource: String,
        shouldActivate: Bool = true,
        suppressWelcome: Bool = false
    ) {
        shouldDeferInitialMainWindowBootstrapForExternalConfirmation = false
        _ = bootstrapInitialMainWindowIfNeeded(
            debugSource: debugSource,
            shouldActivate: shouldActivate,
            suppressWelcome: suppressWelcome
        )
    }

    func claimAuthCallbackURLSchemes() {
        // Pin the current build's callback scheme so auth, SSH, and navigation deeplinks
        // route back to this app instead of an unrelated LaunchServices entry.
        let bundleURL = Bundle.main.bundleURL
        NSWorkspace.shared.setDefaultApplication(
            at: bundleURL,
            toOpenURLsWithScheme: AuthEnvironment.callbackScheme
        ) { _ in }
    }

    @discardableResult
    func handleCotermExternalURLs(from urls: [URL]) -> Bool {
        let intentCounts = cotermExternalURLIntentCounts(in: urls)
        guard intentCounts.total > 0 else { return false }
        guard intentCounts.total == 1 else {
            if intentCounts.ssh > 1 && intentCounts.navigation == 0 && intentCounts.text == 0 {
                showCotermSSHURLParseError(.multipleLinks)
            } else {
                showCotermTextURLParseError(.multipleLinks)
            }
            return true
        }

        if handleCotermSSHURLs(from: urls) {
            return true
        }
        if handleCotermNavigationURLs(from: urls) {
            return true
        }
        if handleCotermTextURLs(from: urls) {
            return true
        }
        return false
    }

    private struct CotermExternalURLIntentCounts {
        var ssh = 0
        var navigation = 0
        var text = 0

        var total: Int {
            ssh + navigation + text
        }
    }

    private func cotermExternalURLIntentCounts(in urls: [URL]) -> CotermExternalURLIntentCounts {
        urls.reduce(CotermExternalURLIntentCounts()) { counts, url in
            var nextCounts = counts
            switch CotermSSHURLRequest.parse(url) {
            case .success(.some), .failure:
                nextCounts.ssh += 1
            case .success(nil):
                break
            }
            switch CotermNavigationURLRequest.parse(url) {
            case .success(.some), .failure:
                nextCounts.navigation += 1
            case .success(nil):
                break
            }
            switch CotermTextURLRequest.parse(url) {
            case .success(.some), .failure:
                nextCounts.text += 1
            case .success(nil):
                break
            }
            return nextCounts
        }
    }

    @discardableResult
    func handleCotermNavigationURLs(from urls: [URL]) -> Bool {
        var navigationRequests: [CotermNavigationURLRequest] = []
        var parseErrors: [(url: URL, error: CotermNavigationURLParseError)] = []

        for url in urls {
            switch CotermNavigationURLRequest.parse(url) {
            case .success(.some(let request)):
                navigationRequests.append(request)
            case .success(nil):
                break
            case .failure(let error):
                parseErrors.append((url, error))
            }
        }

        let navigationIntentCount = navigationRequests.count + parseErrors.count
        guard navigationIntentCount > 0 else { return false }

        guard navigationIntentCount == 1 else {
#if DEBUG
            cotermDebugLog("navigationURL.ignored reason=multipleLinks count=\(urls.count) intents=\(navigationIntentCount)")
#endif
            return true
        }

        if let parseError = parseErrors.first {
#if DEBUG
            cotermDebugLog("navigationURL.blocked reason=\(parseError.error) url=\(parseError.url.absoluteString.prefix(160))")
#endif
            return true
        }

        if let request = navigationRequests.first {
            let deeplinkType = Self.deeplinkType(forNavigationTarget: request.target)
            trackDeeplinkReceived(type: deeplinkType)
            if handleCotermNavigationURLRequest(request) {
                trackDeeplinkConfirmed(type: deeplinkType)
            } else {
                trackDeeplinkRejected(type: deeplinkType, reason: "target_not_found")
            }
        }
        return true
    }

    @discardableResult
    private func handleCotermNavigationURLRequest(_ request: CotermNavigationURLRequest) -> Bool {
        let workspaceId: UUID
        switch request.target {
        case .workspace(let id), .pane(let id, _), .surface(let id, _):
            workspaceId = id
        }

        guard let context = mainWindowContexts.values.first(where: { context in
            context.tabManager.tabs.contains(where: { $0.id == workspaceId })
        }),
              let workspace = context.tabManager.tabs.first(where: { $0.id == workspaceId }),
              let window = context.window ?? windowForMainWindowId(context.windowId) else {
#if DEBUG
            cotermDebugLog("navigationURL.notFound workspace=\(workspaceId.uuidString.prefix(8))")
#endif
            return false
        }

        let targetPanelId: UUID?
        switch request.target {
        case .workspace:
            targetPanelId = nil
        case .pane(_, let paneId):
            guard let pane = workspace.bonsplitController.allPaneIds.first(where: { $0.id == paneId }) else {
#if DEBUG
                cotermDebugLog(
                    "navigationURL.notFound workspace=\(workspaceId.uuidString.prefix(8)) " +
                    "pane=\(paneId.uuidString.prefix(8))"
                )
#endif
                return false
            }
            let selectedTab = workspace.bonsplitController.selectedTab(inPane: pane)
                ?? workspace.bonsplitController.tabs(inPane: pane).first
            targetPanelId = selectedTab.flatMap { workspace.panelIdFromSurfaceId($0.id) }
            if targetPanelId == nil {
                workspace.bonsplitController.focusPane(pane)
            }
        case .surface(_, let surfaceId):
            guard workspace.panels[surfaceId] != nil,
                  workspace.surfaceIdFromPanelId(surfaceId) != nil else {
#if DEBUG
                cotermDebugLog(
                    "navigationURL.notFound workspace=\(workspaceId.uuidString.prefix(8)) " +
                    "surface=\(surfaceId.uuidString.prefix(8))"
                )
#endif
                return false
            }
            targetPanelId = surfaceId
        }

        prepareForExplicitOpenIntentAtStartup()
        setActiveMainWindow(window)
        _ = focusMainWindow(windowId: context.windowId)
        context.tabManager.focusTab(
            workspaceId,
            surfaceId: targetPanelId,
            suppressFlash: true
        )

#if DEBUG
        let surface = targetPanelId.map { String($0.uuidString.prefix(8)) } ?? "nil"
        cotermDebugLog(
            "navigationURL.focus workspace=\(workspaceId.uuidString.prefix(8)) " +
            "surface=\(surface) window=\(context.windowId.uuidString.prefix(8))"
        )
#endif
        return true
    }

    @discardableResult
    func handleCotermSSHURLs(from urls: [URL]) -> Bool {
        var sshURLRequests: [CotermSSHURLRequest] = []
        var sshURLParseErrors: [CotermSSHURLParseError] = []
        for url in urls {
            switch CotermSSHURLRequest.parse(url) {
            case .success(.some(let request)):
                sshURLRequests.append(request)
            case .success(nil):
                break
            case .failure(let error):
                sshURLParseErrors.append(error)
            }
        }
        let sshURLIntentCount = sshURLRequests.count + sshURLParseErrors.count
        guard sshURLIntentCount > 0 else { return false }
        ProductAnalytics.shared.trackLinking(
            .started,
            linkKind: .ssh,
            entrypoint: .externalURL,
            result: .started,
            properties: [
                "request_count": sshURLRequests.count,
                "parse_error_count": sshURLParseErrors.count,
            ]
        )

        if sshURLIntentCount > 1 {
            trackDeeplinkRejected(type: "ssh", reason: "multiple_links")
            trackLinkingFailed(linkKind: .ssh, errorKind: "multiple_links")
            showCotermSSHURLParseError(.multipleLinks)
        } else {
            for error in sshURLParseErrors {
                let reason = Self.analyticsErrorKind(for: error)
                trackDeeplinkRejected(type: "ssh", reason: reason)
                trackLinkingFailed(linkKind: .ssh, errorKind: reason)
                showCotermSSHURLParseError(error)
            }
            if let request = sshURLRequests.first {
                handleCotermSSHURLRequest(request)
            }
        }
        return true
    }

    @discardableResult
    func handleCotermTextURLs(from urls: [URL]) -> Bool {
        var textURLRequests: [CotermTextURLRequest] = []
        var textURLParseErrors: [(deeplinkType: String, error: CotermTextURLParseError)] = []
        for url in urls {
            switch CotermTextURLRequest.parse(url) {
            case .success(.some(let request)):
                textURLRequests.append(request)
            case .success(nil):
                break
            case .failure(let error):
                textURLParseErrors.append((Self.deeplinkType(forTextURL: url), error))
            }
        }
        let textURLIntentCount = textURLRequests.count + textURLParseErrors.count
        guard textURLIntentCount > 0 else { return false }
        let linkKind = textURLRequests.first.map { Self.analyticsLinkKind(for: $0) }
            ?? textURLParseErrors.first.map { Self.analyticsLinkKind(forDeeplinkType: $0.deeplinkType) }
            ?? .prompt
        ProductAnalytics.shared.trackLinking(
            .started,
            linkKind: linkKind,
            entrypoint: .externalURL,
            result: .started,
            properties: [
                "request_count": textURLRequests.count,
                "parse_error_count": textURLParseErrors.count,
            ]
        )

        if textURLIntentCount > 1 {
            trackDeeplinkRejected(type: linkKind.rawValue, reason: "multiple_links")
            trackLinkingFailed(linkKind: linkKind, errorKind: "multiple_links")
            showCotermTextURLParseError(.multipleLinks)
        } else {
            for parseError in textURLParseErrors {
                let reason = Self.analyticsErrorKind(for: parseError.error)
                trackDeeplinkRejected(type: parseError.deeplinkType, reason: reason)
                trackLinkingFailed(linkKind: Self.analyticsLinkKind(forDeeplinkType: parseError.deeplinkType), errorKind: reason)
                showCotermTextURLParseError(parseError.error)
            }
            if let request = textURLRequests.first {
                handleCotermTextURLRequest(request)
            }
        }
        return true
    }

    private func handleCotermSSHURLRequest(_ request: CotermSSHURLRequest) {
#if DEBUG
        let target = request.originalURL.host ?? request.originalURL.path
        cotermDebugLog("sshURL.prompt target=\(target) destinationLength=\(request.destination.count) hasPort=\(request.port != nil)")
#endif

        trackDeeplinkReceived(type: "ssh")
        deferInitialMainWindowBootstrapForExternalConfirmation()
        guard confirmCotermSSHURLRequest(request) else {
            resumeInitialMainWindowBootstrapAfterExternalConfirmation(debugSource: "sshURL.cancelled")
            ProductAnalytics.shared.trackLinking(
                .failed,
                linkKind: .ssh,
                entrypoint: .externalURL,
                result: .cancelled,
                properties: ["error_kind": "user_cancelled"]
            )
#if DEBUG
            cotermDebugLog("sshURL.cancelled")
#endif
            return
        }

        prepareForExplicitOpenIntentAtStartup()
        trackDeeplinkConfirmed(type: "ssh")
        bootstrapInitialMainWindowAfterAcceptedExternalOpen(debugSource: "sshURL.confirmed")
        NSApp.activate(ignoringOtherApps: true)
        let didStart = CotermSSHURLProcessLauncher.shared.start(
            request: request,
            preferredWindow: NSApp.keyWindow ?? NSApp.mainWindow
        )
        var analyticsProperties: [String: Any] = [
            "has_port": request.port != nil,
            "has_title": request.title != nil,
            "no_focus": request.noFocus,
        ]
        if !didStart {
            analyticsProperties["error_kind"] = "launcher_failed"
        }
        ProductAnalytics.shared.trackLinking(
            didStart ? .completed : .failed,
            linkKind: .ssh,
            entrypoint: .externalURL,
            result: didStart ? .completed : .failed,
            properties: analyticsProperties,
            flush: didStart
        )
    }

    private func handleCotermTextURLRequest(_ request: CotermTextURLRequest) {
#if DEBUG
        let target = request.originalURL.host ?? request.originalURL.path
        cotermDebugLog("textURL.prompt target=\(target) kind=\(request.kind.rawValue) textLength=\(request.text.count)")
#endif

        let deeplinkType = Self.deeplinkType(for: request)
        trackDeeplinkReceived(type: deeplinkType)
        deferInitialMainWindowBootstrapForExternalConfirmation()
        guard confirmCotermTextURLRequest(request) else {
            resumeInitialMainWindowBootstrapAfterExternalConfirmation(debugSource: "textURL.cancelled")
            ProductAnalytics.shared.trackLinking(
                .failed,
                linkKind: Self.analyticsLinkKind(for: request),
                entrypoint: .externalURL,
                result: .cancelled,
                properties: ["error_kind": "user_cancelled"]
            )
#if DEBUG
            cotermDebugLog("textURL.cancelled")
#endif
            return
        }

        prepareForExplicitOpenIntentAtStartup()
        trackDeeplinkConfirmed(type: deeplinkType)
        bootstrapInitialMainWindowAfterAcceptedExternalOpen(
            debugSource: "textURL.confirmed",
            shouldActivate: !request.noFocus,
            suppressWelcome: true
        )
        if !request.noFocus {
            NSApp.activate(ignoringOtherApps: true)
        }
        let didPaste = pasteTextInPreferredMainWindowFromExternalLink(
            request.pasteText,
            preferredWindow: NSApp.keyWindow ?? NSApp.mainWindow,
            shouldBringToFront: !request.noFocus,
            debugSource: "textURL.\(request.kind.rawValue)",
            onSendFailure: { [weak self] in
                self?.showCotermTextURLPasteFailure(request)
            }
        )
        if !didPaste {
            showCotermTextURLPasteFailure(request)
        }
        var analyticsProperties: [String: Any] = [
            "no_focus": request.noFocus,
        ]
        if !didPaste {
            analyticsProperties["error_kind"] = "paste_failed"
        }
        ProductAnalytics.shared.trackLinking(
            didPaste ? .completed : .failed,
            linkKind: Self.analyticsLinkKind(for: request),
            entrypoint: .externalURL,
            result: didPaste ? .completed : .failed,
            properties: analyticsProperties,
            flush: didPaste
        )
    }

    private func trackLinkingFailed(linkKind: LinkingAnalyticsKind, errorKind: String) {
        ProductAnalytics.shared.trackLinking(
            .failed,
            linkKind: linkKind,
            entrypoint: .externalURL,
            result: .failed,
            properties: ["error_kind": errorKind]
        )
    }

    private func trackDeeplinkReceived(type: String) {
#if DEBUG
        print("[PostHog] firing: deeplink_received")
#endif
        PostHogAnalytics.shared.capture("deeplink_received", properties: [
            "deeplink_type": type,
        ])
    }

    private func trackDeeplinkConfirmed(type: String) {
#if DEBUG
        print("[PostHog] firing: deeplink_confirmed")
#endif
        PostHogAnalytics.shared.capture("deeplink_confirmed", properties: [
            "deeplink_type": type,
        ])
    }

    private func trackDeeplinkRejected(type: String, reason: String) {
#if DEBUG
        print("[PostHog] firing: deeplink_rejected")
#endif
        PostHogAnalytics.shared.capture("deeplink_rejected", properties: [
            "deeplink_type": type,
            "reason": reason,
        ])
    }

    private static func deeplinkType(forNavigationTarget target: CotermNavigationURLRequest.Target) -> String {
        switch target {
        case .workspace:
            return "workspace"
        case .pane:
            return "pane"
        case .surface:
            return "surface"
        }
    }

    private static func analyticsLinkKind(for request: CotermTextURLRequest) -> LinkingAnalyticsKind {
        switch request.kind {
        case .prompt:
            return .prompt
        case .rules:
            return .rules
        }
    }

    private static func analyticsLinkKind(for _: CotermTextURLParseError) -> LinkingAnalyticsKind {
        .prompt
    }

    private static func analyticsLinkKind(forDeeplinkType deeplinkType: String) -> LinkingAnalyticsKind {
        deeplinkType == "rules" ? .rules : .prompt
    }

    private static func deeplinkType(for request: CotermTextURLRequest) -> String {
        switch request.kind {
        case .prompt:
            return "prompt"
        case .rules:
            return "rules"
        }
    }

    private static func deeplinkType(forTextURL url: URL) -> String {
        if let host = url.host?.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased(),
           host == "rule" || host == "rules" {
            return "rules"
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return "prompt"
        }
        let route = components.path
            .split(separator: "/")
            .map { String($0).lowercased() }
        if route.contains("rules") {
            return "rules"
        }
        return "prompt"
    }

    private static func analyticsErrorKind(for error: CotermSSHURLParseError) -> String {
        String(describing: error)
    }

    private static func analyticsErrorKind(for error: CotermTextURLParseError) -> String {
        String(describing: error)
    }

    private func confirmCotermSSHURLRequest(_ request: CotermSSHURLRequest) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(
            localized: "dialog.sshURL.title",
            defaultValue: "Open SSH Workspace in Coterm?"
        )
        alert.informativeText = String(
            format: String(
                localized: "dialog.sshURL.message",
                defaultValue: "An external link wants to open \"%@\" in coterm. Do you want to open this SSH workspace?\n\nIf you did not initiate this request, it may represent an attempted attack on your system. Only continue if you explicitly started this action."
            ),
            request.displayTarget
        )

        let cancelTitle = String(localized: "dialog.sshURL.cancel", defaultValue: "No")
        let runTitle = String(localized: "dialog.sshURL.run", defaultValue: "Open")
        alert.addButton(withTitle: cancelTitle)
        alert.addButton(withTitle: runTitle)

        let cancelButton = alert.buttons[0]
        cancelButton.keyEquivalent = "\r"
        if alert.buttons.count > 1 {
            let connectButton = alert.buttons[1]
            connectButton.keyEquivalent = ""
            connectButton.isEnabled = false
        }

        let gate = CotermSSHURLConfirmationGate()
        if alert.buttons.count > 1 {
            gate.connectButton = alert.buttons[1]
        }
        alert.accessoryView = cotermSSHURLAccessoryView(request: request, gate: gate)
        let response: NSApplication.ModalResponse = withExtendedLifetime(gate) {
            alert.runModal()
        }
        return response == .alertSecondButtonReturn
    }

    private func confirmCotermTextURLRequest(_ request: CotermTextURLRequest) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = request.kind == .prompt
            ? String(localized: "dialog.textURL.prompt.title", defaultValue: "Paste a Prompt From an External Link?")
            : String(localized: "dialog.textURL.rules.title", defaultValue: "Paste Rules From an External Link?")

        let scheme = request.originalURL.scheme ?? AuthEnvironment.callbackScheme
        let messageFormat = request.kind == .prompt
            ? String(
                localized: "dialog.textURL.prompt.message",
                defaultValue: "A %@:// link is asking coterm to paste a prompt into the current workspace. coterm cannot verify which website or app opened this link.\n\ncoterm will paste the text into the terminal and will not press Return. Only continue if you trust this prompt."
            )
            : String(
                localized: "dialog.textURL.rules.message",
                defaultValue: "A %@:// link is asking coterm to paste rules into the current workspace. coterm cannot verify which website or app opened this link.\n\ncoterm will paste the rules into the terminal and will not write files or press Return. Only continue if you trust these rules."
            )
        alert.informativeText = String(
            format: messageFormat,
            scheme
        )

        alert.addButton(withTitle: String(localized: "dialog.textURL.cancel", defaultValue: "Cancel"))
        alert.addButton(withTitle: String(localized: "dialog.textURL.paste", defaultValue: "Paste"))

        let cancelButton = alert.buttons[0]
        cancelButton.keyEquivalent = "\r"
        if alert.buttons.count > 1 {
            alert.buttons[1].keyEquivalent = ""
        }

        alert.accessoryView = cotermTextURLAccessoryView(request: request)
        return alert.runModal() == .alertSecondButtonReturn
    }

    private func cotermSSHURLAccessoryView(
        request: CotermSSHURLRequest,
        gate: CotermSSHURLConfirmationGate
    ) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let targetLabel = NSTextField(labelWithString: String(
            format: String(localized: "dialog.sshURL.targetLabel", defaultValue: "SSH target: %@"),
            request.displayTarget
        ))
        targetLabel.lineBreakMode = .byTruncatingMiddle
        targetLabel.maximumNumberOfLines = 1

        let commandLabel = NSTextField(labelWithString: String(
            localized: "dialog.sshURL.commandLabel",
            defaultValue: "Command preview:"
        ))
        commandLabel.font = GlobalFontMagnification.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)

        let socketPath = CotermSSHURLProcessLauncher.shared.resolvedSocketPath()
        let commandScrollView = cotermSSHURLTextPreview(request.cliPreview(socketPath: socketPath), height: 80)

        stack.addArrangedSubview(targetLabel)
        stack.addArrangedSubview(commandLabel)
        stack.addArrangedSubview(commandScrollView)

        let checkbox = NSButton(
            checkboxWithTitle: String(
                localized: "dialog.sshURL.checkbox",
                defaultValue: "I trust this SSH target and want coterm to connect."
            ),
            target: gate,
            action: #selector(CotermSSHURLConfirmationGate.checkboxChanged(_:))
        )
        checkbox.lineBreakMode = .byWordWrapping
        stack.addArrangedSubview(checkbox)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 156))
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            targetLabel.widthAnchor.constraint(equalTo: container.widthAnchor),
            commandScrollView.widthAnchor.constraint(equalTo: container.widthAnchor),
            checkbox.widthAnchor.constraint(equalTo: container.widthAnchor)
        ])
        return container
    }

    private func cotermTextURLAccessoryView(request: CotermTextURLRequest) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let localizedKind = request.kind == .prompt
            ? String(localized: "dialog.textURL.kind.prompt", defaultValue: "Prompt")
            : String(localized: "dialog.textURL.kind.rules", defaultValue: "Rules")
        let displayTitle = request.name ?? request.title
        let kindLabel = NSTextField(labelWithString: String(
            format: String(localized: "dialog.textURL.kindLabel", defaultValue: "Link type: %@"),
            localizedKind
        ))
        kindLabel.lineBreakMode = .byTruncatingTail
        kindLabel.maximumNumberOfLines = 1

        let titleLabel = displayTitle.map { displayTitle in
            let label = NSTextField(labelWithString: String(
                format: String(localized: "dialog.textURL.titleLabel", defaultValue: "Title: %@"),
                displayTitle
            ))
            label.lineBreakMode = .byTruncatingMiddle
            label.maximumNumberOfLines = 1
            return label
        }

        let previewLabel = NSTextField(labelWithString: String(
            localized: "dialog.textURL.previewLabel",
            defaultValue: "Text preview:"
        ))
        previewLabel.font = GlobalFontMagnification.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)

        let preview = cotermSSHURLTextPreview(request.pasteText, height: 180)

        stack.addArrangedSubview(kindLabel)
        if let titleLabel {
            stack.addArrangedSubview(titleLabel)
        }
        stack.addArrangedSubview(previewLabel)
        stack.addArrangedSubview(preview)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 238))
        container.addSubview(stack)
        var constraints: [NSLayoutConstraint] = [
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            kindLabel.widthAnchor.constraint(equalTo: container.widthAnchor),
            preview.widthAnchor.constraint(equalTo: container.widthAnchor)
        ]
        if let titleLabel {
            constraints.append(titleLabel.widthAnchor.constraint(equalTo: container.widthAnchor))
        }
        NSLayoutConstraint.activate(constraints)
        return container
    }

    private func cotermSSHURLTextPreview(_ text: String, height: CGFloat) -> NSScrollView {
        let textView = NSTextView(frame: .zero)
        textView.string = text
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textColor = NSColor.labelColor
        textView.font = GlobalFontMagnification.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 560, height: height))
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.heightAnchor.constraint(equalToConstant: height)
        ])
        return scrollView
    }

    private func showCotermSSHURLParseError(_ error: CotermSSHURLParseError) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = String(
            localized: "dialog.sshURL.blocked.title",
            defaultValue: "Coterm SSH Link Blocked"
        )
        alert.informativeText = cotermSSHURLParseErrorMessage(error)
        alert.addButton(withTitle: String(localized: "dialog.sshURL.blocked.ok", defaultValue: "OK"))
        alert.runModal()
    }

    private func showCotermTextURLPasteFailure(_ request: CotermTextURLRequest) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = request.kind == .prompt
            ? String(localized: "dialog.textURL.prompt.pasteFailed.title", defaultValue: "Couldn't Paste Prompt Link")
            : String(localized: "dialog.textURL.rules.pasteFailed.title", defaultValue: "Couldn't Paste Rules Link")
        alert.informativeText = String(
            localized: "dialog.textURL.pasteFailed.message",
            defaultValue: "coterm could not send the link text to a terminal."
        )
        alert.addButton(withTitle: String(localized: "common.ok", defaultValue: "OK"))
        alert.runModal()
    }

    private func showCotermTextURLParseError(_ error: CotermTextURLParseError) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = String(
            localized: "dialog.textURL.blocked.title",
            defaultValue: "coterm Link Blocked"
        )
        alert.informativeText = cotermTextURLParseErrorMessage(error)
        alert.addButton(withTitle: String(localized: "dialog.textURL.blocked.ok", defaultValue: "OK"))
        alert.runModal()
    }

    private func cotermSSHURLParseErrorMessage(_ error: CotermSSHURLParseError) -> String {
        switch error {
        case .missingDestination:
            return String(
                localized: "dialog.sshURL.error.missingDestination",
                defaultValue: "The link did not include an SSH host."
            )
        case .destinationTooLong(let maxLength):
            return String(
                format: String(localized: "dialog.sshURL.error.destinationTooLong", defaultValue: "The SSH target is too long. The maximum length is %lld characters."),
                maxLength
            )
        case .destinationContainsUnsafeCharacters:
            return String(
                localized: "dialog.sshURL.error.destinationContainsUnsafeCharacters",
                defaultValue: "The SSH host or user contains unsupported or hidden characters, so coterm refused to use it."
            )
        case .destinationStartsWithDash:
            return String(
                localized: "dialog.sshURL.error.destinationStartsWithDash",
                defaultValue: "The SSH host or user cannot start with a dash."
            )
        case .titleTooLong(let maxLength):
            return String(
                format: String(localized: "dialog.sshURL.error.titleTooLong", defaultValue: "The workspace title is too long. The maximum length is %lld characters."),
                maxLength
            )
        case .titleContainsUnsafeCharacters:
            return String(
                localized: "dialog.sshURL.error.titleContainsControlCharacters",
                defaultValue: "The workspace title contains hidden control or formatting characters, so coterm refused to use it."
            )
        case .invalidPort:
            return String(
                localized: "dialog.sshURL.error.invalidPort",
                defaultValue: "The SSH port must be between 1 and 65535."
            )
        case .invalidIntegerParameter(let parameter):
            return String(
                format: String(localized: "dialog.sshURL.error.invalidIntegerParameter", defaultValue: "The SSH link included an invalid integer value for parameter: %@"),
                parameter
            )
        case .invalidHostKeyPolicy(let parameter):
            return String(
                format: String(localized: "dialog.sshURL.error.invalidHostKeyPolicy", defaultValue: "The SSH link included an invalid host key policy for parameter: %@"),
                parameter
            )
        case .invalidBooleanParameter(let parameter):
            return String(
                format: String(localized: "dialog.sshURL.error.invalidBooleanParameter", defaultValue: "The SSH link included an invalid boolean value for parameter: %@"),
                parameter
            )
        case .conflictingDestinationParameters:
            return String(
                localized: "dialog.sshURL.error.conflictingDestinationParameters",
                defaultValue: "The link included conflicting SSH target fields."
            )
        case .conflictingTitleParameters:
            return String(
                localized: "dialog.sshURL.error.conflictingTitleParameters",
                defaultValue: "The link included both title and name. Use only one workspace title field."
            )
        case .duplicateParameter(let parameter):
            return String(
                format: String(localized: "dialog.sshURL.error.duplicateParameter", defaultValue: "The SSH link repeated a parameter: %@"),
                parameter
            )
        case .unsupportedParameter(let parameter):
            return String(
                format: String(localized: "dialog.sshURL.error.unsupportedParameter", defaultValue: "The SSH link included an unsupported parameter: %@"),
                parameter
            )
        case .multipleLinks:
            return String(
                localized: "dialog.sshURL.error.multipleLinks",
                defaultValue: "Only one SSH link can be opened at a time."
            )
        }
    }

    private func cotermTextURLParseErrorMessage(_ error: CotermTextURLParseError) -> String {
        switch error {
        case .missingText:
            return String(
                localized: "dialog.textURL.error.missingText",
                defaultValue: "The link did not include text."
            )
        case .textTooLong(let maxLength):
            return String(
                format: String(localized: "dialog.textURL.error.textTooLong", defaultValue: "The link text is too long. The maximum length is %lld characters."),
                maxLength
            )
        case .textContainsUnsafeCharacters:
            return String(
                localized: "dialog.textURL.error.textContainsUnsafeCharacters",
                defaultValue: "The link text contains unsupported or hidden characters, so coterm refused to use it."
            )
        case .nameTooLong(let maxLength):
            return String(
                format: String(localized: "dialog.textURL.error.nameTooLong", defaultValue: "The link name is too long. The maximum length is %lld characters."),
                maxLength
            )
        case .nameContainsUnsafeCharacters:
            return String(
                localized: "dialog.textURL.error.nameContainsUnsafeCharacters",
                defaultValue: "The link name contains hidden control or formatting characters, so coterm refused to use it."
            )
        case .titleTooLong(let maxLength):
            return String(
                format: String(localized: "dialog.textURL.error.titleTooLong", defaultValue: "The link title is too long. The maximum length is %lld characters."),
                maxLength
            )
        case .titleContainsUnsafeCharacters:
            return String(
                localized: "dialog.textURL.error.titleContainsUnsafeCharacters",
                defaultValue: "The link title contains hidden control or formatting characters, so coterm refused to use it."
            )
        case .invalidBooleanParameter(let parameter):
            return String(
                format: String(localized: "dialog.textURL.error.invalidBooleanParameter", defaultValue: "The link included an invalid boolean value for parameter: %@"),
                parameter
            )
        case .duplicateParameter(let parameter):
            return String(
                format: String(localized: "dialog.textURL.error.duplicateParameter", defaultValue: "The link repeated a parameter: %@"),
                parameter
            )
        case .unsupportedParameter(let parameter):
            return String(
                format: String(localized: "dialog.textURL.error.unsupportedParameter", defaultValue: "The link included an unsupported parameter: %@"),
                parameter
            )
        case .multipleLinks:
            return String(
                localized: "dialog.textURL.error.multipleLinks",
            defaultValue: "Only one coterm external link can be opened at a time."
            )
        }
    }
}
