import AppKit
import SwiftUI

struct ShortcutEditorSheet: View {
    let title: String
    let subtitle: String
    @State var shortcut: AppShortcut
    let isAssigned: Bool
    let allowsModifierOnlyShortcut: Bool
    let onSave: (AppShortcut) -> Void
    let onClear: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            ShortcutRecorderView(allowsModifierOnlyShortcut: allowsModifierOnlyShortcut) { recordedShortcut in
                shortcut = recordedShortcut
                onSave(recordedShortcut)
                dismiss()
            }
            .frame(height: 112)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )

            HStack(spacing: 8) {
                Text("Current")
                    .foregroundStyle(.secondary)
                if isAssigned {
                    ShortcutTokenStack(shortcut: shortcut)
                } else {
                    Text("Unassigned")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 14, weight: .medium))

            Spacer()

            HStack {
                Button("Clear") {
                    onClear()
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button("Done") {
                    dismiss()
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct ShortcutTokenStack: View {
    let shortcut: AppShortcut

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tokens, id: \.self) { token in
                Text(token)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            }
        }
    }

    private var tokens: [String] {
        var tokens: [String] = []
        if shortcut.modifiers.contains(.command) { tokens.append("CMD") }
        if shortcut.modifiers.contains(.shift) { tokens.append("SHIFT") }
        if shortcut.modifiers.contains(.option) { tokens.append("OPT") }
        if shortcut.modifiers.contains(.control) { tokens.append("CTRL") }
        tokens.append(shortcut.key.label.uppercased())
        return tokens
    }
}

private struct ShortcutRecorderView: NSViewRepresentable {
    let allowsModifierOnlyShortcut: Bool
    let onRecord: (AppShortcut) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.allowsModifierOnlyShortcut = allowsModifierOnlyShortcut
        view.onRecord = onRecord

        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }

        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.allowsModifierOnlyShortcut = allowsModifierOnlyShortcut
        nsView.onRecord = onRecord
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class ShortcutRecorderNSView: NSView {
    var allowsModifierOnlyShortcut = false
    var onRecord: ((AppShortcut) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async {
            self.window?.makeFirstResponder(self)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let title = "Press a key or key combination"
        let subtitle = allowsModifierOnlyShortcut
            ? "Single keys and modifier-only keys like Control are supported."
            : "Single keys like Space are supported and save immediately."
        let attributedText = NSMutableAttributedString(
            string: "\(title)\n\(subtitle)",
            attributes: [
                .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle,
            ]
        )
        attributedText.addAttributes(
            [
                .font: NSFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
            ],
            range: NSRange(location: title.count + 1, length: subtitle.count)
        )

        let size = attributedText.size()
        let rect = NSRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        attributedText.draw(in: rect)
    }

    override func keyDown(with event: NSEvent) {
        guard let key = AppShortcut.Key(carbonKeyCode: UInt32(event.keyCode)) else {
            NSSound.beep()
            return
        }

        guard !key.isModifierKey else { return }

        let modifiers = AppShortcut.Modifiers(eventModifierFlags: event.modifierFlags)
        onRecord?(AppShortcut(key: key, modifiers: modifiers))
    }

    override func flagsChanged(with event: NSEvent) {
        guard allowsModifierOnlyShortcut else { return }
        guard let key = AppShortcut.Key(carbonKeyCode: UInt32(event.keyCode)), key.isModifierKey else { return }
        onRecord?(AppShortcut(key: key, modifiers: []))
    }
}
