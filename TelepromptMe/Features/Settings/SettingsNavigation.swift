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

struct SettingsWindowView: View {
    @AppStorage("settings.selectedSection") private var selectedSection: SettingsSection = .general

    var body: some View {
        TabView(selection: $selectedSection) {
            ForEach(SettingsSection.allCases) { section in
                SettingsView(section: section)
                    .tabItem {
                        Label(section.title, systemImage: section.icon)
                    }
                    .tag(section)
            }
        }
        .scenePadding()
        .frame(minWidth: 560, idealWidth: 620, minHeight: 430, idealHeight: 500)
    }
}
