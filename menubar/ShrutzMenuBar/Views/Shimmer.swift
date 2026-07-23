import SwiftUI

/// A subtle animated shimmer placeholder shown while a thumbnail hasn't
/// loaded yet (Sets and Creators Publish grids) — never render a mass of
/// real thumbnails eagerly; cells that haven't loaded show this instead.
struct Shimmer: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: ShrutzPalette.cornerRadiusThumbnail)
            .fill(Color.white.opacity(0.12))
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.18), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 60)
                .offset(x: phase * 120)
            )
            .clipShape(RoundedRectangle(cornerRadius: ShrutzPalette.cornerRadiusThumbnail))
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}
