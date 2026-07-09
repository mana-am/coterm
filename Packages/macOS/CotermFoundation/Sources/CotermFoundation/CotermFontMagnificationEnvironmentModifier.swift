public import SwiftUI

/// Injects the stored coterm font magnification percent into a SwiftUI subtree.
struct CotermFontMagnificationEnvironmentModifier: ViewModifier {
    @AppStorage(GlobalFontMagnification.percentKey) private var percent = GlobalFontMagnification.defaultPercent

    func body(content: Content) -> some View {
        content.environment(\.cotermGlobalFontMagnificationPercent, percent)
    }
}
