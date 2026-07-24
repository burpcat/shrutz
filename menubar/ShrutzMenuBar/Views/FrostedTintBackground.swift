import SwiftUI

/// The 5-blob drifting color mesh shared by the live ambient glass
/// (`FrostedTintBackground`, layered under `.ultraThinMaterial`) and the
/// static app-icon artwork (`AppIconArtwork`, which can't use a live
/// `Material` in an offscreen `ImageRenderer` snapshot — see that file's
/// doc comment — and layers a plain translucent overlay instead). Kept
/// separate so both share the exact same vivid-compositing fix rather than
/// risking two independently-tuned copies drifting apart. Deployment
/// target is macOS 14.0, so SwiftUI `MeshGradient` (macOS 15+) isn't
/// available — heavily-blurred animated color circles are the documented
/// fallback.
struct AmbientMesh: View {
    let palette: WallpaperPalette
    var isPaused: Bool = false
    /// Disable the slow positional drift for a one-shot static render
    /// (the app icon) where no animation will ever actually play.
    var animated: Bool = true

    @State private var drift = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let blobSize = max(w, h) * 1.1

            ZStack {
                blob(palette.topLeft, blobSize: blobSize, at: CGPoint(x: 0, y: 0), in: geo.size)
                blob(palette.topRight, blobSize: blobSize, at: CGPoint(x: w, y: 0), in: geo.size)
                blob(palette.bottomLeft, blobSize: blobSize, at: CGPoint(x: 0, y: h), in: geo.size)
                blob(palette.bottomRight, blobSize: blobSize, at: CGPoint(x: w, y: h), in: geo.size)
                blob(palette.center, blobSize: blobSize * 0.7, at: CGPoint(x: w / 2, y: h / 2), in: geo.size)
            }
            .frame(width: w, height: h)
            .clipped()
            // .compositingGroup() flattens the 5 blobs into one bitmap using
            // .plusLighter *among themselves* before that flattened result
            // composites (normally) against whatever's layered on top/below.
            // Without it, overlapping blobs would alpha-blend toward grey
            // exactly like the old flat-mean color sampling did, just at
            // compositing time instead of extraction time. .saturation
            // counteracts a Material's own vibrancy desaturation, where one
            // is present above this mesh.
            .compositingGroup()
            .blendMode(isPaused ? .normal : .plusLighter)
            .saturation(isPaused ? 1.0 : 1.3)
        }
        .animation(.easeInOut(duration: 0.6), value: isPaused)
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 26).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
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
            .opacity(isPaused ? 0.5 : 0.6)
            .position(point)
            .offset(offset)
    }
}

/// The ambient frosted-glass wash behind every surface (popover + Settings
/// window alike): `AmbientMesh` sampled from the current wallpaper's
/// actual regions, behind `.ultraThinMaterial`. Falls back to a flat,
/// fully desaturated grey when `isPaused` (Appendix A: `#C9C7C4`).
struct FrostedTintBackground: View {
    let palette: WallpaperPalette?
    var isPaused: Bool = false

    private static let calm = WallpaperPalette(colors: Array(repeating: ShrutzPalette.pausedGlass, count: 5))

    private var active: WallpaperPalette {
        isPaused ? Self.calm : (palette ?? Self.calm)
    }

    var body: some View {
        AmbientMesh(palette: active, isPaused: isPaused)
            .animation(.easeInOut(duration: 1.1), value: active)
            .background(.ultraThinMaterial)
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
