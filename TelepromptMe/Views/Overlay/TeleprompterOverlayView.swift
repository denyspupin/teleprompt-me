import SwiftUI

struct TeleprompterOverlayView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Overlay Preview", systemImage: "rectangle.topthird.inset.filled")
                    .font(.headline)
                Spacer()
                Text("Interactive when paused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("This is the native overlay shell for TelepromptMe. In the next phase it will render the active script with live typography, auto-scroll, and manual stepping.")
                .font(.system(size: 30, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .lineSpacing(8)
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
