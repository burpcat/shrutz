import SwiftUI

/// The ambient frosted-glass wash behind every surface (popover + Settings
/// window alike): a heavily blurred, low-res gradient mesh sampled from
/// the current wallpaper's actual regions, drifting slowly, behind
/// `.ultraThinMaterial`. Falls back to a flat, fully desaturated grey when
/// `isPaused` (Appendix A: `#C9C7C4`). Deployment target is macOS 14.0, so
/// SwiftUI `MeshGradient` (macOS 15+) isn't available — this uses
/// heavily-blurred animated color circles, positioned to match the
/// wallpaper's own quadrant/center tones, as the documented fallback.
struct FrostedTintBackground: View {
    let palette: WallpaperPalette?
    var isPaused: Bool = false

    @State private var drift = false

    private static let calm = WallpaperPalette(colors: Array(repeating: ShrutzPalette.pausedGlass, count: 5))

    private var active: WallpaperPalette {
        isPaused ? Self.calm : (palette ?? Self.calm)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let blobSize = max(w, h) * 1.1

            ZStack {
                blob(active.topLeft, blobSize: blobSize, at: CGPoint(x: 0, y: 0), in: geo.size)
                blob(active.topRight, blobSize: blobSize, at: CGPoint(x: w, y: 0), in: geo.size)
                blob(active.bottomLeft, blobSize: blobSize, at: CGPoint(x: 0, y: h), in: geo.size)
                blob(active.bottomRight, blobSize: blobSize, at: CGPoint(x: w, y: h), in: geo.size)
                blob(active.center, blobSize: blobSize * 0.7, at: CGPoint(x: w / 2, y: h / 2), in: geo.size)
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .animation(.easeInOut(duration: 0.6), value: isPaused)
        .animation(.easeInOut(duration: 1.1), value: active)
        .onAppear {
            withAnimation(.easeInOut(duration: 26).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
        .background(.ultraThinMaterial)
    }

    private func blob(_ color: Color, blobSize: CGFloat, at point: CGPoint, in size: CGSize) -> some View {
        // Slow drift: nudge each blob a small fraction toward center and
        // back, full cycle ~26s (well inside the brief's 20-40s target) —
        // "same as Apple Music, but slower."
        let driftAmount: CGFloat = 18
        let towardCenter = CGSize(
            width: point.x < size.width / 2 ? driftAmount : -driftAmount,
            height: point.y < size.height / 2 ? driftAmount : -driftAmount
        )
        let offset = drift ? towardCenter : .zero

        return Circle()
            .fill(color)
            .frame(width: blobSize, height: blobSize)
            .blur(radius: blobSize * 0.35)
            .opacity(isPaused ? 0.5 : 0.75)
            .position(point)
            .offset(offset)
    }
}

/// A soft dark blur placed behind text where the ambient glass's contrast
/// might otherwise drop too low to read comfortably (Appendix A: "a faint
/// dark scrim (~15-25% black blur) behind text only where contrast needs
/// it" — applied selectively, not as a blanket overlay).
struct TextScrim: ViewModifier {
    var opacity: Double = 0.2

    func body(content: Content) -> some View {
        content
            .background(
                Capsule()
                    .fill(Color.black.opacity(opacity))
                    .blur(radius: 8)
                    .padding(-6)
            )
    }
}

extension View {
    func textScrim(opacity: Double = 0.2) -> some View {
        modifier(TextScrim(opacity: opacity))
    }
}

#Preview {
    FrostedTintBackground(palette: WallpaperPalette(colors: [.blue, .purple, .orange, .pink, .yellow]))
        .frame(width: 340, height: 180)
}
