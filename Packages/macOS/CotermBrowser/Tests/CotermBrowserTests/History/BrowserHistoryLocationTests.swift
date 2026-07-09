import Foundation
import Testing
@testable import CotermBrowser

@Suite struct BrowserHistoryLocationTests {
    @Test func foldsDebugAndStagingNamespaces() {
        #expect(BrowserHistoryLocation.normalizedNamespace(bundleIdentifier: "coterm.com.emergent.app.debug.my-tag") == "coterm.com.emergent.app.debug")
        #expect(BrowserHistoryLocation.normalizedNamespace(bundleIdentifier: "coterm.com.emergent.app.staging.rc") == "coterm.com.emergent.app.staging")
        #expect(BrowserHistoryLocation.normalizedNamespace(bundleIdentifier: "coterm.com.emergent.app") == "coterm.com.emergent.app")
    }

    @Test func historyFileURLNestsUnderNamespace() {
        let root = URL(fileURLWithPath: "/tmp/appsupport", isDirectory: true)
        let location = BrowserHistoryLocation(applicationSupportDirectory: root, bundleIdentifier: "coterm.com.emergent.app.debug.tag")
        #expect(location.namespace == "coterm.com.emergent.app.debug")
        #expect(location.historyFileURL.path == "/tmp/appsupport/coterm.com.emergent.app.debug/browser_history.json")
    }

    @Test func legacyURLPresentOnlyWhenNamespaceDiffers() {
        let root = URL(fileURLWithPath: "/tmp/appsupport", isDirectory: true)
        let tagged = BrowserHistoryLocation(applicationSupportDirectory: root, bundleIdentifier: "coterm.com.emergent.app.debug.tag")
        #expect(tagged.legacyTaggedHistoryFileURL?.path == "/tmp/appsupport/coterm.com.emergent.app.debug.tag/browser_history.json")

        let prod = BrowserHistoryLocation(applicationSupportDirectory: root, bundleIdentifier: "coterm.com.emergent.app")
        #expect(prod.legacyTaggedHistoryFileURL == nil)
    }
}
