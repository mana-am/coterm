import Testing
@testable import CotermMobileShellUI

/// CotermMobileShellUI is UIKit-bound and iOS-only; its behavior is exercised by
/// the app build and the lower-layer packages' suites. This smoke test keeps the
/// test target valid for simulator-destination CI runs.
@Suite struct CotermMobileShellUISmokeTests {
    @Test func moduleLinks() {
        #expect(Bool(true))
    }
}
