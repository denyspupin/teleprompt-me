import SwiftUI

struct SettingsRowDivider: ViewModifier {
    let showsDivider: Bool

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.horizontal, 18)
            }
        }
    }
}

struct MinimalSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            let knobSize: CGFloat = 14
            let trackHeight: CGFloat = 4
            let availableWidth = max(geometry.size.width - knobSize, 1)
            let progress = normalizedValue
            let knobOffset = availableWidth * progress

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(trackColor)
                    .frame(height: trackHeight)

                Capsule(style: .continuous)
                    .fill(fillColor)
                    .frame(width: knobOffset + knobSize / 2, height: trackHeight)

                Circle()
                    .fill(knobColor)
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: isDragging ? 4 : 2, y: 1)
                    .offset(x: knobOffset)
            }
            .frame(height: max(knobSize, 20), alignment: .center)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        updateValue(locationX: gesture.location.x, width: geometry.size.width, knobSize: knobSize)
                    }
                    .onEnded { gesture in
                        updateValue(locationX: gesture.location.x, width: geometry.size.width, knobSize: knobSize)
                        isDragging = false
                    }
            )
        }
        .frame(height: 20)
    }

    private var normalizedValue: Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let distance = range.upperBound - range.lowerBound
        guard distance > 0 else { return 0 }
        return (clamped - range.lowerBound) / distance
    }

    private var trackColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.10)
    }

    private var fillColor: Color {
        isDragging || isHovering ? Color.accentColor.opacity(0.95) : Color.accentColor.opacity(0.8)
    }

    private var knobColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.96) : Color.white
    }

    private func updateValue(locationX: CGFloat, width: CGFloat, knobSize: CGFloat) {
        let usableWidth = max(width - knobSize, 1)
        let adjustedX = min(max(locationX - knobSize / 2, 0), usableWidth)
        let ratio = adjustedX / usableWidth
        let rawValue = range.lowerBound + Double(ratio) * (range.upperBound - range.lowerBound)
        let steppedValue = (rawValue / step).rounded() * step
        value = min(max(steppedValue, range.lowerBound), range.upperBound)
    }
}
