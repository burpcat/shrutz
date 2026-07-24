import SwiftUI

/// The "Shrutz" wordmark lockup, per the approved mockups: an ornate
/// script capital "S" (Pinyon Script), "hrut" in plain Cormorant Garamond
/// (NOT italic/script — only the S is ornate), and a bold red "z" struck
/// through by two parallel diagonal bars (a "≠"-style double strike — the
/// canonical glyph; a single-bar strike seen in some mockups is a
/// rendering artifact, not the design intent). Used everywhere: the
/// popover header and every Settings-window header — never a plain serif
/// rendering of the whole word.
///
/// Every number the wordmark uses lives here, scaled only by `size` — so
/// the lockup is guaranteed identical (same glyph, same angle, same
/// proportions) at every call site (popover collapsed/expanded, every
/// Settings header), never redrawn ad hoc per screen. `scriptScale`
/// compensates for Pinyon Script's capital having a much smaller apparent
/// cap-height than its em size relative to a plain serif at the same
/// point size — tune this and the strike-bar factors by comparing a
/// screenshot against menubar/design/reference/01-popover.png.
enum ShrutzWordmarkMetrics {
    static let scriptScale: CGFloat = 2.0
    static let zStrikeAngleDegrees: Double = 20
    static let zStrikeBarLengthFactor: CGFloat = 0.46
    static let zStrikeBarThicknessFactor: CGFloat = 0.05
    // Confirmed by screenshot at popover-collapsed size (20pt): the old
    // 0.10 gap left ~1px of edge-to-edge separation between the two bars
    // at Retina scale, which anti-aliasing merged into one ragged blob
    // instead of two readable parallel strikes. Widened so the two bars
    // stay visually distinct down to the smallest call site (16pt).
    static let zStrikeBarGapFactor: CGFloat = 0.24
    static let zStrikeBaseYOffsetFactor: CGFloat = 0.02
    /// Leftward nudge so the visually-heavier red double-barred "z" reads
    /// as optically centered rather than bounding-box centered.
    static let opticalNudgeFactor: CGFloat = 0.08
}

struct ShrutzWordmark: View {
    var size: CGFloat = 20
    var color: Color = ShrutzPalette.wordmarkLight

    private var scriptSize: CGFloat { size * ShrutzWordmarkMetrics.scriptScale }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("S")
                .font(.shrutzWordmarkScript(scriptSize))
                .foregroundColor(color)
            Text("hrut")
                .font(.shrutzSerif(size, weight: .regular))
                .foregroundColor(color)
            ZStack {
                Text("z")
                    .font(.shrutzSerif(size, weight: .semibold))
                    .foregroundColor(ShrutzPalette.accent)
                strikeBar(offsetY: size * (ShrutzWordmarkMetrics.zStrikeBaseYOffsetFactor - ShrutzWordmarkMetrics.zStrikeBarGapFactor / 2))
                strikeBar(offsetY: size * (ShrutzWordmarkMetrics.zStrikeBaseYOffsetFactor + ShrutzWordmarkMetrics.zStrikeBarGapFactor / 2))
            }
        }
        .fixedSize()
        .offset(x: -size * ShrutzWordmarkMetrics.opticalNudgeFactor)
    }

    /// One of the two parallel bars forming the "≠"-style double strike —
    /// built from a single helper so the two bars can never drift apart in
    /// angle/length/thickness.
    private func strikeBar(offsetY: CGFloat) -> some View {
        Capsule()
            .fill(ShrutzPalette.accent)
            .frame(
                width: size * ShrutzWordmarkMetrics.zStrikeBarLengthFactor,
                height: max(1, size * ShrutzWordmarkMetrics.zStrikeBarThicknessFactor)
            )
            .rotationEffect(.degrees(ShrutzWordmarkMetrics.zStrikeAngleDegrees))
            .offset(y: offsetY)
    }
}

#Preview {
    VStack(spacing: 20) {
        ShrutzWordmark(size: 24, color: ShrutzPalette.wordmarkLight)
            .padding(24)
            .background(Color.black)
        ShrutzWordmark(size: 24, color: ShrutzPalette.wordmarkDark)
            .padding(24)
            .background(Color.white)
    }
}
