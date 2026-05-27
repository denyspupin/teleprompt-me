import SwiftUI

struct TeleprompterOverlayView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(appState.activeScriptTitle, systemImage: "rectangle.topthird.inset.filled")
                    .font(.headline)
                Spacer()
                Text("Interactive when paused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(appState.activeScriptText)
                .font(.system(size: 30, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .lineSpacing(8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .padding(8)
    }
}
