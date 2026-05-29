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

struct SidebarHoverRow: View {
    let title: String
    let systemImage: String
    var isSelected: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Label(title, systemImage: systemImage)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selectedBackgroundColor)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(hoverBackgroundColor)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onHover { hovering in
                isHovered = hovering
            }
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var hoverBackgroundColor: Color {
        switch colorScheme {
        case .dark:
            return Color.white.opacity(0.08)
        default:
            return Color.black.opacity(0.06)
        }
    }

    private var selectedBackgroundColor: Color {
        Color.accentColor
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
                SidebarHoverRow(title: "Back to app", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            .padding(10)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Settings")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)

                    VStack(spacing: 6) {
                        ForEach(SettingsSection.allCases) { section in
                            Button {
                                selectedSection = section
                            } label: {
                                SidebarHoverRow(
                                    title: section.title,
                                    systemImage: section.icon,
                                    isSelected: selectedSection == section
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.never)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
    private let settingsControlColumnWidth: CGFloat = 280

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
        ScrollView(.vertical) {
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
        .scrollIndicators(.automatic)
    }

    private var generalContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsSection(title: "Playback") {
                settingsCard {
                    sliderRow(
                        title: "Autoplay speed",
                        subtitle: "Control how quickly the active script advances.",
                        valueText: "\(Int(currentSettings.playbackSpeedWordsPerMinute)) WPM",
                        value: binding(for: \.playbackSpeedWordsPerMinute) { newValue in
                            appState.playbackController.applySpeed(newValue)
                        },
                        range: 60...260,
                        step: 5,
                        showsDivider: false
                    )
                }
            }

            settingsSection(title: "Overlay") {
                settingsCard {
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
                        isOn: binding(for: \.keepOverlayCentered),
                        showsDivider: false
                    )
                }
            }
        }
    }

    private var appearanceContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsSection(title: "Typography") {
                settingsCard {
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
                        step: 0.02,
                        showsDivider: false
                    )
                }
            }
        }
    }

    private var shortcutsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            settingsSection(title: "Keyboard Shortcuts") {
                settingsCard {
                    shortcutHeaderRow()

                    ForEach(Array(AppShortcutCommand.allCases.enumerated()), id: \.element) { index, command in
                        shortcutRow(
                            for: command,
                            showsDivider: index < AppShortcutCommand.allCases.count - 1
                        )
                    }
                }
            }
        }
    }

    private func shortcutHeaderRow() -> some View {
        HStack(spacing: 18) {
            Text("Command")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Keybinding")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: settingsControlColumnWidth, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .modifier(SettingsRowDivider(showsDivider: true))
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            content()
        }
    }

    @ViewBuilder
    private func settingsCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func toggleRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        showsDivider: Bool = true
    ) -> some View {
        rowContainer(showsDivider: showsDivider) {
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
        step: Double,
        showsDivider: Bool = true
    ) -> some View {
        rowContainer(alignment: .top, showsDivider: showsDivider) {
            settingsTextColumn(title: title, subtitle: subtitle)

            Spacer(minLength: 24)

            VStack(alignment: .trailing, spacing: 14) {
                Text(valueText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                MinimalSlider(
                    value: value,
                    range: range,
                    step: step
                )
                .frame(width: settingsControlColumnWidth)
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
            settingsTextColumn(title: title, subtitle: subtitle)

            Spacer(minLength: 24)

            HStack {
                Spacer(minLength: 0)

                Picker(title, selection: selection) {
                    content()
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.large)
            }
            .frame(width: settingsControlColumnWidth, alignment: .trailing)
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
    private func shortcutRow(
        for target: AppShortcutCommand,
        showsDivider: Bool = true
    ) -> some View {
        Button {
            editingShortcut = target
        } label: {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(target.title)
                        .font(.system(size: 15, weight: .medium))
                    Text(target.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    shortcutBindingView(for: target)

                    Spacer(minLength: 0)

                    if isShortcutAssigned(target) {
                        Button {
                            updateShortcut(target, value: AppShortcut.unassigned, isAssigned: false)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Unassign shortcut")
                    }
                }
                .frame(width: settingsControlColumnWidth, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .modifier(SettingsRowDivider(showsDivider: showsDivider))
    }

    @ViewBuilder
    private func shortcutBindingView(for target: AppShortcutCommand) -> some View {
        if isShortcutAssigned(target) {
            Text(shortcutGlyphString(for: shortcut(for: target)))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
        } else {
            Text("Unassigned")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func rowContainer(
        alignment: VerticalAlignment = .center,
        showsDivider: Bool = true,
        @ViewBuilder content: () -> some View
    ) -> some View {
        HStack(alignment: alignment, spacing: 18) {
            content()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.clear)
        .modifier(SettingsRowDivider(showsDivider: showsDivider))
    }

    private func settingsTextColumn(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
        case .stopPlayback:
            return currentSettings.stopPlaybackShortcut
        case .restartPlayback:
            return currentSettings.restartPlaybackShortcut
        case .increaseSpeed:
            return currentSettings.increaseSpeedShortcut
        case .decreaseSpeed:
            return currentSettings.decreaseSpeedShortcut
        case .stepForward:
            return currentSettings.stepForwardShortcut
        case .stepBackward:
            return currentSettings.stepBackwardShortcut
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
        case .stopPlayback:
            return currentSettings.stopPlaybackShortcutModifiersRawValue != -1
        case .restartPlayback:
            return currentSettings.restartPlaybackShortcutModifiersRawValue != -1
        case .increaseSpeed:
            return currentSettings.increaseSpeedShortcutModifiersRawValue != -1
        case .decreaseSpeed:
            return currentSettings.decreaseSpeedShortcutModifiersRawValue != -1
        case .stepForward:
            return currentSettings.stepForwardShortcutModifiersRawValue != -1
        case .stepBackward:
            return currentSettings.stepBackwardShortcutModifiersRawValue != -1
        }
    }

    private func shortcutGlyphString(for shortcut: AppShortcut) -> String {
        let modifiers = [
            shortcut.modifiers.contains(.control) ? "⌃" : nil,
            shortcut.modifiers.contains(.option) ? "⌥" : nil,
            shortcut.modifiers.contains(.shift) ? "⇧" : nil,
            shortcut.modifiers.contains(.command) ? "⌘" : nil,
        ].compactMap { $0 }.joined()

        return modifiers + shortcutKeyGlyph(for: shortcut.key)
    }

    private func shortcutKeyGlyph(for key: AppShortcut.Key) -> String {
        switch key {
        case .space:
            return "Space"
        case .return:
            return "↩"
        case .upArrow:
            return "↑"
        case .downArrow:
            return "↓"
        case .commandKey:
            return "⌘"
        case .shiftKey:
            return "⇧"
        case .optionKey:
            return "⌥"
        case .controlKey:
            return "⌃"
        default:
            return key.label.uppercased()
        }
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
        case .stopPlayback:
            settingsModel.stopPlaybackShortcut = value
            settingsModel.stopPlaybackShortcutModifiersRawValue = isAssigned ? value.modifiers.rawValue : -1
        case .restartPlayback:
            settingsModel.restartPlaybackShortcut = value
            settingsModel.restartPlaybackShortcutModifiersRawValue = isAssigned ? value.modifiers.rawValue : -1
        case .increaseSpeed:
            settingsModel.increaseSpeedShortcut = value
            settingsModel.increaseSpeedShortcutModifiersRawValue = isAssigned ? value.modifiers.rawValue : -1
        case .decreaseSpeed:
            settingsModel.decreaseSpeedShortcut = value
            settingsModel.decreaseSpeedShortcutModifiersRawValue = isAssigned ? value.modifiers.rawValue : -1
        case .stepForward:
            settingsModel.stepForwardShortcut = value
            settingsModel.stepForwardShortcutModifiersRawValue = isAssigned ? value.modifiers.rawValue : -1
        case .stepBackward:
            settingsModel.stepBackwardShortcut = value
            settingsModel.stepBackwardShortcutModifiersRawValue = isAssigned ? value.modifiers.rawValue : -1
        }

        try? modelContext.save()
        appState.applySettings(settingsModel)
    }

    private func syncSettingsIntoAppState() {
        let settingsModel = currentSettingsModel()
        appState.applySettings(settingsModel)
    }
}

private struct SettingsRowDivider: ViewModifier {
    let showsDivider: Bool

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.horizontal, 18)
            }
        }
    }
}

private struct MinimalSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            let knobSize: CGFloat = 14
            let trackHeight: CGFloat = 4
            let availableWidth = max(geometry.size.width - knobSize, 1)
            let progress = normalizedValue
            let knobOffset = availableWidth * progress

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(trackColor)
                    .frame(height: trackHeight)

                Capsule(style: .continuous)
                    .fill(fillColor)
                    .frame(width: knobOffset + knobSize / 2, height: trackHeight)

                Circle()
                    .fill(knobColor)
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: isDragging ? 4 : 2, y: 1)
                    .offset(x: knobOffset)
            }
            .frame(height: max(knobSize, 20), alignment: .center)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        updateValue(locationX: gesture.location.x, width: geometry.size.width, knobSize: knobSize)
                    }
                    .onEnded { gesture in
                        updateValue(locationX: gesture.location.x, width: geometry.size.width, knobSize: knobSize)
                        isDragging = false
                    }
            )
        }
        .frame(height: 20)
    }

    private var normalizedValue: Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let distance = range.upperBound - range.lowerBound
        guard distance > 0 else { return 0 }
        return (clamped - range.lowerBound) / distance
    }

    private var trackColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.10)
    }

    private var fillColor: Color {
        isDragging || isHovering ? Color.accentColor.opacity(0.95) : Color.accentColor.opacity(0.8)
    }

    private var knobColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.96) : Color.white
    }

    private func updateValue(locationX: CGFloat, width: CGFloat, knobSize: CGFloat) {
        let usableWidth = max(width - knobSize, 1)
        let adjustedX = min(max(locationX - knobSize / 2, 0), usableWidth)
        let ratio = adjustedX / usableWidth
        let rawValue = range.lowerBound + Double(ratio) * (range.upperBound - range.lowerBound)
        let steppedValue = (rawValue / step).rounded() * step
        value = min(max(steppedValue, range.lowerBound), range.upperBound)
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
