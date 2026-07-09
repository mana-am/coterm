import AppKit

@MainActor
private var cotermBrowserWebKitKeyDownDispatchDepth = 0

@MainActor
func cotermBrowserWebKitKeyDownDispatchIsActive() -> Bool {
    cotermBrowserWebKitKeyDownDispatchDepth > 0
}

@MainActor
func cotermWithBrowserWebKitKeyDownDispatch<T>(_ body: () -> T) -> T {
    cotermBrowserWebKitKeyDownDispatchDepth += 1
    defer {
        cotermBrowserWebKitKeyDownDispatchDepth = max(0, cotermBrowserWebKitKeyDownDispatchDepth - 1)
    }
    return body()
}

@MainActor
extension CotermWebView {
    func forwardKeyDownToWebKit(_ event: NSEvent) {
        cotermWithBrowserWebKitKeyDownDispatch {
            super.keyDown(with: event)
        }
    }
}
