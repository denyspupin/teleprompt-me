import AppKit
import SwiftUI

struct ShortcutEditorSheet: View {
    let command: AppShortcutCommand
    @State var shortcut: AppShortcut
    let isAssigned: Bool
    let onSave: (AppShortcut) -> Void
    let onClear: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(command.title)
                    .font(.title2.weight(.semibold))
                Text(command.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ShortcutRecorderView { recordedShortcut in
                shortcut = recordedShortcut
            }
            .frame(height: 112)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.7))
            }

            HStack(spacing: 8) {
                Text("New shortcut")
                    .foregroundStyle(.secondary)
                ShortcutBadge(shortcut: shortcut)
            }

            Spacer()

            HStack {
                Button("Clear Shortcut") {
                    onClear()
                    dismiss()
                }
                .disabled(!isAssigned)

                Spacer()

                Button("Cancel", role: .cancel) {
                    dismiss()
                }

                Button("Save") {
                    onSave(shortcut)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 520, height: 300)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct ShortcutBadge: View {
    let shortcut: AppShortcut

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tokens, id: \.self) { token in
                Text(token)
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(shortcut.displayName)
    }

    private var tokens: [String] {
        var values: [String] = []
        if shortcut.modifiers.contains(.command) { values.append("⌘") }
        if shortcut.modifiers.contains(.shift) { values.append("⇧") }
        if shortcut.modifiers.contains(.option) { values.append("⌥") }
        if shortcut.modifiers.contains(.control) { values.append("⌃") }
        values.append(shortcut.key.label.uppercased())
        return values
    }
}

private struct ShortcutRecorderView: NSViewRepresentable {
    let onRecord: (AppShortcut) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.onRecord = onRecord
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.onRecord = onRecord
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class ShortcutRecorderNSView: NSView {
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
        let title = "Press a key combination"
        let subtitle = "The shortcut is captured here, then saved when you confirm."
        let text = NSMutableAttributedString(
            string: "\(title)\n\(subtitle)",
            attributes: [
                .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle,
            ]
        )
        text.addAttributes(
            [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.secondaryLabelColor,
            ],
            range: NSRange(location: title.count + 1, length: subtitle.count)
        )

        let size = text.size()
        text.draw(
            in: NSRect(
                x: (bounds.width - size.width) / 2,
                y: (bounds.height - size.height) / 2,
                width: size.width,
                height: size.height
            )
        )
    }

    override func keyDown(with event: NSEvent) {
        guard let key = AppShortcut.Key(carbonKeyCode: UInt32(event.keyCode)),
              !key.isModifierKey else {
            NSSound.beep()
            return
        }

        let modifiers = AppShortcut.Modifiers(eventModifierFlags: event.modifierFlags)
        onRecord?(AppShortcut(key: key, modifiers: modifiers))
        needsDisplay = true
    }
}
