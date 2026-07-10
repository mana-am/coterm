import Testing
@testable import CotermSettings

@Test func markerFilesAreVariantAware() {
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "cc.coterm.app",
        environment: [:]
    ) == .stable)
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "cc.coterm.app.nightly",
        environment: [:]
    ) == .nightly(slug: nil))
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "cc.coterm.app.debug.agent",
        environment: [:]
    ) == .dev(slug: "agent"))
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "cc.coterm.app.debug",
        environment: ["COTERM_TAG": "Issue 3542"]
    ) == .dev(slug: "issue-3542"))
    #expect(SocketPathMarkerFiles.variant(
        bundleIdentifier: "cc.coterm.app.debug",
        environment: ["COTERM_TAG": "café"]
    ) == .dev(slug: "caf"))
}

@Test func defaultSocketPathsStayVariantScoped() {
    #expect(SocketPathMarkerFiles.defaultSocketPath(
        bundleIdentifier: "cc.coterm.app",
        environment: [:],
        isDebugBuild: false,
        stableSocketPath: "/stable/coterm.sock"
    ) == "/stable/coterm.sock")
    #expect(SocketPathMarkerFiles.defaultSocketPath(
        bundleIdentifier: "cc.coterm.app.nightly",
        environment: [:],
        isDebugBuild: false,
        stableSocketPath: "/stable/coterm.sock"
    ) == "/tmp/coterm-nightly.sock")
    #expect(SocketPathMarkerFiles.defaultSocketPath(
        bundleIdentifier: "cc.coterm.app.staging.my-feature",
        environment: [:],
        isDebugBuild: false,
        stableSocketPath: "/stable/coterm.sock"
    ) == "/tmp/coterm-staging-my-feature.sock")
    #expect(SocketPathMarkerFiles.defaultSocketPath(
        bundleIdentifier: "cc.coterm.app.debug",
        environment: ["COTERM_TAG": "Issue 3542"],
        isDebugBuild: false,
        stableSocketPath: "/stable/coterm.sock"
    ) == "/tmp/coterm-debug-issue-3542.sock")
}
