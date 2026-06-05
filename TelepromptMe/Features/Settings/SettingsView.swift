import AppKit
import SwiftData
import SwiftUI

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
                case .aiModels:
                    aiModelsContent
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

    private var aiModelsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsSection(title: "Speech Recognition") {
                settingsCard {
                    pickerRow(
                        title: "Recognition engine",
                        subtitle: "Choose the local model used to follow your spoken script.",
                        selection: speechEngineSelectionBinding
                    ) {
                        ForEach(readySpeechEngines) { engine in
                            Text(engine.title).tag(engine.rawValue)
                        }
                    }

                    pickerRow(
                        title: "Language",
                        subtitle: "Pick the language the built-in recognizer should listen for.",
                        selection: binding(for: \.selectedSpeechLocaleIdentifier)
                    ) {
                        ForEach(speechLocaleOptions, id: \.identifier) { locale in
                            Text(locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier)
                                .tag(locale.identifier)
                        }
                    }

                    toggleRow(
                        title: "Start voice follow with overlay",
                        subtitle: "Begin listening automatically whenever the teleprompter overlay opens.",
                        isOn: binding(for: \.isVoiceFollowEnabledByDefault)
                    )

                    sliderRow(
                        title: "Matching sensitivity",
                        subtitle: "Higher values require closer matches before the script advances.",
                        valueText: currentSettings.speechFollowSensitivity.formatted(.number.precision(.fractionLength(2))),
                        value: binding(for: \.speechFollowSensitivity),
                        range: 0.45...0.9,
                        step: 0.01,
                        showsDivider: false
                    )
                }
            }

            settingsSection(title: "Available Models") {
                settingsCard {
                    ForEach(Array(SpeechRecognitionEngineID.allCases.enumerated()), id: \.element) { index, model in
                        modelRow(
                            model: model,
                            showsDivider: index < SpeechRecognitionEngineID.allCases.count - 1
                        )
                    }
                }
            }
        }
    }

    private var readySpeechEngines: [SpeechRecognitionEngineID] {
        SpeechRecognitionEngineID.allCases.filter { model in
            appState.speechModelDownloadManager.state(for: model) == .downloaded
        }
    }

    private var speechLocaleOptions: [Locale] {
        let defaults = [
            Locale(identifier: "en_US"),
            Locale(identifier: "en_GB"),
            Locale(identifier: "de_DE"),
            Locale(identifier: "es_ES"),
            Locale(identifier: "fr_FR"),
        ]

        guard !defaults.map(\.identifier).contains(currentSettings.selectedSpeechLocaleIdentifier) else {
            return defaults
        }

        return [Locale(identifier: currentSettings.selectedSpeechLocaleIdentifier)] + defaults
    }

    private var supportedSpeechLocaleIdentifiers: Set<String> {
        Set(speechLocaleOptions.map(\.identifier))
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

    @ViewBuilder
    private func modelRow(
        model: SpeechRecognitionEngineID,
        showsDivider: Bool = true
    ) -> some View {
        let state = appState.speechModelDownloadManager.state(for: model)

        rowContainer(alignment: .top, showsDivider: showsDivider) {
            VStack(alignment: .leading, spacing: 8) {
                settingsTextColumn(title: model.title, subtitle: modelSubtitle(for: model))

                if case .failed(let message) = state {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 24)

            modelControl(for: model, state: state)
                .frame(width: settingsControlColumnWidth, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func modelControl(
        for model: SpeechRecognitionEngineID,
        state: SpeechModelDownloadManager.DownloadState
    ) -> some View {
        switch state {
        case .downloaded:
            HStack(spacing: 10) {
                Text(model.isBuiltIn ? "Built in" : "Downloaded")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.12), in: Capsule(style: .continuous))

                if currentSettings.resolvedSpeechEngineID == model {
                    Text("In use")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Button("Use") {
                        selectSpeechEngine(model)
                    }
                    .controlSize(.regular)
                }

                if !model.isBuiltIn {
                    Button {
                        deleteSpeechModel(model)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Delete model")
                }
            }
        case .downloading(let progress):
            VStack(alignment: .trailing, spacing: 8) {
                ProgressView(value: progress)
                    .frame(width: settingsControlColumnWidth)

                Button("Cancel") {
                    appState.speechModelDownloadManager.cancelDownload(for: model)
                }
                .controlSize(.small)
            }
        case .notDownloaded, .failed:
            Button("Download") {
                appState.speechModelDownloadManager.download(model)
            }
            .controlSize(.regular)
            .disabled(model.isBuiltIn)
        }
    }

    private func modelSubtitle(for model: SpeechRecognitionEngineID) -> String {
        if let estimatedDownloadSize = model.estimatedDownloadSize {
            return "\(model.subtitle) Estimated download: \(estimatedDownloadSize)."
        }

        return model.subtitle
    }

    private var sectionDescription: String {
        switch selectedSection {
        case .general:
            return "Core app behavior and overlay defaults."
        case .aiModels:
            return "Manage local transcription models and voice-follow behavior."
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

    private var speechEngineSelectionBinding: Binding<String> {
        Binding(
            get: {
                currentSettings.resolvedSpeechEngineID.rawValue
            },
            set: { newValue in
                guard appState.speechModelDownloadManager.isReady(newValue) else { return }
                let settingsModel = currentSettingsModel()
                settingsModel.selectedSpeechEngineID = newValue
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

    private func selectSpeechEngine(_ model: SpeechRecognitionEngineID) {
        guard appState.speechModelDownloadManager.state(for: model) == .downloaded else { return }
        let settingsModel = currentSettingsModel()
        settingsModel.selectedSpeechEngineID = model.rawValue
        try? modelContext.save()
        appState.applySettings(settingsModel)
    }

    private func deleteSpeechModel(_ model: SpeechRecognitionEngineID) {
        appState.speechModelDownloadManager.delete(model)

        if currentSettings.resolvedSpeechEngineID == model {
            selectSpeechEngine(.appleBuiltIn)
        }
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
        if !supportedSpeechLocaleIdentifiers.contains(settingsModel.selectedSpeechLocaleIdentifier) {
            settingsModel.selectedSpeechLocaleIdentifier = "en_US"
            try? modelContext.save()
        }
        if !appState.speechModelDownloadManager.isReady(settingsModel.selectedSpeechEngineID) {
            settingsModel.selectedSpeechEngineID = SpeechRecognitionEngineID.appleBuiltIn.rawValue
            try? modelContext.save()
        }
        appState.applySettings(settingsModel)
    }
}
