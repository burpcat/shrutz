import SwiftUI

/// The popover: two states of the same ambient-glass card (mockups 02/09).
/// Collapsed (~200x90): only the wordmark, centered, nothing else. Tapping
/// it spring-animates to expanded (~340x180): wordmark header + a small
/// red asterisk settings affordance, a thumbnail + set name + progress
/// bar, and transport controls. `AppState.panelIsExpanded` (not local
/// `@State`) drives this so `PanelWindowController` can force it back to
/// collapsed every time the popover is freshly opened, and so the window
/// controller can observe it to resize the actual NSPanel frame.
struct ShrutzPanelView: View {
    @EnvironmentObject var appState: AppState
    let onSettingsTapped: () -> Void

    private var isPaused: Bool { appState.now?.paused ?? false }
    private var isExpanded: Bool { appState.panelIsExpanded }

    var body: some View {
        ZStack {
            FrostedTintBackground(palette: appState.wallpaperPalette, isPaused: isPaused)

            if isExpanded {
                expandedContent
                    .transition(.opacity)
            } else {
                collapsedContent
                    .transition(.opacity)
            }
        }
        .frame(width: isExpanded ? 340 : 200, height: isExpanded ? 180 : 90)
        .clipShape(RoundedRectangle(cornerRadius: ShrutzPalette.cornerRadiusPopover))
        .overlay(
            RoundedRectangle(cornerRadius: ShrutzPalette.cornerRadiusPopover)
                .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: ShrutzPalette.cornerRadiusPopover))
        .onTapGesture {
            guard !isExpanded else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                appState.panelIsExpanded = true
            }
        }
    }

    private var collapsedContent: some View {
        ShrutzWordmark(size: 20)
    }

    private var expandedContent: some View {
        VStack(spacing: 14) {
            header
            middleRow
            transportRow
        }
        .padding(16)
    }

    private var header: some View {
        HStack {
            ShrutzWordmark(size: 16)
            Spacer()
            Button(action: onSettingsTapped) {
                Image(systemName: "asterisk")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ShrutzPalette.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private var middleRow: some View {
        HStack(spacing: 10) {
            PanelThumbnail(path: appState.now?.wallpaperPath)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                Text(appState.now?.set ?? "—")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ShrutzPalette.textPrimary)
                    .textScrim()
                progressBar
            }
        }
    }

    private var progressBar: some View {
        let total = max(1, (appState.now?.activeMinutesNeeded ?? 1) * 60)
        let remaining = appState.now?.secondsRemaining ?? total
        let progress = min(1, max(0, 1 - Double(remaining) / Double(total)))

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.25))
                Capsule().fill(Color.white.opacity(0.9))
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 4)
    }

    private var transportRow: some View {
        HStack(spacing: 28) {
            Spacer()

            Button {
                Task { await appState.prev() }
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ShrutzPalette.textPrimary)
            }
            .buttonStyle(.plain)
            .disabled(!appState.shrutzInstalled)

            Button {
                Task { await appState.togglePause() }
            } label: {
                if isPaused {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ShrutzPalette.accent)
                } else {
                    ZStack {
                        Circle().fill(ShrutzPalette.accent)
                        Image(systemName: "pause.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    .frame(width: 28, height: 28)
                }
            }
            .buttonStyle(.plain)
            .disabled(!appState.shrutzInstalled)

            Button {
                Task { await appState.next() }
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ShrutzPalette.textPrimary)
            }
            .buttonStyle(.plain)
            .disabled(!appState.shrutzInstalled)

            Spacer()
        }
    }
}

private struct PanelThumbnail: View {
    let path: String?
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Color.white.opacity(0.15)
            }
        }
        .task(id: path) {
            guard let path else { image = nil; return }
            image = await ThumbnailCache.shared.thumbnail(for: path, maxPixelSize: 88)
        }
    }
}

#Preview {
    ShrutzPanelView(onSettingsTapped: {})
        .environmentObject(AppState())
}
