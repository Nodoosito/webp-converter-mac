import SwiftUI
import AppKit

struct AppKitCommitTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var onCommit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCommit: onCommit)
    }

    func makeNSView(context: Context) -> ContainerView {
        let container = ContainerView()
        let textField = FocusableTextField(string: text)

        textField.placeholderString = placeholder
        textField.isBordered = true
        textField.isBezeled = true
        textField.isEditable = true
        textField.isSelectable = true
        textField.focusRingType = .default
        textField.refusesFirstResponder = false
        textField.delegate = context.coordinator
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.commitFromAction)

        container.install(textField: textField)
        context.coordinator.textField = textField

        return container
    }

    func updateNSView(_ nsView: ContainerView, context: Context) {
        guard let textField = nsView.textField else { return }

        let isEditing = textField.currentEditor() != nil
        if !isEditing, textField.stringValue != text {
            textField.stringValue = text
        }

        textField.placeholderString = placeholder
        context.coordinator.onCommit = onCommit
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding private var text: String
        var onCommit: () -> Void
        weak var textField: NSTextField?

        init(text: Binding<String>, onCommit: @escaping () -> Void) {
            _text = text
            self.onCommit = onCommit
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            #if DEBUG
            print("[AppKitCommitTextField] begin editing")
            #endif
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text = field.stringValue
            #if DEBUG
            print("[AppKitCommitTextField] text changed: \(field.stringValue)")
            #endif
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            #if DEBUG
            print("[AppKitCommitTextField] end editing")
            #endif
            onCommit()
        }

        @objc func commitFromAction() {
            onCommit()
        }
    }
}

final class ContainerView: NSView {
    fileprivate private(set) var textField: FocusableTextField?

    override var acceptsFirstResponder: Bool { false }

    func install(textField: FocusableTextField) {
        self.textField = textField
        textField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
            textField.topAnchor.constraint(equalTo: topAnchor),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

final class FocusableTextField: NSTextField {
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        #if DEBUG
        if result {
            print("[AppKitCommitTextField] became first responder")
        }
        #endif
        return result
    }
}
