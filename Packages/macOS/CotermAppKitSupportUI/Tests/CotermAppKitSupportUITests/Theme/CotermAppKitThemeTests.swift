import AppKit
import CotermFoundation
import Testing

@testable import CotermAppKitSupportUI

@MainActor
@Suite struct CotermAppKitThemeTests {
    @Test func buttonBackgroundColorMatchesHex() {
        #expect(CotermAppKitTheme.buttonBackgroundHex == "#2170FF")
        #expect(CotermAppKitTheme.buttonBackgroundColor.hexString() == "#2170FF")
    }

    @Test func applyButtonStyleSetsBorderedBlueBackgroundAndWhiteTitle() {
        let button = NSButton(title: "Continue", target: nil, action: nil)
        button.isBordered = false
        button.isTransparent = true

        CotermAppKitTheme.applyButtonStyle(to: button)

        #expect(button.isBordered)
        #expect(button.isTransparent == false)
        #expect(button.bezelColor == CotermAppKitTheme.buttonBackgroundColor)
        #expect(button.contentTintColor == CotermAppKitTheme.textColor)

        let foreground = button.attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(foreground == CotermAppKitTheme.textColor)
    }

    @Test func applyTextStyleSetsWhiteForeground() {
        let textField = NSTextField(labelWithString: "Label")
        textField.textColor = .secondaryLabelColor

        CotermAppKitTheme.applyTextStyle(to: textField)

        #expect(textField.textColor == CotermAppKitTheme.textColor)
    }

    @Test func applyTextStylePreservesClearHiddenFields() {
        let hiddenField = NSTextField(string: "")
        hiddenField.textColor = .clear

        CotermAppKitTheme.applyTextStyle(to: hiddenField)

        #expect(hiddenField.textColor == .clear)
    }

    @Test func applyRecursivelyStylesNestedControls() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 80))
        let label = NSTextField(labelWithString: "Status")
        label.textColor = .labelColor
        let button = NSButton(title: "OK", target: nil, action: nil)
        container.addSubview(label)
        container.addSubview(button)

        CotermAppKitTheme.applyRecursively(to: container)

        #expect(label.textColor == CotermAppKitTheme.textColor)
        #expect(button.bezelColor == CotermAppKitTheme.buttonBackgroundColor)
        #expect(button.contentTintColor == CotermAppKitTheme.textColor)
    }
}
