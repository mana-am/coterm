import XCTest
import AppKit
import WebKit
import ObjectiveC.runtime

#if canImport(Coterm_DEV)
@testable import Coterm_DEV
#elseif canImport(Coterm)
@testable import Coterm
#endif

private var cotermUnitTestCotermWebViewKeyDownOverrideInstalled = false
private var cotermUnitTestCotermWebViewKeyDownHook: ((CotermWebView, NSEvent) -> Bool)?

extension CotermWebView {
    @objc func cotermUnitTest_keyDown(with event: NSEvent) {
        if cotermUnitTestCotermWebViewKeyDownHook?(self, event) == true {
            return
        }
        cotermUnitTest_keyDown(with: event)
    }
}

private func installCotermUnitTestCotermWebViewKeyDownOverride() {
    guard !cotermUnitTestCotermWebViewKeyDownOverrideInstalled else { return }

    let originalSelector = #selector(CotermWebView.keyDown(with:))
    let swizzledSelector = #selector(CotermWebView.cotermUnitTest_keyDown(with:))

    guard let originalMethod = class_getInstanceMethod(CotermWebView.self, originalSelector),
          let swizzledMethod = class_getInstanceMethod(CotermWebView.self, swizzledSelector) else {
        fatalError("Unable to locate CotermWebView keyDown methods for swizzling")
    }

    method_exchangeImplementations(originalMethod, swizzledMethod)
    cotermUnitTestCotermWebViewKeyDownOverrideInstalled = true
}

final class CotermWebViewKeyDownReentryTests: XCTestCase {
    @MainActor
    func testPrintableOptionTextRoutesToBrowserKeyDownOnce() {
        withHookedBrowserKeyDownWindow { window, keyDownEvents in
            guard let event = makeKeyDownEvent(
                key: "å",
                modifiers: [.option],
                keyCode: 0,
                windowNumber: window.windowNumber
            ) else {
                XCTFail("Failed to construct printable Option event")
                return
            }

            XCTAssertTrue(window.performKeyEquivalent(with: event))
            XCTAssertEqual(keyDownEvents().map(\.keyCode), [0])
        }
    }

    @MainActor
    func testPrintableOptionTextDoesNotReenterBrowserKeyDownDuringWebKitKeyDownDispatch() {
        withHookedBrowserKeyDownWindow { window, keyDownEvents in
            guard let event = makeKeyDownEvent(
                key: "å",
                modifiers: [.option],
                keyCode: 0,
                windowNumber: window.windowNumber
            ) else {
                XCTFail("Failed to construct printable Option event")
                return
            }

            let handled = cotermWithBrowserWebKitKeyDownDispatch {
                window.performKeyEquivalent(with: event)
            }

            XCTAssertFalse(handled)
            XCTAssertTrue(keyDownEvents().isEmpty)
        }
    }

    @MainActor
    func testBrowserReturnDoesNotReenterBrowserKeyDownDuringWebKitKeyDownDispatch() {
        withHookedBrowserKeyDownWindow { window, keyDownEvents in
            guard let event = makeKeyDownEvent(
                key: "\r",
                modifiers: [],
                keyCode: 36,
                windowNumber: window.windowNumber
            ) else {
                XCTFail("Failed to construct Return event")
                return
            }

            let handled = cotermWithBrowserWebKitKeyDownDispatch {
                window.performKeyEquivalent(with: event)
            }

            XCTAssertFalse(handled)
            XCTAssertTrue(keyDownEvents().isEmpty)
        }
    }

    @MainActor
    func testBrowserArrowDoesNotReenterBrowserKeyDownDuringWebKitKeyDownDispatch() {
        withHookedBrowserKeyDownWindow { window, keyDownEvents in
            guard let event = makeKeyDownEvent(
                key: "\u{F701}",
                modifiers: [],
                keyCode: 125,
                windowNumber: window.windowNumber
            ) else {
                XCTFail("Failed to construct Down Arrow event")
                return
            }

            let handled = cotermWithBrowserWebKitKeyDownDispatch {
                window.performKeyEquivalent(with: event)
            }

            XCTAssertFalse(handled)
            XCTAssertTrue(keyDownEvents().isEmpty)
        }
    }

    @MainActor
    private func withHookedBrowserKeyDownWindow(
        _ body: (NSWindow, () -> [NSEvent]) -> Void
    ) {
        _ = NSApplication.shared
        AppDelegate.installWindowResponderSwizzlesForTesting()
        installCotermUnitTestCotermWebViewKeyDownOverride()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        let container = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView = container

        let webView = CotermWebView(frame: container.bounds, configuration: WKWebViewConfiguration())
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)

        var keyDownEvents: [NSEvent] = []
        cotermUnitTestCotermWebViewKeyDownHook = { currentWebView, event in
            guard currentWebView === webView else { return false }
            keyDownEvents.append(event)
            return true
        }

        window.makeKeyAndOrderFront(nil)
        defer {
            cotermUnitTestCotermWebViewKeyDownHook = nil
            window.orderOut(nil)
        }

        XCTAssertTrue(window.makeFirstResponder(webView))
        body(window, { keyDownEvents })
    }

    private func makeKeyDownEvent(
        key: String,
        modifiers: NSEvent.ModifierFlags,
        keyCode: UInt16,
        windowNumber: Int
    ) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: windowNumber,
            context: nil,
            characters: key,
            charactersIgnoringModifiers: key,
            isARepeat: false,
            keyCode: keyCode
        )
    }
}
