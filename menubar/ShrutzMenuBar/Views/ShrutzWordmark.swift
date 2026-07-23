import SwiftUI

/// The "Shrutz" wordmark lockup, per the approved mockups: an ornate
/// script capital "S" (Pinyon Script), "hrut" in plain Cormorant Garamond
/// (NOT italic/script — only the S is ornate), and a bold red "z" with a
/// hand-tuned hairline bar overlay. Used everywhere: the popover header
/// and every Settings-window header — never a plain serif rendering of
/// the whole word (that's a rendering artifact in some mockups, not the
/// design intent).
///
/// `scriptScale` compensates for Pinyon Script's capital having a much
/// smaller apparent cap-height than its em size relative to a plain serif
/// at the same point size — tune this and the bar overlay by comparing a
/// screenshot against menubar/design/reference/01-logo-variants.png.
struct ShrutzWordmark: View {
    var size: CGFloat = 20
    var color: Color = ShrutzPalette.wordmarkLight

    private var scriptSize: CGFloat { size * 2.0 }

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
                Capsule()
                    .fill(ShrutzPalette.accent)
                    .frame(width: size * 0.42, height: max(1, size * 0.07))
                    .offset(y: size * 0.02)
            }
        }
        .fixedSize()
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
