import SwiftUI
import AppKit

struct AppKitCommitTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var onCommit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCommit: onCommit)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = LoggingTextField(string: text)
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.isBezeled = false
        textField.isEditable = true
        textField.isSelectable = true
        textField.delegate = context.coordinator
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.commitFromAction)
        textField.focusRingType = .none
        textField.drawsBackground = true
        textField.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.18)
        textField.textColor = NSColor.labelColor
        textField.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: NSColor.secondaryLabelColor]
        )
        textField.refusesFirstResponder = false

        #if DEBUG
        print("[AppKitCommitTextField] makeNSView editable=\(textField.isEditable) selectable=\(textField.isSelectable)")
        #endif

        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        let isEditing = nsView.currentEditor() != nil

        #if DEBUG
        print("[AppKitCommitTextField] updateNSView isEditing=\(isEditing) current='\(nsView.stringValue)' model='\(text)'")
        #endif

        if !isEditing, nsView.stringValue != text {
            nsView.stringValue = text
        }

        nsView.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: NSColor.secondaryLabelColor]
        )
        nsView.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.18)
        nsView.textColor = NSColor.labelColor
        context.coordinator.onCommit = onCommit
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding private var text: String
        var onCommit: () -> Void

        init(text: Binding<String>, onCommit: @escaping () -> Void) {
            _text = text
            self.onCommit = onCommit
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            #if DEBUG
            print("[AppKitCommitTextField] controlTextDidBeginEditing")
            #endif
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text = field.stringValue

            #if DEBUG
            print("[AppKitCommitTextField] controlTextDidChange text='\(field.stringValue)'")
            #endif
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            #if DEBUG
            print("[AppKitCommitTextField] controlTextDidEndEditing")
            #endif
            onCommit()
        }

        @objc func commitFromAction() {
            #if DEBUG
            print("[AppKitCommitTextField] commitFromAction")
            #endif
            onCommit()
        }
    }
}

private final class LoggingTextField: NSTextField {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        #if DEBUG
        print("[AppKitCommitTextField] mouseDown")
        #endif
        super.mouseDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        #if DEBUG
        print("[AppKitCommitTextField] becomeFirstResponder result=\(result)")
        #endif
        return result
    }

    override func keyDown(with event: NSEvent) {
        #if DEBUG
        print("[AppKitCommitTextField] keyDown keyCode=\(event.keyCode) chars='\(event.characters ?? "")'")
        #endif
        super.keyDown(with: event)
    }
}
