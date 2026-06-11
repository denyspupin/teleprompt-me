import AppKit
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]

    @Binding var selectedSection: SettingsSection
    @State private var editingShortcut: AppShortcutCommand?
    @State private var modelImportError: String?

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
                        ForEach(readySpeechModels) { model in
                            Text(model.title).tag(model.id)
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
                    rowContainer {
                        settingsTextColumn(
                            title: "Import Whisper Model",
                            subtitle: "Add a local whisper.cpp .bin model file."
                        )

                        Spacer(minLength: 24)

                        Button("Import") {
                            importCustomSpeechModel()
                        }
                        .controlSize(.regular)
                    }

                    if let modelImportError {
                        rowContainer(showsDivider: true) {
                            Text(modelImportError)
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    ForEach(Array(availableSpeechModels.enumerated()), id: \.element.id) { index, model in
                        modelRow(
                            model: model,
                            showsDivider: index < availableSpeechModels.count - 1
                        )
                    }
                }
            }
        }
    }

    private var availableSpeechModels: [SpeechModelDescriptor] {
        appState.speechModelDownloadManager.availableModels
    }

    private var readySpeechModels: [SpeechModelDescriptor] {
        availableSpeechModels.filter { model in
            appState.speechModelDownloadManager.isUsable(model)
        }
    }

    private var selectedSpeechModel: SpeechModelDescriptor {
        appState.speechModelDownloadManager.descriptor(for: selectedSpeechModelID) ??
            SpeechModelCatalog.builtInDescriptors[0]
    }

    private var selectedSpeechModelID: String {
        appState.speechModelDownloadManager.isUsable(currentSettings.selectedSpeechEngineID)
            ? currentSettings.selectedSpeechEngineID
            : SpeechModelCatalog.builtInAppleSpeechID
    }

    private var speechLocaleOptions: [Locale] {
        let defaults = [
            Locale(identifier: "en_US"),
            Locale(identifier: "en_GB"),
            Locale(identifier: "de_DE"),
            Locale(identifier: "es_ES"),
            Locale(identifier: "fr_FR"),
        ]

        let supportedIdentifiers = selectedSpeechModel.supportedLanguageIdentifiers
        let supportedDefaults = supportedIdentifiers.isEmpty
            ? defaults
            : defaults.filter { supportedIdentifiers.contains($0.identifier) }
        let baseOptions = supportedDefaults.isEmpty
            ? supportedIdentifiers.map(Locale.init(identifier:))
            : supportedDefaults

        guard !baseOptions.map(\.identifier).contains(currentSettings.selectedSpeechLocaleIdentifier) else {
            return baseOptions
        }

        return [Locale(identifier: currentSettings.selectedSpeechLocaleIdentifier)] + baseOptions
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
        model: SpeechModelDescriptor,
        showsDivider: Bool = true
    ) -> some View {
        let state = appState.speechModelDownloadManager.state(for: model)

        rowContainer(alignment: .top, showsDivider: showsDivider) {
            VStack(alignment: .leading, spacing: 8) {
                settingsTextColumn(title: model.title, subtitle: modelSubtitle(for: model))

                modelMetadataBadges(for: model, state: state)

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
        for model: SpeechModelDescriptor,
        state: SpeechModelDownloadManager.DownloadState
    ) -> some View {
        switch state {
        case .downloaded:
            HStack(spacing: 10) {
                Text(modelStatusText(for: model))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(appState.speechModelDownloadManager.isUsable(model) ? .green : .orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        (appState.speechModelDownloadManager.isUsable(model) ? Color.green : Color.orange)
                            .opacity(0.12),
                        in: Capsule(style: .continuous)
                    )

                if selectedSpeechModelID == model.id && appState.speechModelDownloadManager.isUsable(model) {
                    Text("In use")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Button("Use") {
                        selectSpeechEngine(model)
                    }
                    .controlSize(.regular)
                    .disabled(!appState.speechModelDownloadManager.isUsable(model))
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

    @ViewBuilder
    private func modelMetadataBadges(
        for model: SpeechModelDescriptor,
        state: SpeechModelDownloadManager.DownloadState
    ) -> some View {
        FlowLayout(spacing: 6) {
            if model.isRecommended {
                modelBadge("Recommended")
            }

            if model.isCustom {
                modelBadge("Custom")
            }

            if !model.auxiliaryModelFileNames.isEmpty {
                modelBadge("Core ML")
            }

            if let estimatedDownloadSize = model.estimatedDownloadSize {
                modelBadge(estimatedDownloadSize)
            }

            modelBadge(languageSupportText(for: model))

            if state == .downloaded,
               !appState.speechModelDownloadManager.isUsable(model) {
                modelBadge("Incompatible", tint: .orange)
            }
        }
    }

    private func modelBadge(_ text: String, tint: Color = .secondary) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.10), in: Capsule(style: .continuous))
    }

    private func modelSubtitle(for model: SpeechModelDescriptor) -> String {
        if !model.isBuiltIn,
           appState.speechModelDownloadManager.state(for: model) == .downloaded,
           !appState.speechModelDownloadManager.isUsable(model) {
            return "\(model.subtitle) Downloaded files must include the expected whisper.cpp model file."
        }

        return model.subtitle
    }

    private func languageSupportText(for model: SpeechModelDescriptor) -> String {
        guard !model.supportedLanguageIdentifiers.isEmpty else {
            return "All configured languages"
        }

        let languageNames = model.supportedLanguageIdentifiers
            .prefix(3)
            .map { languageDisplayName(for: $0) }
        let remainingCount = model.supportedLanguageIdentifiers.count - languageNames.count

        if remainingCount > 0 {
            return "\(languageNames.joined(separator: ", ")) +\(remainingCount)"
        }

        return languageNames.joined(separator: ", ")
    }

    private func languageDisplayName(for identifier: String) -> String {
        let locale = Locale(identifier: identifier)
        return Locale.current.localizedString(forIdentifier: locale.identifier) ?? identifier
    }

    private func modelStatusText(for model: SpeechModelDescriptor) -> String {
        if model.isBuiltIn {
            return "Built in"
        }

        if model.isCustom {
            return "Imported"
        }

        return appState.speechModelDownloadManager.isUsable(model) ? "Downloaded" : "Incompatible"
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
                selectedSpeechModelID
            },
            set: { newValue in
                guard appState.speechModelDownloadManager.isUsable(newValue) else { return }
                let settingsModel = currentSettingsModel()
                settingsModel.selectedSpeechEngineID = newValue
                resetUnsupportedSpeechLocaleIfNeeded(for: settingsModel)
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

    private func selectSpeechEngine(_ model: SpeechModelDescriptor) {
        guard appState.speechModelDownloadManager.isUsable(model) else { return }
        let settingsModel = currentSettingsModel()
        settingsModel.selectedSpeechEngineID = model.id
        resetUnsupportedSpeechLocaleIfNeeded(for: settingsModel)
        try? modelContext.save()
        appState.applySettings(settingsModel)
    }

    private func deleteSpeechModel(_ model: SpeechModelDescriptor) {
        let wasSelectedModel = currentSettings.selectedSpeechEngineID == model.id ||
            selectedSpeechModelID == model.id
        appState.speechModelDownloadManager.delete(model)

        if wasSelectedModel,
           let appleBuiltIn = appState.speechModelDownloadManager.availableModels.first(where: \.isBuiltIn) {
            selectSpeechEngine(appleBuiltIn)
        }
    }

    private func importCustomSpeechModel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.data]
        panel.nameFieldLabel = "Whisper model:"
        panel.prompt = "Import"

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        do {
            let descriptor = try appState.speechModelDownloadManager.importCustomModel(from: selectedURL)
            modelImportError = nil
            selectSpeechEngine(descriptor)
        } catch {
            modelImportError = error.localizedDescription
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
        if !appState.speechModelDownloadManager.isReady(settingsModel.selectedSpeechEngineID) {
            settingsModel.selectedSpeechEngineID = SpeechRecognitionEngineID.appleBuiltIn.rawValue
            try? modelContext.save()
        }
        resetUnsupportedSpeechLocaleIfNeeded(for: settingsModel)
        appState.applySettings(settingsModel)
    }

    private func resetUnsupportedSpeechLocaleIfNeeded(for settingsModel: AppSettings) {
        let descriptor = appState.speechModelDownloadManager.descriptor(for: settingsModel.selectedSpeechEngineID) ??
            SpeechModelCatalog.builtInDescriptors[0]
        let supportedIdentifiers = descriptor.supportedLanguageIdentifiers

        guard !supportedIdentifiers.isEmpty,
              !supportedIdentifiers.contains(settingsModel.selectedSpeechLocaleIdentifier) else {
            return
        }

        if supportedIdentifiers.contains("en_US") {
            settingsModel.selectedSpeechLocaleIdentifier = "en_US"
        } else {
            settingsModel.selectedSpeechLocaleIdentifier = supportedIdentifiers[0]
        }
        try? modelContext.save()
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let rows = rows(for: subviews, maxWidth: proposal.width ?? .infinity)
        return CGSize(
            width: rows.map(\.width).max() ?? 0,
            height: rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = rows(for: subviews, maxWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                item.subview.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [FlowRow] {
        var rows: [FlowRow] = []
        var currentItems: [FlowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width

            if nextWidth > maxWidth, !currentItems.isEmpty {
                rows.append(FlowRow(items: currentItems, width: currentWidth, height: currentHeight))
                currentItems = []
                currentWidth = 0
                currentHeight = 0
            }

            currentItems.append(FlowItem(subview: subview, size: size))
            currentWidth = currentItems.count == 1 ? size.width : currentWidth + spacing + size.width
            currentHeight = max(currentHeight, size.height)
        }

        if !currentItems.isEmpty {
            rows.append(FlowRow(items: currentItems, width: currentWidth, height: currentHeight))
        }

        return rows
    }
}

private struct FlowRow {
    var items: [FlowItem]
    var width: CGFloat
    var height: CGFloat
}

private struct FlowItem {
    var subview: LayoutSubview
    var size: CGSize
}
