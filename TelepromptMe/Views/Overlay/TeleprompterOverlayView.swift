import SwiftUI

struct TeleprompterOverlayView: View {
    private enum Layout {
        static let fontSize: CGFloat = 30
        static let lineSpacing: CGFloat = 8
        static let visibleLineCount: CGFloat = 3
        static let controlHeight: CGFloat = 36
    }

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Label(appState.activeScriptTitle, systemImage: "rectangle.topthird.inset.filled")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                controlBar
            }

            teleprompterTextViewport
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .padding(8)
        .onChange(of: appState.activeScriptID) { _, _ in
            appState.playbackController.stop()
        }
    }

    private var teleprompterTextViewport: some View {
        textContent
            .offset(y: -appState.playbackController.currentOffset)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: viewportHeight, alignment: .top)
            .clipped()
    }

    private var controlBar: some View {
        HStack(spacing: 8) {
            controlButton(
                systemImage: appState.playbackController.state == .playing ? "pause.fill" : "play.fill",
                label: appState.playbackController.state == .playing ? "Pause" : "Play"
            ) {
                appState.togglePlayback()
            }

            controlButton(systemImage: "stop.fill", label: "Stop") {
                appState.stop()
            }

            controlButton(systemImage: "backward.end.fill", label: "Start Over") {
                appState.restartPlayback()
            }

            controlButton(systemImage: "minus", label: "Slower") {
                appState.playbackController.decreaseSpeed()
            }

            Text("\(Int(appState.playbackController.speedWordsPerMinute))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 36)

            controlButton(systemImage: "plus", label: "Faster") {
                appState.playbackController.increaseSpeed()
            }

            controlButton(systemImage: "xmark", label: "Hide") {
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

    private var textContent: some View {
        Text(appState.activeScriptText)
            .font(.system(size: Layout.fontSize, weight: .medium, design: .rounded))
            .foregroundStyle(.primary)
            .lineSpacing(Layout.lineSpacing)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var viewportHeight: CGFloat {
        (Layout.fontSize * Layout.visibleLineCount) + (Layout.lineSpacing * (Layout.visibleLineCount - 1)) + 10
    }
}
