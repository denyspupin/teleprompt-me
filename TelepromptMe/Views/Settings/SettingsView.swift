import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]

    private var currentSettings: AppSettings {
        settings.first ?? AppSettings()
    }

    var body: some View {
        Form {
            Section("Overlay") {
                Toggle("Show icon in Dock", isOn: binding(for: \.showDockIcon))
                Toggle("Show menu bar item", isOn: binding(for: \.showMenuBarItem))
                Toggle("Keep overlay centered below camera", isOn: binding(for: \.keepOverlayCentered))
                LabeledContent("Opacity") {
                    Text(currentSettings.overlayOpacity.formatted(.number.precision(.fractionLength(2))))
                }
            }

            Section("Typography") {
                TextField("Font name", text: binding(for: \.fontName))
                LabeledContent("Font size") {
                    Text(currentSettings.fontSize.formatted(.number.precision(.fractionLength(0))))
                }
                LabeledContent("Line spacing") {
                    Text(currentSettings.lineSpacing.formatted(.number.precision(.fractionLength(0))))
                }
            }

            Section("Playback") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Speed")
                        Spacer()
                        Text("\(Int(currentSettings.playbackSpeedWordsPerMinute)) WPM")
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: binding(
                            for: \.playbackSpeedWordsPerMinute,
                            fallback: 140
                        ) { newValue in
                            appState.playbackController.applySpeed(newValue)
                        },
                        in: 60...260,
                        step: 5
                    )

                    Text("Shortcuts: Cmd+Shift+P play/pause, Cmd+Shift+S stop, Cmd+Shift+Return restart, Cmd+Shift+= faster, Cmd+Shift+- slower.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 560)
        .onAppear {
            ensureSettings()
            appState.playbackController.applySpeed(currentSettings.playbackSpeedWordsPerMinute)
        }
    }

    private func ensureSettings() {
        guard settings.isEmpty else { return }
        let defaults = AppSettings()
        modelContext.insert(defaults)
        try? modelContext.save()
    }

    private func binding<Value>(
        for keyPath: ReferenceWritableKeyPath<AppSettings, Value>,
        fallback: Value? = nil,
        onSet: ((Value) -> Void)? = nil
    ) -> Binding<Value> {
        Binding(
            get: {
                if let settings = settings.first {
                    return settings[keyPath: keyPath]
                }
                guard let fallback else {
                    fatalError("Missing fallback for settings binding.")
                }
                return fallback
            },
            set: { newValue in
                let settingsModel = currentSettingsModel()
                settingsModel[keyPath: keyPath] = newValue
                onSet?(newValue)
                try? modelContext.save()
            }
        )
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
}
