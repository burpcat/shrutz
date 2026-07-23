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

/// The app-wide cream/navy palette — originally scoped to just the panel
/// dropdown, now shared across Settings too for one coherent visual system.
enum ShrutzPalette {
    static let panelBackground = Color(hex: 0xFBF8F1)
    static let controlBackground = Color(hex: 0xEEEAE5)
    static let navy = Color(hex: 0x3E4A5C)
}
