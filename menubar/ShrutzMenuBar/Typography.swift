import SwiftUI
import AppKit

/// App-wide typography. Cormorant Garamond (old-style Garamond revival,
/// OFL) is the primary serif — headings, the wordmark, editorial set
/// names. Libre Franklin (also OFL) is the dense-UI fallback where
/// Cormorant Garamond's delicate hairlines would wash out at small sizes.
/// Both are bundled under Resources/Fonts and registered via
/// ATSApplicationFontsPath in Info.plist — see project.yml.
enum ShrutzFont {
    enum SerifWeight {
        case regular, medium, semibold
    }
    enum SansWeight {
        case regular, medium, semibold, bold
    }

    static func serifPostScriptName(_ weight: SerifWeight, italic: Bool) -> String {
        switch (weight, italic) {
        case (.regular, false): return "CormorantGaramond-Regular"
        case (.regular, true):  return "CormorantGaramond-Italic"
        case (.medium, false):  return "CormorantGaramond-Medium"
        case (.medium, true):   return "CormorantGaramond-MediumItalic"
        case (.semibold, false): return "CormorantGaramond-SemiBold"
        case (.semibold, true):  return "CormorantGaramond-SemiBoldItalic"
        }
    }

    static func sansPostScriptName(_ weight: SansWeight) -> String {
        switch weight {
        case .regular:  return "LibreFranklin-Regular"
        case .medium:   return "LibreFranklin-Medium"
        case .semibold: return "LibreFranklin-SemiBold"
        case .bold:     return "LibreFranklin-Bold"
        }
    }
}

extension Font {
    static func shrutzSerif(_ size: CGFloat, weight: ShrutzFont.SerifWeight = .regular, italic: Bool = false) -> Font {
        .custom(ShrutzFont.serifPostScriptName(weight, italic: italic), size: size)
    }

    static func shrutzSans(_ size: CGFloat, weight: ShrutzFont.SansWeight = .regular) -> Font {
        .custom(ShrutzFont.sansPostScriptName(weight), size: size)
    }
}

enum Typography {
    #if DEBUG
    /// Cheap guard against ATSApplicationFontsPath / the xcodegen folder
    /// reference silently failing to register the bundled fonts — if a
    /// PostScript name doesn't resolve, SwiftUI silently falls back to the
    /// system font, which is easy to miss visually. Call once at launch.
    static func assertFontsResolve() {
        let names = [
            "CormorantGaramond-Regular", "CormorantGaramond-Medium", "CormorantGaramond-SemiBold",
            "CormorantGaramond-Italic", "CormorantGaramond-MediumItalic", "CormorantGaramond-SemiBoldItalic",
            "LibreFranklin-Regular", "LibreFranklin-Medium", "LibreFranklin-SemiBold", "LibreFranklin-Bold",
        ]
        for name in names where NSFont(name: name, size: 12) == nil {
            print("⚠️ Typography: font '\(name)' failed to resolve — check ATSApplicationFontsPath / exact PostScript name")
        }
    }
    #endif
}
