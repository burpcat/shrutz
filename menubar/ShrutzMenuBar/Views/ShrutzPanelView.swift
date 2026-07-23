import SwiftUI

/// The redesigned "now-playing"-style dropdown card, hosted in a borderless
/// NSPanel by PanelWindowController. Content is deliberately minimal — the
/// wordmark, a settings button, and transport controls — with the frosted
/// wallpaper-derived wash as the only other visual element. No set name,
/// no thumbnail, no timer text: the tinted glass is the artwork.
struct ShrutzPanelView: View {
    @EnvironmentObject var appState: AppState
    let onSettingsTapped: () -> Void

    private let cornerRadius: CGFloat = 20
    private let panelWidth: CGFloat = 300

    var body: some View {
        ZStack {
            FrostedTintBackground(palette: appState.wallpaperPalette, isPaused: appState.now?.paused ?? false)
            VStack(spacing: 18) {
                header
                transportRow
            }
            .padding(18)
        }
        .frame(width: panelWidth)
        .fixedSize(horizontal: false, vertical: true)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
        )
    }

    private var header: some View {
        HStack {
            ShrutzWordmark(size: 18)
            Spacer()
            Button(action: onSettingsTapped) {
                Image(systemName: "gearshape")
                    .foregroundColor(ShrutzPalette.navy)
            }
            .buttonStyle(.plain)
        }
    }

    private var transportRow: some View {
        HStack(spacing: 32) {
            Spacer()

            Button {
                Task { await appState.prev() }
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ShrutzPalette.navy)
            }
            .buttonStyle(.plain)
            .disabled(!appState.shrutzInstalled)

            Button {
                Task { await appState.togglePause() }
            } label: {
                ZStack {
                    Circle().fill(ShrutzPalette.navy)
                    Image(systemName: appState.now?.paused == true ? "play.fill" : "pause.fill")
                        .font(.system(size: 18))
                        .foregroundColor(ShrutzPalette.panelBackground)
                }
                .frame(width: 52, height: 52)
            }
            .buttonStyle(.plain)
            .disabled(!appState.shrutzInstalled)

            Button {
                Task { await appState.next() }
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ShrutzPalette.navy)
            }
            .buttonStyle(.plain)
            .disabled(!appState.shrutzInstalled)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ShrutzPanelView(onSettingsTapped: {})
        .environmentObject(AppState())
}
