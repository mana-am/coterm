import Foundation
import Testing
@testable import CotermBrowser

@Suite struct BrowserHistoryLocationTests {
    @Test func foldsDebugAndStagingNamespaces() {
        #expect(BrowserHistoryLocation.normalizedNamespace(bundleIdentifier: "cc.coterm.app.debug.my-tag") == "cc.coterm.app.debug")
        #expect(BrowserHistoryLocation.normalizedNamespace(bundleIdentifier: "cc.coterm.app.staging.rc") == "cc.coterm.app.staging")
        #expect(BrowserHistoryLocation.normalizedNamespace(bundleIdentifier: "cc.coterm.app") == "cc.coterm.app")
    }

    @Test func historyFileURLNestsUnderNamespace() {
        let root = URL(fileURLWithPath: "/tmp/appsupport", isDirectory: true)
        let location = BrowserHistoryLocation(applicationSupportDirectory: root, bundleIdentifier: "cc.coterm.app.debug.tag")
        #expect(location.namespace == "cc.coterm.app.debug")
        #expect(location.historyFileURL.path == "/tmp/appsupport/cc.coterm.app.debug/browser_history.json")
    }

    @Test func legacyURLPresentOnlyWhenNamespaceDiffers() {
        let root = URL(fileURLWithPath: "/tmp/appsupport", isDirectory: true)
        let tagged = BrowserHistoryLocation(applicationSupportDirectory: root, bundleIdentifier: "cc.coterm.app.debug.tag")
        #expect(tagged.legacyTaggedHistoryFileURL?.path == "/tmp/appsupport/cc.coterm.app.debug.tag/browser_history.json")

        let prod = BrowserHistoryLocation(applicationSupportDirectory: root, bundleIdentifier: "cc.coterm.app")
        #expect(prod.legacyTaggedHistoryFileURL == nil)
    }
}
