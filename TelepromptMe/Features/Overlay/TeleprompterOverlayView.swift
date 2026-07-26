import SwiftUI

private struct OverlayTextHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct TeleprompterOverlayView: View {
    private enum Layout {
        static let visibleLineCount: CGFloat = 3
        static let controlHeight: CGFloat = 36
        static let titleSpacing: CGFloat = 8
        static let horizontalPadding: CGFloat = 24
        static let verticalPadding: CGFloat = 18
    }

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(appState.activeScriptTitle)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)

                    HStack(spacing: Layout.titleSpacing) {
                        Label(speedLabel, systemImage: "speedometer")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !speechStatusLabel.isEmpty {
                            Label(speechStatusLabel, systemImage: speechStatusImage)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(speechStatusColor)
                                .lineLimit(1)
                                .help(speechStatusLabel)
                        }
                    }
                }

                Spacer()
                controlBar
            }

            teleprompterTextViewport
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            .regularMaterial.opacity(appState.settingsSnapshot.overlayOpacity),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .padding(8)
        .onChange(of: appState.activeScriptID) { _, _ in
            appState.playbackController.stop()
        }
        .onPreferenceChange(OverlayTextHeightPreferenceKey.self) { textHeight in
            appState.playbackController.updateScrollableMetrics(
                contentHeight: textHeight,
                viewportHeight: viewportHeight
            )
        }
    }

    private var teleprompterTextViewport: some View {
        textContent
            .offset(y: -appState.playbackController.currentOffset)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: viewportHeight, alignment: .top)
            .clipped()
            .allowsHitTesting(false)
    }

    private var controlBar: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    appState.togglePlayback()
                } label: {
                    Label(
                        appState.playbackController.state == .playing ? "Pause" : "Play",
                        systemImage: appState.playbackController.state == .playing ? "pause.fill" : "play.fill"
                    )
                    .labelStyle(.iconOnly)
                    .frame(width: 28, height: 28)
                }
                .buttonStyle(.glassProminent)
                .help(appState.playbackController.state == .playing ? "Pause" : "Play")

                controlButton(systemImage: "arrow.counterclockwise", label: "Restart From Top") {
                    appState.restartPlayback()
                }

                controlButton(
                    systemImage: appState.speechFollowController.isListening
                        ? "waveform.circle.fill"
                        : "waveform.circle",
                    label: appState.speechFollowController.isListening
                        ? "Stop Voice Follow"
                        : "Start Voice Follow"
                ) {
                    appState.toggleVoiceFollow()
                }
                .tint(appState.speechFollowController.isListening ? .accentColor : nil)

                controlButton(systemImage: "eye.slash.fill", label: "Hide") {
                    appState.hideOverlay()
                }
            }
        }
        .frame(height: Layout.controlHeight)
    }

    private func controlButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.glass)
        .help(label)
        .accessibilityLabel(label)
    }

    private var speedLabel: String {
        "\(Int(appState.playbackController.speedWordsPerMinute)) WPM"
    }

    private var speechStatusLabel: String {
        switch appState.speechFollowController.state {
        case .idle:
            return ""
        case .listening:
            return "Listening"
        case .matching:
            return "Following"
        case .lost:
            return "Finding place"
        case .failed(let message):
            return message
        }
    }

    private var speechStatusColor: Color {
        switch appState.speechFollowController.state {
        case .failed:
            return .red
        case .lost:
            return .orange
        default:
            return .secondary
        }
    }

    private var speechStatusImage: String {
        switch appState.speechFollowController.state {
        case .idle:
            return "waveform"
        case .listening:
            return "mic.fill"
        case .matching:
            return "waveform.badge.checkmark"
        case .lost:
            return "questionmark.circle"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var textContent: some View {
        Text(appState.activeScriptText)
            .font(appState.settingsSnapshot.resolvedFont)
            .foregroundStyle(.primary)
            .lineSpacing(appState.settingsSnapshot.lineSpacing)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: OverlayTextHeightPreferenceKey.self,
                        value: geometry.size.height
                    )
                }
            }
    }

    private var viewportHeight: CGFloat {
        let fontSize = CGFloat(appState.settingsSnapshot.fontSize)
        let lineSpacing = CGFloat(appState.settingsSnapshot.lineSpacing)
        return (fontSize * Layout.visibleLineCount) + (lineSpacing * (Layout.visibleLineCount - 1)) + 10
    }
}
