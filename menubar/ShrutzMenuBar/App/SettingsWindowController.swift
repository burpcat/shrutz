import AppKit
import SwiftUI

/// A manually-managed Settings NSWindow, replacing SwiftUI's built-in
/// `Settings` scene + `SettingsLink` — for an LSUIElement accessory app,
/// that scene doesn't reliably bring itself to the front. This controller
/// gives explicit control: activate the app, then make the window key and
/// order it to the front, every time Settings is opened.
final class SettingsWindowController: NSWindowController {
    private var didCenter = false

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: true
        )
        window.title = "Shrutz Preferences"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 520, height: 420)
        self.init(window: window)
    }

    func show(appState: AppState) {
        if window?.contentView == nil {
            window?.contentView = NSHostingView(rootView: PreferencesView().environmentObject(appState))
        }
        if !didCenter {
            window?.center()
            didCenter = true
        }

        // `activate(ignoringOtherApps:)` is soft-deprecated as of macOS 14
        // and its focus-stealing override is no longer reliably honored —
        // empirically confirmed: it alone left this LSUIElement accessory
        // app's window behind the frontmost app. Layer every currently-
        // recommended mechanism instead: the modern no-argument
        // `activate()`, the NSRunningApplication equivalent, and
        // `orderFrontRegardless()` on top of the standard
        // `makeKeyAndOrderFront`.
        NSApp.activate()
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}
