import SwiftUI
import AppKit

/// A hand-tuned bezier swirl approximating the stylized "S" mark from the
/// design reference — authored as SwiftUI shape code rather than an
/// external asset, so it stays adjustable without needing an illustrator.
/// Control points are tuned visually against the reference image; treat
/// as a starting point, not a final asset.
struct ShrutzSGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()

        // A single flowing stroke: starts at the top-right, curls into a
        // tight upper loop, sweeps down and to the left through the
        // middle, then flares back out to a lower-right tail — the same
        // overall gesture as a calligraphic "S" swash.
        p.move(to: CGPoint(x: w * 0.68, y: h * 0.12))
        p.addCurve(
            to: CGPoint(x: w * 0.30, y: h * 0.32),
            control1: CGPoint(x: w * 0.62, y: h * 0.00),
            control2: CGPoint(x: w * 0.22, y: h * 0.06)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.62, y: h * 0.50),
            control1: CGPoint(x: w * 0.40, y: h * 0.56),
            control2: CGPoint(x: w * 0.55, y: h * 0.40)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.32, y: h * 0.70),
            control1: CGPoint(x: w * 0.70, y: h * 0.62),
            control2: CGPoint(x: w * 0.55, y: h * 0.60)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.66, y: h * 0.88),
            control1: CGPoint(x: w * 0.10, y: h * 0.80),
            control2: CGPoint(x: w * 0.30, y: h * 1.00)
        )

        return p
    }
}

enum ShrutzStatusMarkRenderer {
    /// Renders the S-glyph as a template `NSImage` for `NSStatusItem`.
    /// `isTemplate = true` lets AppKit auto-tint it for light/dark menu
    /// bars and highlighted/click states — only the alpha silhouette
    /// matters, not the stroke color used to render it.
    @MainActor
    static func makeImage(pointSize: CGFloat = 18) -> NSImage {
        let view = ShrutzSGlyph()
            .stroke(Color.black, style: StrokeStyle(lineWidth: pointSize * 0.14, lineCap: .round, lineJoin: .round))
            .frame(width: pointSize, height: pointSize)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: pointSize, height: pointSize))
        image.isTemplate = true
        return image
    }
}

#Preview {
    ShrutzSGlyph()
        .stroke(ShrutzPalette.navy, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        .frame(width: 120, height: 120)
        .padding()
}
