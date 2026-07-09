import AppKit

enum FindFocusNotificationKey {
    static let selectAll = "coterm.find.selectAll"
}

func cotermClampedFindSelection(_ range: NSRange, in text: String) -> NSRange {
    let textLength = text.utf16.count
    guard range.location != NSNotFound else {
        return NSRange(location: textLength, length: 0)
    }
    let location = min(max(range.location, 0), textLength)
    let length = min(max(range.length, 0), textLength - location)
    return NSRange(location: location, length: length)
}

func cotermTextFieldIsFirstResponder(_ field: NSTextField, in window: NSWindow) -> Bool {
    let firstResponder = window.firstResponder
    if firstResponder === field { return true }
    if let editor = field.currentEditor() as? NSTextView, firstResponder === editor { return true }
    return (firstResponder as? NSTextView).flatMap { cotermFieldEditorOwnerView($0) } === field
}

private let cotermFindSelectionChangingCommands: Set<String> = [
    "moveLeft:",
    "moveRight:",
    "moveBackward:",
    "moveForward:",
    "moveUp:",
    "moveDown:",
    "moveWordLeft:",
    "moveWordRight:",
    "moveWordBackward:",
    "moveWordForward:",
    "moveToBeginningOfLine:",
    "moveToEndOfLine:",
    "moveToBeginningOfDocument:",
    "moveToEndOfDocument:",
    "moveLeftAndModifySelection:",
    "moveRightAndModifySelection:",
    "moveBackwardAndModifySelection:",
    "moveForwardAndModifySelection:",
    "moveUpAndModifySelection:",
    "moveDownAndModifySelection:",
    "moveWordLeftAndModifySelection:",
    "moveWordRightAndModifySelection:",
    "moveWordBackwardAndModifySelection:",
    "moveWordForwardAndModifySelection:",
    "moveToBeginningOfLineAndModifySelection:",
    "moveToEndOfLineAndModifySelection:",
    "moveToBeginningOfDocumentAndModifySelection:",
    "moveToEndOfDocumentAndModifySelection:",
    "selectAll:",
]

func cotermFindCommandMayChangeSelection(_ selector: Selector) -> Bool {
    cotermFindSelectionChangingCommands.contains(NSStringFromSelector(selector))
}

func cotermFindEventIsPlainEscape(_ event: NSEvent) -> Bool {
    ShortcutStroke.normalizedModifierFlags(from: event.modifierFlags).isEmpty && ShortcutStroke.isEscapeCancelEvent(event)
}

private let cotermFindSelectionStore = NSMapTable<AnyObject, NSValue>.weakToStrongObjects()
private let cotermFindFieldEditorOwners = NSMapTable<NSTextView, FindSelectionTrackingTextField>.weakToWeakObjects()

func cotermStoredFindSelection(for owner: AnyObject?) -> NSRange? {
    guard let owner else { return nil }
    return cotermFindSelectionStore.object(forKey: owner)?.rangeValue
}

func cotermStoreFindSelection(_ range: NSRange, for owner: AnyObject?) {
    guard let owner else { return }
    cotermFindSelectionStore.setObject(NSValue(range: range), forKey: owner)
}

func cotermTrackedFindFieldEditorOwner(_ editor: NSTextView) -> FindSelectionTrackingTextField? {
    guard editor.isFieldEditor else { return nil }
    return cotermFindFieldEditorOwners.object(forKey: editor)
}

func cotermFindTextFieldOwner(for responder: NSResponder?) -> FindSelectionTrackingTextField? {
    if let field = responder as? FindSelectionTrackingTextField {
        return field
    }
    if let editor = responder as? NSTextView {
        return cotermTrackedFindFieldEditorOwner(editor) ?? (cotermFieldEditorOwnerView(editor) as? FindSelectionTrackingTextField)
    }
    return nil
}

@MainActor
func cotermRememberFindSelectionBeforePanelFocusMove(tabManager: TabManager?, window: NSWindow?) {
    guard let editor = window?.firstResponder as? NSTextView else { return }
    let selection = cotermClampedFindSelection(editor.selectedRange(), in: editor.string)
    if let field = cotermTrackedFindFieldEditorOwner(editor),
       let owner = field.cotermSelectionOwner {
        _ = field.cotermRememberSelection(selection, in: editor.string)
        cotermStoreFindSelection(selection, for: owner)
        return
    }
    guard let workspace = tabManager?.selectedWorkspace,
          let focusedPanelId = workspace.focusedPanelId else { return }
    let owner = (workspace.terminalPanel(for: focusedPanelId)?.searchState as AnyObject?) ?? (workspace.browserPanel(for: focusedPanelId)?.searchState as AnyObject?)
    guard let owner else { return }
    cotermStoreFindSelection(selection, for: owner)
}

@discardableResult
func cotermApplyFindFocusSelection(
    field: FindSelectionTrackingTextField,
    selectAll: Bool,
    alreadyFocused: Bool,
    rememberedRange: NSRange?
) -> NSRange? {
    guard let editor = field.currentEditor() as? NSTextView, !editor.hasMarkedText() else { return nil }
    if selectAll {
        let selection = field.cotermRememberSelection(NSRange(location: 0, length: editor.string.utf16.count), in: editor.string)
        editor.setSelectedRange(selection)
        return selection
    }
    guard !alreadyFocused, let rememberedRange else { return nil }
    let selection = field.cotermRememberSelection(rememberedRange, in: editor.string)
    editor.setSelectedRange(selection)
    return selection
}

@discardableResult
func cotermRememberFindSelection(in root: NSView?) -> NSRange? {
    guard let root else { return nil }
    if let field = root as? FindSelectionTrackingTextField,
       let selection = field.cotermRememberSelectionFromCurrentEditor() {
        return selection
    }
    for subview in root.subviews {
        if let selection = cotermRememberFindSelection(in: subview) {
            return selection
        }
    }
    return nil
}

func cotermFindResponderSnapshot() -> [String: String] {
    let responder = (NSApp.keyWindow ?? NSApp.mainWindow)?.firstResponder
    var updates: [String: String] = [
        "firstResponderType": responder.map { String(describing: type(of: $0)) } ?? "",
        "firstResponderIdentifier": (responder as? NSView)?.identifier?.rawValue ?? "",
    ]
    if let textView = responder as? NSTextView {
        updates["firstResponderSelectedRange"] = NSStringFromRange(textView.selectedRange())
        if let owner = cotermFieldEditorOwnerView(textView) {
            updates["fieldEditorOwnerType"] = String(describing: type(of: owner))
            updates["fieldEditorOwnerIdentifier"] = owner.identifier?.rawValue ?? ""
        }
    }
    return updates
}

class FindSelectionTrackingTextField: NSTextField {
    var cotermLastSelectedRange: NSRange?
    weak var cotermSelectionOwner: AnyObject?
    var cotermOnEscape: ((NSTextView) -> Bool)?
    private var cotermSelectionObserver: NSObjectProtocol?
    private var cotermKeyMonitor: Any?
    private weak var cotermObservedEditor: NSTextView?
    private weak var cotermPreviousEditorNextResponder: NSResponder?

    deinit {
        cotermDetachSelectionObserver()
        cotermRemoveKeyMonitor()
    }

    override func becomeFirstResponder() -> Bool {
        guard super.becomeFirstResponder() else { return false }
        cotermAttachSelectionObserverIfNeeded()
        cotermRestoreRememberedSelection()
        return true
    }

    override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
        cotermAttachSelectionObserverIfNeeded()
        cotermInstallKeyMonitorIfNeeded()
        if cotermLastSelectedRange == nil, cotermStoredFindSelection(for: cotermSelectionOwner) == nil {
            _ = cotermRememberSelectionFromCurrentEditor()
        }
    }

    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        _ = cotermRememberSelectionFromCurrentEditor()
    }

    override func textDidEndEditing(_ notification: Notification) {
        _ = cotermRememberSelectionFromCurrentEditor()
        cotermRemoveKeyMonitor()
        cotermDetachSelectionObserver()
        super.textDidEndEditing(notification)
    }

    override func cancelOperation(_ sender: Any?) {
        if let editor = currentEditor() as? NSTextView, !editor.hasMarkedText(), cotermOnEscape?(editor) == true {
            return
        }
        super.cancelOperation(sender)
    }

    func cotermRememberSelection(_ range: NSRange, in text: String) -> NSRange {
        let selection = cotermClampedFindSelection(range, in: text)
        cotermLastSelectedRange = selection
        cotermStoreFindSelection(selection, for: cotermSelectionOwner)
        return selection
    }

    func cotermRememberSelection(from textView: NSTextView) -> NSRange {
        cotermRememberSelection(textView.selectedRange(), in: textView.string)
    }

    func cotermRememberSelectionFromCurrentEditor() -> NSRange? {
        guard let editor = currentEditor() as? NSTextView else { return nil }
        return cotermRememberSelection(from: editor)
    }

    private func cotermAttachSelectionObserverIfNeeded() {
        guard let editor = currentEditor() as? NSTextView else { return }
        if let cotermObservedEditor, cotermObservedEditor !== editor {
            cotermDetachSelectionObserver()
        }
        cotermAdoptFieldEditor(editor)
        guard cotermSelectionObserver == nil else { return }
        cotermSelectionObserver = NotificationCenter.default.addObserver(
            forName: NSTextView.didChangeSelectionNotification,
            object: editor,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let textView = notification.object as? NSTextView else { return }
            _ = self.cotermRememberSelection(from: textView)
        }
    }

    private func cotermDetachSelectionObserver() {
        if let cotermSelectionObserver {
            NotificationCenter.default.removeObserver(cotermSelectionObserver)
            self.cotermSelectionObserver = nil
        }
        if let editor = cotermObservedEditor {
            if editor.nextResponder === self {
                editor.nextResponder = cotermPreviousEditorNextResponder
            }
            if cotermTrackedFindFieldEditorOwner(editor) === self {
                cotermFindFieldEditorOwners.removeObject(forKey: editor)
            }
        }
        cotermPreviousEditorNextResponder = nil
        cotermObservedEditor = nil
    }

    private func cotermAdoptFieldEditor(_ editor: NSTextView) {
        cotermObservedEditor = editor
        cotermFindFieldEditorOwners.setObject(self, forKey: editor)
        if editor.nextResponder !== self {
            cotermPreviousEditorNextResponder = editor.nextResponder
            editor.nextResponder = self
        }
        cotermInstallKeyMonitorIfNeeded()
    }

    private func cotermInstallKeyMonitorIfNeeded() {
        guard cotermKeyMonitor == nil else { return }
        cotermKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let eventWindow = event.window ?? (event.windowNumber > 0 ? NSApp.window(withWindowNumber: event.windowNumber) : nil)
            guard let self,
                  eventWindow == nil || eventWindow === self.window,
                  let editor = self.currentEditor() as? NSTextView,
                  self.window?.firstResponder === editor else { return event }
            if cotermFindEventIsPlainEscape(event), !editor.hasMarkedText(), self.cotermOnEscape?(editor) == true { return nil }
            DispatchQueue.main.async { [weak self, weak editor] in
                guard let self, let editor else { return }
                _ = self.cotermRememberSelection(from: editor)
            }
            return event
        }
    }

    private func cotermRemoveKeyMonitor() {
        if let cotermKeyMonitor {
            NSEvent.removeMonitor(cotermKeyMonitor)
            self.cotermKeyMonitor = nil
        }
    }

    private func cotermRestoreRememberedSelection() {
        guard let rememberedSelection = cotermStoredFindSelection(for: cotermSelectionOwner) ?? cotermLastSelectedRange else { return }
        if let editor = currentEditor() as? NSTextView, !editor.hasMarkedText() {
            let selection = cotermRememberSelection(rememberedSelection, in: editor.string)
            editor.setSelectedRange(selection)
        }
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let editor = self.currentEditor() as? NSTextView,
                  !editor.hasMarkedText() else { return }
            let selection = self.cotermRememberSelection(rememberedSelection, in: editor.string)
            editor.setSelectedRange(selection)
        }
    }
}
