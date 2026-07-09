import CotermFoundation
import SwiftUI

struct OptionalDSLFont: ViewModifier {
    let spec: DSLFontSpec?

    func body(content: Content) -> some View {
        if let spec {
            content.cotermFont(
                size: spec.baseSize,
                weight: spec.weight ?? .regular,
                design: spec.design
            )
        } else {
            content
        }
    }
}
