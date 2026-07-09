import CotermMobileShell
import CotermMobileWorkspace
import SwiftUI
#if os(iOS)
@preconcurrency import UIKit
#elseif os(macOS)
import AppKit
#endif

extension MobileRootAuthGate {
    /// Reflects Stack auth state into the legacy shell store's sign-in lifecycle.
    ///
    /// This bridge lives in the feature target because it reaches into the
    /// `CotermMobileShellStore` god object, which sits above the pure
    /// ``MobileRootAuthGate`` policy in ``CotermMobileWorkspace``.
    @MainActor
    static func syncShellAuthentication(
        stackAuthenticated: Bool,
        isRestoringSession: Bool = false,
        store: CotermMobileShellStore
    ) {
        if stackAuthenticated {
            store.signIn()
        } else if !isRestoringSession {
            store.signOut()
        }
    }
}
