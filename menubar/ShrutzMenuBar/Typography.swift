import SwiftUI
import AppKit

/// Typography is scoped, not app-wide:
/// - The wordmark lockup uses **Pinyon Script** (OFL) for the ornate "S"
///   and **Cormorant Garamond** (OFL) for the plain "hrut" — see
///   ShrutzWordmark.swift. The "z" is bold system red, not a custom font.
/// - **Sets** and **Creators Publish** tab content (titles, author/count
///   labels) use Cormorant Garamond + its true small-caps sibling
///   Cormorant SC (OFL) — an "old-money" editorial register.
/// - Everything else (popover set name, General tab, Weather labels) uses
///   the plain system (SF Pro) face via `.system(...)`, per the brief.
/// All fonts are bundled under Resources/Fonts and registered via
/// ATSApplicationFontsPath in Info.plist — see project.yml.
enum ShrutzFont {
    enum SerifWeight {
        case regular, medium, semibold
    }
    enum SmallCapsWeight {
        case regular, medium, semibold
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

    static func smallCapsPostScriptName(_ weight: SmallCapsWeight) -> String {
        switch weight {
        case .regular:  return "CormorantSC-Regular"
        case .medium:   return "CormorantSC-Medium"
        case .semibold: return "CormorantSC-SemiBold"
        }
    }

    static let wordmarkScriptPostScriptName = "PinyonScript-Regular"
}

extension Font {
    static func shrutzSerif(_ size: CGFloat, weight: ShrutzFont.SerifWeight = .regular, italic: Bool = false) -> Font {
        .custom(ShrutzFont.serifPostScriptName(weight, italic: italic), size: size)
    }

    /// True small caps (not shrunk capitals) for author/image-count labels
    /// on the Sets and Creators Publish tabs. Callers should also apply
    /// `.tracking(...)` for the letter-spaced look shown in the mockups.
    static func shrutzSmallCaps(_ size: CGFloat, weight: ShrutzFont.SmallCapsWeight = .regular) -> Font {
        .custom(ShrutzFont.smallCapsPostScriptName(weight), size: size)
    }

    static func shrutzWordmarkScript(_ size: CGFloat) -> Font {
        .custom(ShrutzFont.wordmarkScriptPostScriptName, size: size)
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
            "CormorantSC-Regular", "CormorantSC-Medium", "CormorantSC-SemiBold",
            "PinyonScript-Regular",
        ]
        for name in names where NSFont(name: name, size: 12) == nil {
            print("⚠️ Typography: font '\(name)' failed to resolve — check ATSApplicationFontsPath / exact PostScript name")
        }
    }
    #endif
}
