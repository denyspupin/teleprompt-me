import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var settings: [AppSettings]

    private var currentSettings: AppSettings {
        settings.first ?? AppSettings()
    }

    var body: some View {
        Form {
            Section("Overlay") {
                Toggle("Show icon in Dock", isOn: .constant(currentSettings.showDockIcon))
                Toggle("Show menu bar item", isOn: .constant(currentSettings.showMenuBarItem))
                Toggle("Keep overlay centered below camera", isOn: .constant(currentSettings.keepOverlayCentered))
                LabeledContent("Opacity") {
                    Text(currentSettings.overlayOpacity.formatted(.number.precision(.fractionLength(2))))
                }
            }

            Section("Typography") {
                TextField("Font name", text: .constant(currentSettings.fontName))
                LabeledContent("Font size") {
                    Text(currentSettings.fontSize.formatted(.number.precision(.fractionLength(0))))
                }
                LabeledContent("Line spacing") {
                    Text(currentSettings.lineSpacing.formatted(.number.precision(.fractionLength(0))))
                }
            }

            Section("Playback") {
                Text("Global shortcuts, speed control, and paragraph stepping will be wired into this settings area in the next implementation phase.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 560)
    }
}
