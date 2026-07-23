import SwiftUI
import AppKit

/// A tactile circular drag-to-set control used for every duration/tunable
/// in the General tab, instead of a plain stepper/text field. Drag radius
/// controls sensitivity: near the center moves in big, coarse jumps (fast
/// scrubbing across a wide range); out toward the rim moves in small, fine
/// increments (precise adjustment) — like an inner/outer jog-wheel.
struct RotaryDurationDial: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String
    let helpText: String

    @State private var showHelp = false
    @State private var dragStartValue: Double?
    @State private var dragStartAngle: Double?
    @State private var lastSnappedValue: Int?

    private let diameter: CGFloat = 92
    private let tickCount = 24

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.shrutzSans(12, weight: .medium))
                    .foregroundColor(ShrutzPalette.navy.opacity(0.85))
                Button {
                    showHelp = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(ShrutzPalette.navy.opacity(0.55))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showHelp, arrowEdge: .top) {
                    Text(helpText)
                        .font(.shrutzSans(12))
                        .padding(10)
                        .frame(maxWidth: 220)
                }
            }

            dial
        }
    }

    private var dial: some View {
        ZStack {
            ForEach(0..<tickCount, id: \.self) { i in
                Rectangle()
                    .fill(ShrutzPalette.navy.opacity(0.25))
                    .frame(width: 1.5, height: i % 6 == 0 ? 8 : 4)
                    .offset(y: -(diameter / 2 - 6))
                    .rotationEffect(.degrees(Double(i) / Double(tickCount) * 360))
            }

            Circle()
                .strokeBorder(ShrutzPalette.navy.opacity(0.2), lineWidth: 2)
                .frame(width: diameter - 24, height: diameter - 24)

            VStack(spacing: 0) {
                Text("\(value)")
                    .font(.shrutzSerif(20, weight: .medium))
                    .foregroundColor(ShrutzPalette.navy)
                Text(unit)
                    .font(.shrutzSans(10))
                    .foregroundColor(ShrutzPalette.navy.opacity(0.6))
            }
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                let center = CGPoint(x: diameter / 2, y: diameter / 2)
                let dx = drag.location.x - center.x
                let dy = drag.location.y - center.y
                let radius = sqrt(dx * dx + dy * dy)
                let angle = atan2(dy, dx)

                if dragStartAngle == nil {
                    dragStartAngle = angle
                    dragStartValue = Double(value)
                    lastSnappedValue = value
                }

                guard let startAngle = dragStartAngle, let startValue = dragStartValue else { return }

                var angleDelta = angle - startAngle
                if angleDelta > .pi { angleDelta -= 2 * .pi }
                if angleDelta < -.pi { angleDelta += 2 * .pi }

                // Coarse near center (small radius → more value per radian),
                // fine near the rim (large radius → less value per radian).
                let radiusFraction = min(1, max(0, radius / (diameter / 2)))
                let rangeWidth = Double(range.upperBound - range.lowerBound)
                let coarseScale = rangeWidth / (.pi / 2)   // quarter turn spans the whole range
                let fineScale = rangeWidth / (6 * .pi)      // three full turns spans the whole range
                let scale = coarseScale + (fineScale - coarseScale) * radiusFraction

                let rawValue = startValue + angleDelta * scale
                let snapped = Int((rawValue / Double(step)).rounded()) * step
                let clamped = min(range.upperBound, max(range.lowerBound, snapped))

                if clamped != lastSnappedValue {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                    lastSnappedValue = clamped
                    value = clamped
                }
            }
            .onEnded { _ in
                dragStartAngle = nil
                dragStartValue = nil
                lastSnappedValue = nil
            }
    }
}

#Preview {
    RotaryDurationDial(
        label: "Active minutes",
        value: .constant(30),
        range: 1...120,
        step: 1,
        unit: "min",
        helpText: "Minutes of actual keyboard/mouse use before the wallpaper advances — time away from the machine doesn't count."
    )
    .padding()
    .background(ShrutzPalette.panelBackground)
}
