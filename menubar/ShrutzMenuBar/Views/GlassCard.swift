import SwiftUI

/// The hairline top-lit stroke + two-layer grounding shadow shared by every
/// elevated card, whether it uses `GlassCard`'s own `.regularMaterial` fill
/// or supplies its own custom background (e.g. Weather's condition-tinted
/// zones). Kept separate from `GlassCard` so both can share one definition
/// of "what makes a card read as elevated" without duplicating it.
struct CardBorder: ViewModifier {
    var cornerRadius: CGFloat = ShrutzPalette.cornerRadiusCard

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.5), Color.white.opacity(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 6)
            .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1)
    }
}

/// The shared "elevated plane" treatment for every card in the app (Sets
/// cards, Gallery cards, General tab's grouped rows, the Gallery
/// disclaimer/error cards). `.regularMaterial` is one step more opaque
/// than the window's own `.ultraThinMaterial` background, which is what
/// makes a card read as a distinctly brighter plane instead of blending
/// into the ambient glass behind it — the flat `Color.white.opacity(0.08)`
/// fill this replaces was visually indistinguishable from the background
/// in real screenshots.
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = ShrutzPalette.cornerRadiusCard

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(0.14))
                    )
            )
            .modifier(CardBorder(cornerRadius: cornerRadius))
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = ShrutzPalette.cornerRadiusCard) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }

    /// For views that supply their own background fill (e.g. a
    /// condition-tinted gradient) but still want the shared elevated-card
    /// stroke + shadow.
    func zoneCardBorder(cornerRadius: CGFloat = ShrutzPalette.cornerRadiusCard) -> some View {
        modifier(CardBorder(cornerRadius: cornerRadius))
    }
}

#Preview {
    VStack(spacing: 16) {
        Text("Card content").padding(20).frame(maxWidth: .infinity).glassCard()
    }
    .padding(24)
    .background(
        LinearGradient(colors: [.pink, .orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
    )
}
