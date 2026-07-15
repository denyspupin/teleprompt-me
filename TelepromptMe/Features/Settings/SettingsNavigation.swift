import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case aiModels
    case appearance
    case shortcuts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "General"
        case .aiModels:
            return "AI Models"
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
        case .aiModels:
            return "waveform.and.magnifyingglass"
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
