import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Hard design tokens from the approved mockups (Appendix A) — every
/// surface is ambient frosted glass over a wallpaper-derived color mesh,
/// with a single red accent. No blue anywhere; toggles/accents use red
/// when "on", never the system blue.
enum ShrutzPalette {
    /// The one accent color: crossed "z", pause circle, download buttons,
    /// dial arc, active-set edge, unload control.
    static let accent = Color(hex: 0xE5342B)

    /// Wordmark body color on tinted/dark glass.
    static let wordmarkLight = Color(hex: 0xF5F1EC)
    /// Wordmark body color on the light glass variant.
    static let wordmarkDark = Color(hex: 0x1A1A1A)

    /// Primary text on glass (~90% white).
    static let textPrimary = Color.white.opacity(0.9)
    /// Secondary/label text on glass (~60% white).
    static let textSecondary = Color.white.opacity(0.6)

    /// Flat, fully desaturated glass tone while rotation is paused.
    static let pausedGlass = Color(hex: 0xC9C7C4)

    static let cornerRadiusPopover: CGFloat = 28
    static let cornerRadiusWindow: CGFloat = 20
    static let cornerRadiusCard: CGFloat = 16
    static let cornerRadiusThumbnail: CGFloat = 13

    /// The one thumbnail aspect ratio (16:10, matching displays) used
    /// everywhere a wallpaper preview appears — popover, every filmstrip,
    /// and the Creators Publish catalog grid. No mixed aspect ratios.
    static let thumbnailAspectRatio: CGFloat = 1.6
}
