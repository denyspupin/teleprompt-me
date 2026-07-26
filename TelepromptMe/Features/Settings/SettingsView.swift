import AppKit
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]

    let section: SettingsSection
    @State private var saveErrorMessage: String?
    @State private var editingShortcut: AppShortcutCommand?

    private let availableFonts = NSFontManager.shared.availableFontFamilies.sorted()

    private var currentSettings: AppSettings {
        settings.first ?? AppSettings()
    }

    private var speechLocales: [Locale] {
        let defaults = ["en_US", "en_GB", "de_DE", "es_ES", "fr_FR"]
        let identifiers = defaults.contains(currentSettings.selectedSpeechLocaleIdentifier)
            ? defaults
            : [currentSettings.selectedSpeechLocaleIdentifier] + defaults
        return identifiers.map(Locale.init(identifier:))
    }

    var body: some View {
        Form {
            switch section {
            case .general:
                generalContent
            case .appearance:
                appearanceContent
            case .shortcuts:
                shortcutsContent
            }
        }
        .formStyle(.grouped)
        .onAppear {
            appState.applySettings(currentSettings)
        }
        .sheet(item: $editingShortcut) { command in
            ShortcutEditorSheet(
                command: command,
                shortcut: shortcut(for: command),
                isAssigned: isShortcutAssigned(command),
                onSave: { updateShortcut(command, value: $0) },
                onClear: { clearShortcut(command) }
            )
        }
        .alert(
            "Settings Could Not Be Saved",
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "Please try again.")
        }
    }

    private var generalContent: some View {
        Group {
            Section {
                sliderSetting(
                    title: "Reading speed",
                    valueText: "\(Int(currentSettings.playbackSpeedWordsPerMinute)) WPM",
                    value: binding(for: \.playbackSpeedWordsPerMinute),
                    range: 60...260,
                    step: 5
                )
            } header: {
                Text("Autoplay")
            } footer: {
                Text("Controls how quickly the active script advances.")
            }

            Section {
                Picker(
                    "Language",
                    selection: binding(for: \.selectedSpeechLocaleIdentifier)
                ) {
                    ForEach(speechLocales, id: \.identifier) { locale in
                        Text(
                            Locale.current.localizedString(forIdentifier: locale.identifier)
                                ?? locale.identifier
                        )
                        .tag(locale.identifier)
                    }
                }

                Toggle(
                    "Start voice follow when the overlay opens",
                    isOn: binding(for: \.isVoiceFollowEnabledByDefault)
                )

                sliderSetting(
                    title: "Matching sensitivity",
                    valueText: currentSettings.speechFollowSensitivity.formatted(
                        .number.precision(.fractionLength(2))
                    ),
                    value: binding(for: \.speechFollowSensitivity),
                    range: 0.45...0.9,
                    step: 0.01
                )
            } header: {
                Text("Voice Follow")
            } footer: {
                Label(
                    "Voice Follow uses Apple’s on-device speech recognition. Audio isn’t sent to a third party.",
                    systemImage: "hand.raised.fill"
                )
                .foregroundStyle(.secondary)
            }
        }
    }

    private var appearanceContent: some View {
        Group {
            Section {
                Picker("Font", selection: binding(for: \.fontName)) {
                    ForEach(availableFonts, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }

                sliderSetting(
                    title: "Font size",
                    valueText: "\(Int(currentSettings.fontSize)) pt",
                    value: binding(for: \.fontSize),
                    range: 20...96,
                    step: 2
                )

                sliderSetting(
                    title: "Line spacing",
                    valueText: "\(Int(currentSettings.lineSpacing)) pt",
                    value: binding(for: \.lineSpacing),
                    range: 0...32,
                    step: 1
                )
            } header: {
                Text("Typography")
            }

            Section {
                sliderSetting(
                    title: "Opacity",
                    valueText: "\(Int(currentSettings.overlayOpacity * 100))%",
                    value: binding(for: \.overlayOpacity),
                    range: 0.45...1,
                    step: 0.05
                )
            } header: {
                Text("Overlay")
            } footer: {
                Text("Choose a comfortable text style and overlay contrast for your reading environment.")
            }
        }
    }

    private var shortcutsContent: some View {
        Section {
            ForEach(AppShortcutCommand.versionOneCommands) { command in
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(command.title)
                        Text(command.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isShortcutAssigned(command) {
                        ShortcutBadge(shortcut: shortcut(for: command))
                    } else {
                        Text("Not assigned")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button("Edit") {
                        editingShortcut = command
                    }
                    .accessibilityLabel("Edit \(command.title) shortcut")
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Global Shortcuts")
        } footer: {
            Text("These shortcuts work while TelepromptMe is running, even when another app is active.")
        }
    }

    private func sliderSetting(
        title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        LabeledContent(title) {
            HStack(spacing: 12) {
                Slider(value: value, in: range, step: step)
                    .frame(minWidth: 180, idealWidth: 220)
                Text(valueText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 72, alignment: .trailing)
            }
        }
    }

    private func binding<Value>(
        for keyPath: ReferenceWritableKeyPath<AppSettings, Value>
    ) -> Binding<Value> {
        Binding(
            get: { currentSettings[keyPath: keyPath] },
            set: { newValue in
                currentSettings[keyPath: keyPath] = newValue
                saveSettings()
            }
        )
    }

    private func saveSettings() {
        do {
            try modelContext.save()
            appState.applySettings(currentSettings)
        } catch {
            modelContext.rollback()
            saveErrorMessage = error.localizedDescription
        }
    }

    private func shortcut(for command: AppShortcutCommand) -> AppShortcut {
        switch command {
        case .toggleOverlay:
            return currentSettings.toggleOverlayShortcut
        case .togglePlayback:
            return currentSettings.togglePlaybackShortcut
        case .restartPlayback:
            return currentSettings.restartPlaybackShortcut
        default:
            return command.defaultShortcut
        }
    }

    private func isShortcutAssigned(_ command: AppShortcutCommand) -> Bool {
        switch command {
        case .toggleOverlay:
            return currentSettings.isToggleOverlayShortcutAssigned
        case .togglePlayback:
            return currentSettings.isTogglePlaybackShortcutAssigned
        case .restartPlayback:
            return currentSettings.isRestartPlaybackShortcutAssigned
        default:
            return false
        }
    }

    private func updateShortcut(_ command: AppShortcutCommand, value: AppShortcut) {
        let duplicate = AppShortcutCommand.versionOneCommands.first { otherCommand in
            otherCommand != command
                && isShortcutAssigned(otherCommand)
                && shortcut(for: otherCommand) == value
        }
        guard duplicate == nil else {
            saveErrorMessage = "That shortcut is already assigned to \(duplicate?.title ?? "another action")."
            return
        }

        switch command {
        case .toggleOverlay:
            currentSettings.toggleOverlayShortcut = value
        case .togglePlayback:
            currentSettings.togglePlaybackShortcut = value
        case .restartPlayback:
            currentSettings.restartPlaybackShortcut = value
        default:
            return
        }
        saveSettings()
    }

    private func clearShortcut(_ command: AppShortcutCommand) {
        switch command {
        case .toggleOverlay:
            currentSettings.toggleOverlayShortcutModifiersRawValue = -1
        case .togglePlayback:
            currentSettings.togglePlaybackShortcutModifiersRawValue = -1
        case .restartPlayback:
            currentSettings.restartPlaybackShortcutModifiersRawValue = -1
        default:
            return
        }
        saveSettings()
    }
}
