import SwiftUI

/// The macOS app icon's source artwork, at a fixed 1024×1024pt — the same
/// ornate Pinyon Script "S" as the wordmark (not the full word: a 5-glyph
/// serif/script wordmark shrunk to 16×16 would be illegible mush, and the
/// existing icon convention is already a single stylized glyph), on the
/// same vivid ambient mesh used everywhere else in the app.
///
/// This intentionally does NOT reuse `FrostedTintBackground` verbatim:
/// `.ultraThinMaterial` (and any SwiftUI `Material`) needs a live
/// `NSVisualEffectView` backed by an actual on-screen window to sample
/// real desktop content behind it. Rendered offscreen via `ImageRenderer`
/// (see `AppIconBaker`), there's nothing behind it to blur, so AppKit
/// silently substitutes a flat fallback tint — changing the result from
/// what you'd see live. A plain translucent-white gradient stands in for
/// the glass sheen instead, deterministically.
struct AppIconArtwork: View {
    static let size: CGFloat = 1024
    /// Apple's large-icon corner-radius fraction (Big Sur+), matching the
    /// already-rounded convention in the existing icon asset.
    static let cornerRadiusFraction: CGFloat = 0.1834
    /// Below this rendered size, Pinyon Script's thin calligraphic
    /// flourish stops reading as a letterform (confirmed by inspecting
    /// actual 16×16/32×32 renders — CoreText hinting alone doesn't save a
    /// script font's thin strokes at that scale). Swap to a bold, simple
    /// system glyph for just those smallest sizes rather than forcing one
    /// master to serve all 7 — same brand colors, same "S", legible.
    static let scriptLegibilityFloor: CGFloat = 64

    /// Render at the view's own point size (not always 1024) so each
    /// required icon size can be produced by CoreText natively hinting at
    /// that exact size, rather than photographically downsampled from one
    /// master — meaningfully crisper at the small end.
    var renderSize: CGFloat = size

    /// A fixed, hand-picked vivid palette representing the brand look —
    /// the icon is static artwork, not tied to any particular wallpaper.
    private static let brandPalette = WallpaperPalette(colors: [
        Color(hue: 0.98, saturation: 0.75, brightness: 0.78), // rose
        Color(hue: 0.08, saturation: 0.80, brightness: 0.80), // coral
        Color(hue: 0.86, saturation: 0.65, brightness: 0.72), // orchid
        Color(hue: 0.11, saturation: 0.85, brightness: 0.75), // gold
        Color(hue: 0.02, saturation: 0.78, brightness: 0.80), // peach
    ])

    var body: some View {
        ZStack {
            AmbientMesh(palette: Self.brandPalette, isPaused: false, animated: false)
            LinearGradient(
                colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
            glyph
        }
        .frame(width: renderSize, height: renderSize)
        .clipShape(RoundedRectangle(cornerRadius: renderSize * Self.cornerRadiusFraction, style: .continuous))
    }

    @ViewBuilder
    private var glyph: some View {
        if renderSize >= Self.scriptLegibilityFloor {
            Text("S")
                .font(.shrutzWordmarkScript(renderSize * 0.55))
                .foregroundColor(ShrutzPalette.wordmarkLight)
        } else {
            Text("S")
                .font(.system(size: renderSize * 0.58, weight: .bold, design: .serif))
                .foregroundColor(ShrutzPalette.wordmarkLight)
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach([1024, 256, 64, 32, 16], id: \.self) { size in
            AppIconArtwork(renderSize: CGFloat(size))
        }
    }
    .padding()
}
