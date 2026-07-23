import SwiftUI

/// The "Shrutz" logo lockup — a single `Text` run (splitting "Shrut" + "z"
/// into two Text views would break native kerning between them) in
/// Cormorant Garamond italic, with a hand-tuned hairline bar overlaid on
/// the trailing "z" to match the crossed-z in the design reference. No
/// OFL serif ships a naturally barred z, and applying this overlay to
/// every body-text z would look absurd — this bar exists only here, in
/// the standalone wordmark lockup.
///
/// The overlay's offset/width are tuned by eye at `size` — if reused at a
/// meaningfully different size, re-tune rather than assuming it scales
/// linearly (italic slant and letter spacing don't scale perfectly linearly
/// with point size).
struct ShrutzWordmark: View {
    var size: CGFloat = 18
    var color: Color = ShrutzPalette.navy

    var body: some View {
        Text("Shrutz")
            .font(.shrutzSerif(size, weight: .medium, italic: true))
            .foregroundColor(color)
            .overlay(alignment: .trailing) {
                Capsule()
                    .fill(color)
                    .frame(width: size * 0.34, height: max(1, size * 0.055))
                    .offset(x: -size * 0.12, y: size * 0.03)
            }
    }
}

#Preview {
    ShrutzWordmark(size: 32)
        .padding()
        .background(ShrutzPalette.panelBackground)
}
