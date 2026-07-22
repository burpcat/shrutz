import SwiftUI
import AppKit

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

private enum ShrutzPalette {
    static let panelBackground = Color(hex: 0xFBF8F1)
    static let controlBackground = Color(hex: 0xEEEAE5)
    static let navy = Color(hex: 0x3E4A5C)
}

/// The custom card rendered inside the `.window`-style `MenuBarExtra`.
/// Every action here calls straight into the same `AppState` methods the
/// old native-menu dropdown used — this is a visual rebuild only, not new
/// behavior.
struct ShrutzPanelView: View {
    @EnvironmentObject var appState: AppState

    private let cornerRadius: CGFloat = 20
    private let panelWidth: CGFloat = 360

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(ShrutzPalette.panelBackground)

            Image("LeafMotif")
                .resizable()
                .scaledToFit()
                .frame(width: 100)
                .opacity(0.55)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            Image("LeafMotif")
                .resizable()
                .scaledToFit()
                .frame(width: 100)
                .opacity(0.55)
                .rotationEffect(.degrees(180))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            VStack(alignment: .leading, spacing: 16) {
                header
                statusLine
                wallpaperSetControl
                playbackRow
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .frame(width: panelWidth)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image("LogoMarkNavy")
                .resizable()
                .scaledToFit()
                .frame(height: 26)
            Text("Shrutz")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ShrutzPalette.navy)

            Spacer()

            SettingsLink {
                Image(systemName: "gearshape")
                    .foregroundColor(ShrutzPalette.navy)
            }
            .buttonStyle(.plain)

            Menu {
                overflowMenuContent
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(ShrutzPalette.navy)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private var statusLine: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !appState.shrutzInstalled {
                Text("Shrutz is not installed")
                Text("Run install.sh from the shrutz repo first")
            } else if let now = appState.now {
                Text(now.wallpaper)
                Text("Set: \(now.set) (\(now.position)/\(now.total))")
                Text(now.paused ? "Paused" : "\(max(0, now.secondsRemaining) / 60)m to next switch")
            } else {
                Text("Shrutz — waiting for daemon…")
            }
        }
        .font(.system(size: 12))
        .foregroundColor(ShrutzPalette.navy.opacity(0.75))
    }

    private var activeSetName: String {
        appState.sets.first(where: { $0.active })?.name ?? "Wallpaper Set"
    }

    private var wallpaperSetControl: some View {
        Menu {
            ForEach(appState.sets) { set in
                Button {
                    Task { await appState.switchSet(set.name) }
                } label: {
                    Text(set.active ? "✓ \(set.name)" : set.name)
                }
            }
        } label: {
            HStack {
                Text(activeSetName)
                    .foregroundColor(ShrutzPalette.navy)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ShrutzPalette.navy)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(ShrutzPalette.controlBackground))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .disabled(appState.sets.isEmpty)
        .frame(maxWidth: .infinity)
    }

    private var playbackRow: some View {
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

    @ViewBuilder
    private var overflowMenuContent: some View {
        if let status = appState.daemonStatus {
            Button(status.loaded ? "Stop Daemon" : "Start Daemon") {
                Task {
                    if status.loaded {
                        await appState.stopDaemon()
                    } else {
                        await appState.startDaemon()
                    }
                }
            }
        }

        Button("Open Dashboard in Terminal") { openDashboard() }
            .disabled(!appState.shrutzInstalled)

        Divider()

        Button("About Shrutz") {
            NSApplication.shared.orderFrontStandardAboutPanel(options: [:])
        }

        Divider()

        // Deliberately distinct wording from "Stop Daemon" — quitting this
        // menu bar helper does not touch wallpaper rotation, which keeps
        // running under launchd regardless.
        Button("Quit Shrutz") {
            NSApplication.shared.terminate(nil)
        }
    }

    /// Opens `shrutz dash` in Terminal via a generated .command file rather
    /// than AppleScript driving Terminal — a .command file double-clicked/
    /// opened via Launch Services runs in Terminal on its own, with no
    /// Apple-Event scripting involved, so it doesn't create a brand-new
    /// Automation permission prompt that doesn't exist anywhere else in
    /// this all-bash tool.
    private func openDashboard() {
        let script = "#!/bin/bash\n\"\(ShrutzCLI.binaryPath)\" dash\n"
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("shrutz-dash.command")
        try? script.write(to: tmpURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tmpURL.path)
        NSWorkspace.shared.open(tmpURL)
    }
}
