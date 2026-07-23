import SwiftUI

/// The Apple-Music-now-playing-style wash: a soft, slowly drifting,
/// multi-colour blurred backdrop behind `.ultraThinMaterial`, derived from
/// `palette`. Falls back to a calm light grey when `isPaused` — the
/// backing `NSPanel` this sits in is non-opaque/clear, so the material
/// genuinely samples the real desktop behind the floating panel, not just
/// these blobs on a flat background.
///
/// Deployment target is macOS 14.0, so SwiftUI `MeshGradient` (macOS 15+)
/// isn't available — this uses heavily-blurred animated color circles as
/// the documented fallback instead.
struct FrostedTintBackground: View {
    let palette: WallpaperPalette?
    var isPaused: Bool = false

    @State private var drift = false

    private static let calm = WallpaperPalette(colors: [
        Color(hex: 0xD8D5CE), Color(hex: 0xEDEAE3), Color(hex: 0xC9C6C0),
    ])

    private var active: WallpaperPalette {
        isPaused ? Self.calm : (palette ?? Self.calm)
    }

    var body: some View {
        ZStack {
            ForEach(Array(active.colors.enumerated()), id: \.offset) { index, color in
                Circle()
                    .fill(color)
                    .frame(width: 220, height: 220)
                    .blur(radius: 60)
                    .opacity(isPaused ? 0.35 : 0.55)
                    .offset(blobOffset(index, drifted: drift))
            }
        }
        .animation(.easeInOut(duration: 0.6), value: isPaused)
        .animation(.easeInOut(duration: 0.9), value: active)
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
        .background(.ultraThinMaterial)
    }

    /// A small fixed offset pattern per blob index, nudged by `drifted` to
    /// give the slow drifting-wash look without any per-blob state.
    private func blobOffset(_ index: Int, drifted: Bool) -> CGSize {
        let base: [CGSize] = [
            CGSize(width: -60, height: -40),
            CGSize(width: 70, height: -20),
            CGSize(width: -30, height: 50),
            CGSize(width: 50, height: 60),
        ]
        let start = base[index % base.count]
        guard drifted else { return start }
        return CGSize(width: start.width * -0.6, height: start.height * -0.6)
    }
}

#Preview {
    FrostedTintBackground(palette: WallpaperPalette(colors: [.blue, .purple, .orange]))
        .frame(width: 300, height: 160)
}
