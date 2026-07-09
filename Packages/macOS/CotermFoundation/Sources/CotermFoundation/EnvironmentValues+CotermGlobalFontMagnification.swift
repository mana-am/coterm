public import SwiftUI

/// Adds coterm font magnification values to SwiftUI environment lookups.
public extension EnvironmentValues {
    /// The current clamped global font magnification percent.
    ///
    /// coterm scene roots should inject this value with
    /// ``View/cotermFontMagnificationEnvironment()`` so repeated row labels can
    /// read a pure environment value instead of each subscribing to
    /// `UserDefaults`.
    var cotermGlobalFontMagnificationPercent: Int {
        get { self[CotermGlobalFontMagnificationPercentKey.self] }
        set { self[CotermGlobalFontMagnificationPercentKey.self] = GlobalFontMagnification.clamp(newValue) }
    }
}
