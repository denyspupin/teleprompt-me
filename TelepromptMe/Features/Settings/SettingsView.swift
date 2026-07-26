import AppKit
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]

    @Binding var selectedSection: SettingsSection
    @State private var saveErrorMessage: String?

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
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            appState.applySettings(currentSettings)
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

    private var sectionDescription: String {
        switch selectedSection {
        case .general:
            return "Set a comfortable, predictable autoplay speed."
        case .appearance:
            return "Adjust the text and overlay for your reading environment."
        }
    }
}
