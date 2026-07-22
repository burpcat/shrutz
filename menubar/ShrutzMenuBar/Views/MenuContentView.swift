import SwiftUI
import AppKit

struct MenuContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if !appState.shrutzInstalled {
            Text("shrutz is not installed")
            Text("Run install.sh from the shrutz repo first")
        } else if let now = appState.now {
            Text(now.wallpaper)
            Text("Set: \(now.set) (\(now.position)/\(now.total))")
            Text(now.paused ? "Paused" : "\(max(0, now.secondsRemaining) / 60)m to next switch")
        } else {
            Text("shrutz — waiting for daemon…")
        }

        Divider()

        Button("Next Wallpaper") { Task { await appState.next() } }
            .disabled(!appState.shrutzInstalled)
        Button("Previous Wallpaper") { Task { await appState.prev() } }
            .disabled(!appState.shrutzInstalled)
        Button(appState.now?.paused == true ? "Resume" : "Pause") {
            Task { await appState.togglePause() }
        }
        .disabled(!appState.shrutzInstalled)

        if !appState.sets.isEmpty {
            Divider()
            Menu("Sets") {
                ForEach(appState.sets) { set in
                    Button {
                        Task { await appState.switchSet(set.name) }
                    } label: {
                        Text(set.active ? "✓ \(set.name)" : set.name)
                    }
                }
            }
        }

        Divider()

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

        SettingsLink {
            Text("Preferences…")
        }

        Divider()

        // Deliberately distinct wording from "Stop Daemon" — quitting this
        // menu bar helper does not touch wallpaper rotation, which keeps
        // running under launchd regardless.
        Button("Quit Menu Bar Helper") {
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
