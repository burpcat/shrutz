import AppKit

/// Opens `shrutz dash` in Terminal via a generated .command file rather
/// than AppleScript driving Terminal — a .command file double-clicked/
/// opened via Launch Services runs in Terminal on its own, with no
/// Apple-Event scripting involved, so it doesn't create a brand-new
/// Automation permission prompt that doesn't exist anywhere else in this
/// all-bash tool. Extracted out of the dropdown panel — it no longer
/// hosts this action (moved to Settings' General tab).
enum DashboardLauncher {
    static func openInTerminal() {
        let script = "#!/bin/bash\n\"\(ShrutzCLI.binaryPath)\" dash\n"
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("shrutz-dash.command")
        try? script.write(to: tmpURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tmpURL.path)
        NSWorkspace.shared.open(tmpURL)
    }
}
