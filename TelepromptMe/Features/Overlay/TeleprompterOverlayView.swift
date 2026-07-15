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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: Layout.titleSpacing) {
                    Label(appState.activeScriptTitle, systemImage: "text.document")
                        .font(.headline)
                        .lineLimit(1)

                    Text(speedLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(speechStatusLabel)
                        .font(.caption)
                        .foregroundStyle(speechStatusColor)
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
            .ultraThinMaterial.opacity(appState.settingsSnapshot.overlayOpacity),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
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
        HStack(spacing: 8) {
            controlButton(
                systemImage: appState.playbackController.state == .playing ? "pause.fill" : "play.fill",
                label: appState.playbackController.state == .playing ? "Pause" : "Play"
            ) {
                appState.togglePlayback()
            }

            controlButton(systemImage: "backward.end.fill", label: "Start Over") {
                appState.restartPlayback()
            }

            controlButton(
                systemImage: appState.speechFollowController.isListening ? "waveform.circle.fill" : "waveform.circle",
                label: appState.speechFollowController.isListening ? "Stop Voice Follow" : "Follow Voice"
            ) {
                appState.toggleVoiceFollow()
            }

            controlButton(systemImage: "eye.slash.fill", label: "Hide") {
                appState.hideOverlay()
            }
        }
        .frame(height: Layout.controlHeight)
    }

    private func controlButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(label)
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
