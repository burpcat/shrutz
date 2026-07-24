import SwiftUI
import AppKit

/// A DEBUG-only, opt-in dev utility (same precedent as
/// `Typography.assertFontsResolve()`) that renders `AppIconArtwork` to
/// PNGs on the Desktop at every `AppIcon.appiconset` size, for a human to
/// copy into `Assets.xcassets` and commit. Never runs in a normal launch
/// — only when `SHRUTZ_BAKE_ICON=1` is set in the environment, since
/// `ImageRenderer`/SwiftUI font rendering needs a live `NSApplication` run
/// loop to behave reliably, which a bare command-line build-phase script
/// doesn't reliably provide; this app already has that run loop as an
/// `LSUIElement` menu-bar app.
///
/// Renders each size natively (rather than rendering once at 1024 and
/// `sips -z` downsampling) so CoreText hints the glyph at its actual
/// target size — confirmed necessary: a straight downsample left the
/// 16×16/32×32 outputs illegible.
#if DEBUG
enum AppIconBaker {
    static let sizes: [CGFloat] = [16, 32, 64, 128, 256, 512, 1024]

    @MainActor
    static func bakeIfRequested() {
        guard ProcessInfo.processInfo.environment["SHRUTZ_BAKE_ICON"] == "1" else { return }
        for size in sizes {
            bake(size: size)
        }
        NSApp.terminate(nil)
    }

    @MainActor
    private static func bake(size: CGFloat) {
        let renderer = ImageRenderer(content: AppIconArtwork(renderSize: size))
        // ImageRenderer.scale defaults to the main screen's backing scale
        // (2.0 on Retina) — with an N×N-*point* view that would silently
        // double the output to 2N×2N *pixels*. Force 1:1.
        renderer.scale = 1.0

        guard
            let nsImage = renderer.nsImage,
            let tiff = nsImage.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            print("⚠️ AppIconBaker: failed to render icon artwork at \(size)")
            return
        }

        let intSize = Int(size)
        let url = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("icon_\(intSize)x\(intSize).png")
        do {
            try png.write(to: url)
            print("✅ AppIconBaker: wrote \(url.path)")
        } catch {
            print("⚠️ AppIconBaker: failed to write PNG — \(error)")
        }
    }
}
#endif
