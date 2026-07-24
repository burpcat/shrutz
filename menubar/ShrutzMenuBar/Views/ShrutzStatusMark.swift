import SwiftUI
import AppKit

/// The tiny NSStatusItem icon — a monochrome template rendering of the
/// wordmark's own ornate "S" (Pinyon Script), so the menu bar glyph and
/// the popover wordmark are the same letterform rather than a separate
/// hand-drawn approximation.
enum ShrutzStatusMarkRenderer {
    @MainActor
    static func makeImage(pointSize: CGFloat = 18) -> NSImage {
        let view = Text("S")
            .font(.shrutzWordmarkScript(pointSize * ShrutzWordmarkMetrics.scriptScale))
            .foregroundColor(.black)
            .fixedSize()
            .padding(.horizontal, 2)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: pointSize, height: pointSize))
        image.isTemplate = true
        return image
    }
}
