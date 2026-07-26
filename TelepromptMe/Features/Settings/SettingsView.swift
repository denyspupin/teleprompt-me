import AppKit
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]

    @Binding var selectedSection: SettingsSection
    @State private var saveErrorMessage: String?
    @State private var editingShortcut: AppShortcutCommand?

    private let availableFonts = NSFontManager.shared.availableFontFamilies.sorted()

    private var currentSettings: AppSettings {
        settings.first ?? AppSettings()
    }

    var body: some View {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
        settingsCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Autoplay")
                    .font(.headline)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reading speed")
                        Text("Controls how quickly the active script advances.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Slider(
                        value: binding(for: \.playbackSpeedWordsPerMinute),
                        in: 60...260,
                        step: 5
                    )
                    .frame(width: 220)

                    Text("\(Int(currentSettings.playbackSpeedWordsPerMinute)) WPM")
                        .monospacedDigit()
                        .frame(width: 76, alignment: .trailing)
                }
            }
        }
    }

    private var appearanceContent: some View {
        VStack(spacing: 18) {
            settingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Typography")
                        .font(.headline)

                    LabeledContent("Font") {
                        Picker("Font", selection: binding(for: \.fontName)) {
                            ForEach(availableFonts, id: \.self) { font in
                                Text(font).tag(font)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 260)
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
                }
            }

            settingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Overlay")
                        .font(.headline)

                    sliderSetting(
                        title: "Opacity",
                        valueText: "\(Int(currentSettings.overlayOpacity * 100))%",
                        value: binding(for: \.overlayOpacity),
                        range: 0.45...1,
                        step: 0.05
                    )
                }
            }
        }
    }

    private var shortcutsContent: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("Global shortcuts")
                    .font(.headline)
                    .padding(.bottom, 6)

                Text("These shortcuts work while TelepromptMe is running, even when another app is active.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 10)

                ForEach(AppShortcutCommand.versionOneCommands) { command in
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
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
                    .padding(.vertical, 12)

                    if command != AppShortcutCommand.versionOneCommands.last {
                        Divider()
                    }
                }
            }
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
            HStack {
                Slider(value: value, in: range, step: step)
                    .frame(width: 220)
                Text(valueText)
                    .monospacedDigit()
                    .frame(width: 58, alignment: .trailing)
            }
        }
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.white.opacity(0.08))
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

    private var sectionDescription: String {
        switch selectedSection {
        case .general:
            return "Set a comfortable, predictable autoplay speed."
        case .appearance:
            return "Adjust the text and overlay for your reading environment."
        case .shortcuts:
            return "Choose the global keys for the three essential teleprompter actions."
        }
    }
}
