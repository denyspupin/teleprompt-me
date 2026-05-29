import AppKit
import SwiftData
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance
    case shortcuts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "General"
        case .appearance:
            return "Appearance"
        case .shortcuts:
            return "Keyboard Shortcuts"
        }
    }

    var icon: String {
        switch self {
        case .general:
            return "gearshape"
        case .appearance:
            return "textformat"
        case .shortcuts:
            return "command"
        }
    }
}

struct SettingsSidebarView: View {
    @Binding var selectedSection: SettingsSection
    let backAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button {
                backAction()
            } label: {
                Label("Back to app", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .padding(10)

            Divider()

            List(selection: selectedSectionBinding) {
                Section("Settings") {
                    ForEach(SettingsSection.allCases) { section in
                        Label(section.title, systemImage: section.icon)
                            .tag(section)
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    private var selectedSectionBinding: Binding<SettingsSection?> {
        Binding(
            get: { selectedSection },
            set: { newValue in
                if let newValue {
                    selectedSection = newValue
                }
            }
        )
    }
}

struct SettingsWindowView: View {
    @State private var selectedSection: SettingsSection = .general
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebarView(selectedSection: $selectedSection) {
                dismiss()
            }
            .frame(minWidth: 240, maxWidth: 240)

            SettingsView(selectedSection: $selectedSection)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .glassEffect()
    }
}

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]

    @Binding var selectedSection: SettingsSection
    @State private var editingShortcut: AppShortcutCommand?

    private let availableFonts = NSFontManager.shared.availableFontFamilies.sorted()
    private let fontSizeOptions = [20, 24, 30, 36, 42, 48, 56, 64, 72, 84, 96]

    private var currentSettings: AppSettings {
        settings.first ?? AppSettings()
    }

    var body: some View {
        detailPane
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            syncSettingsIntoAppState()
        }
        .sheet(item: $editingShortcut) { target in
            ShortcutEditorSheet(
                title: target.title,
                subtitle: target.subtitle,
                shortcut: shortcut(for: target),
                isAssigned: isShortcutAssigned(target),
                allowsModifierOnlyShortcut: target == .holdToScroll,
                onSave: { newValue in
                    updateShortcut(target, value: newValue)
                },
                onClear: {
                    updateShortcut(target, value: AppShortcut(key: .space, modifiers: []), isAssigned: false)
                }
            )
            .presentationDetents([.height(310)])
        }
    }

    private var detailPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedSection.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(sectionDescription)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                switch selectedSection {
                case .general:
                    generalContent
                case .appearance:
                    appearanceContent
                case .shortcuts:
                    shortcutsContent
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var generalContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Playback") {
                sliderRow(
                    title: "Autoplay speed",
                    subtitle: "Control how quickly the active script advances.",
                    valueText: "\(Int(currentSettings.playbackSpeedWordsPerMinute)) WPM",
                    value: binding(for: \.playbackSpeedWordsPerMinute) { newValue in
                        appState.playbackController.applySpeed(newValue)
                    },
                    range: 60...260,
                    step: 5
                )
            }

            settingsCard(title: "Overlay") {
                toggleRow(
                    title: "Show icon in Dock",
                    subtitle: "Keep TelepromptMe visible in the Dock while it is running.",
                    isOn: binding(for: \.showDockIcon)
                )
                toggleRow(
                    title: "Show menu bar item",
                    subtitle: "Keep quick access to TelepromptMe from the macOS menu bar.",
                    isOn: binding(for: \.showMenuBarItem)
                )
                toggleRow(
                    title: "Keep overlay centered below camera",
                    subtitle: "Position the overlay under the camera area when it opens.",
                    isOn: binding(for: \.keepOverlayCentered)
                )
            }
        }
    }

    private var appearanceContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard(title: "Typography") {
                pickerRow(
                    title: "Font",
                    subtitle: "Choose the typeface used inside the overlay.",
                    selection: binding(for: \.fontName)
                ) {
                    ForEach(availableFonts, id: \.self) { fontName in
                        Text(fontName).tag(fontName)
                    }
                }

                fontSizePickerRow(
                    title: "Font size",
                    subtitle: "Choose the teleprompter text size."
                )

                sliderRow(
                    title: "Line spacing",
                    subtitle: "Adjust the space between lines in the overlay.",
                    valueText: "\(Int(currentSettings.lineSpacing)) pt",
                    value: binding(for: \.lineSpacing),
                    range: 0...32,
                    step: 1
                )

                sliderRow(
                    title: "Overlay opacity",
                    subtitle: "Control how translucent the overlay background appears.",
                    valueText: currentSettings.overlayOpacity.formatted(.number.precision(.fractionLength(2))),
                    value: binding(for: \.overlayOpacity),
                    range: 0.4...1.0,
                    step: 0.02
                )
            }
        }
    }

    private var shortcutsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            settingsCard(title: "Keyboard shortcuts") {
                ForEach(AppShortcutCommand.allCases) { command in
                    shortcutRow(for: command)
                }
            }
        }
    }

    @ViewBuilder
    private func settingsCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
        }
        .background(cardBackground)
    }

    @ViewBuilder
    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        rowContainer {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 24)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    @ViewBuilder
    private func sliderRow(
        title: String,
        subtitle: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        rowContainer(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 15, weight: .medium))
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(valueText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Slider(value: value, in: range, step: step)
                    .tint(.blue)
            }
        }
    }

    @ViewBuilder
    private func pickerRow<SelectionValue: Hashable, PickerContent: View>(
        title: String,
        subtitle: String,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> PickerContent
    ) -> some View {
        rowContainer {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 24)

            Picker(title, selection: selection) {
                content()
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 260)
        }
    }

    @ViewBuilder
    private func fontSizePickerRow(title: String, subtitle: String) -> some View {
        pickerRow(
            title: title,
            subtitle: subtitle,
            selection: fontSizeSelectionBinding
        ) {
            ForEach(fontSizeOptions, id: \.self) { fontSize in
                Text("\(fontSize) pt").tag(fontSize)
            }
        }
    }

    @ViewBuilder
    private func shortcutRow(for target: AppShortcutCommand) -> some View {
        Button {
            if target.isEditable {
                editingShortcut = target
            }
        } label: {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(target.title)
                        .font(.system(size: 15, weight: .medium))
                    Text(target.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 24)

                HStack(spacing: 12) {
                    shortcutBadge(for: target)

                    if target.isEditable && isShortcutAssigned(target) {
                        Button {
                            updateShortcut(target, value: AppShortcut(key: .space, modifiers: []), isAssigned: false)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear shortcut")
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func shortcutBadge(for target: AppShortcutCommand) -> some View {
        if isShortcutAssigned(target) {
            HStack(spacing: 6) {
                ForEach(shortcutTokens(for: shortcut(for: target)), id: \.self) { token in
                    Text(token)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                }
            }
        } else {
            Text("Unassigned")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func rowContainer(
        alignment: VerticalAlignment = .center,
        @ViewBuilder content: () -> some View
    ) -> some View {
        HStack(alignment: alignment, spacing: 18) {
            content()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private var sectionDescription: String {
        switch selectedSection {
        case .general:
            return "Core app behavior and overlay defaults."
        case .appearance:
            return "Adjust how your teleprompter looks on screen."
        case .shortcuts:
            return "Choose the keyboard commands you want available globally."
        }
    }

    private func shortcut(for target: AppShortcutCommand) -> AppShortcut {
        switch target {
        case .toggleOverlay:
            return currentSettings.toggleOverlayShortcut
        case .togglePlayback:
            return currentSettings.togglePlaybackShortcut
        case .holdToScroll:
            return currentSettings.holdToScrollShortcut
        case .stopPlayback, .restartPlayback, .increaseSpeed, .decreaseSpeed, .stepForward, .stepBackward:
            return target.defaultShortcut
        }
    }

    private func isShortcutAssigned(_ target: AppShortcutCommand) -> Bool {
        switch target {
        case .toggleOverlay:
            return currentSettings.toggleOverlayShortcutModifiersRawValue != -1
        case .togglePlayback:
            return currentSettings.togglePlaybackShortcutModifiersRawValue != -1
        case .holdToScroll:
            return (currentSettings.holdToScrollShortcutModifiersRawValue ?? 0) != -1
        case .stopPlayback, .restartPlayback, .increaseSpeed, .decreaseSpeed, .stepForward, .stepBackward:
            return true
        }
    }

    private func shortcutTokens(for shortcut: AppShortcut) -> [String] {
        var tokens: [String] = []
        if shortcut.modifiers.contains(.command) { tokens.append("CMD") }
        if shortcut.modifiers.contains(.shift) { tokens.append("SHIFT") }
        if shortcut.modifiers.contains(.option) { tokens.append("OPT") }
        if shortcut.modifiers.contains(.control) { tokens.append("CTRL") }
        tokens.append(shortcut.key.label.uppercased())
        return tokens
    }

    private func binding<Value>(
        for keyPath: ReferenceWritableKeyPath<AppSettings, Value>,
        onSet: ((Value) -> Void)? = nil
    ) -> Binding<Value> {
        Binding(
            get: {
                currentSettings[keyPath: keyPath]
            },
            set: { newValue in
                let settingsModel = currentSettingsModel()
                settingsModel[keyPath: keyPath] = newValue
                onSet?(newValue)
                try? modelContext.save()
                appState.applySettings(settingsModel)
            }
        )
    }

    private var fontSizeSelectionBinding: Binding<Int> {
        Binding(
            get: {
                nearestFontSizeOption(to: currentSettings.fontSize)
            },
            set: { newValue in
                let settingsModel = currentSettingsModel()
                settingsModel.fontSize = Double(newValue)
                try? modelContext.save()
                appState.applySettings(settingsModel)
            }
        )
    }

    private func nearestFontSizeOption(to value: Double) -> Int {
        fontSizeOptions.min { first, second in
            abs(Double(first) - value) < abs(Double(second) - value)
        } ?? 42
    }

    private func currentSettingsModel() -> AppSettings {
        if let existing = settings.first {
            return existing
        }

        let defaults = AppSettings()
        modelContext.insert(defaults)
        try? modelContext.save()
        return defaults
    }

    private func updateShortcut(_ target: AppShortcutCommand, value: AppShortcut, isAssigned: Bool = true) {
        let settingsModel = currentSettingsModel()

        switch target {
        case .toggleOverlay:
            settingsModel.toggleOverlayShortcut = value
            settingsModel.toggleOverlayShortcutModifiersRawValue = isAssigned ? value.modifiers.rawValue : -1
        case .togglePlayback:
            settingsModel.togglePlaybackShortcut = value
            settingsModel.togglePlaybackShortcutModifiersRawValue = isAssigned ? value.modifiers.rawValue : -1
        case .holdToScroll:
            settingsModel.holdToScrollShortcut = value
            settingsModel.holdToScrollShortcutModifiersRawValue = isAssigned ? value.modifiers.rawValue : -1
        case .stopPlayback, .restartPlayback, .increaseSpeed, .decreaseSpeed, .stepForward, .stepBackward:
            return
        }

        try? modelContext.save()
        appState.applySettings(settingsModel)
    }

    private func syncSettingsIntoAppState() {
        let settingsModel = currentSettingsModel()
        appState.applySettings(settingsModel)
    }
}

private struct ShortcutEditorSheet: View {
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
