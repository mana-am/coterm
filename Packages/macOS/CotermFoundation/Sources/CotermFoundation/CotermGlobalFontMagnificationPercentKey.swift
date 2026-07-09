import SwiftUI

/// Stores the current global font magnification percent in the SwiftUI environment.
struct CotermGlobalFontMagnificationPercentKey: EnvironmentKey {
    static var defaultValue: Int { GlobalFontMagnification.storedPercent }
}
