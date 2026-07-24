import SwiftUI
import AppKit

/// A compact tactile rotary dial (mockup 02: ~52pt, light glassy fill, a
/// big centered number + tiny unit label, a thin red progress arc around
/// the rim) used for every duration/tunable in the General tab instead of
/// a plain stepper. Drag radius controls sensitivity: near the center
/// moves in big, coarse jumps; out toward the rim moves in small, fine
/// increments.
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

    private let diameter: CGFloat = 52

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(ShrutzPalette.textPrimary)
                Button {
                    showHelp = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(ShrutzPalette.textSecondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showHelp, arrowEdge: .top) {
                    Text(helpText)
                        .font(.system(size: 12))
                        .padding(10)
                        .frame(maxWidth: 220)
                }
            }
            Spacer()
            dial
        }
    }

    private var dial: some View {
        ZStack {
            Circle()
                .fill(.regularMaterial)
            Circle()
                .fill(Color.white.opacity(0.22))
            Circle()
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)

            Circle()
                .trim(from: 0, to: progressFraction)
                .stroke(ShrutzPalette.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(3)

            VStack(spacing: 0) {
                Text("\(value)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black.opacity(0.85))
                Text(unit)
                    .font(.system(size: 9))
                    .foregroundColor(.black.opacity(0.55))
            }
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(dragGesture)
    }

    private var progressFraction: CGFloat {
        let width = Double(range.upperBound - range.lowerBound)
        guard width > 0 else { return 0 }
        return CGFloat((Double(value) - Double(range.lowerBound)) / width)
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
                let coarseScale = rangeWidth / (.pi / 2)
                let fineScale = rangeWidth / (6 * .pi)
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
        label: "Active-use time before switch",
        value: .constant(30),
        range: 1...180,
        step: 1,
        unit: "min",
        helpText: "Minutes of actual keyboard/mouse use before the wallpaper advances — time away from the machine doesn't count."
    )
    .padding()
    .frame(width: 320)
    .background(Color.gray)
}
