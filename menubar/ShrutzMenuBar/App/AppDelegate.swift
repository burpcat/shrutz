import AppKit

/// Owns everything a SwiftUI-only `MenuBarExtra` + `Settings` scene
/// couldn't: a manually-managed NSStatusItem (so it can be hidden/shown
/// at runtime), the panel window, the Settings window (with reliable
/// front-bringing), and the reopen callback that re-shows a hidden icon.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, MenuBarIconControlling {
    var appState: AppState!

    private var statusItem: NSStatusItem?
    private var panelWindowController: PanelWindowController?
    private lazy var settingsWindowController = SettingsWindowController()

    static let hideMenuBarIconDefaultsKey = "hideMenuBarIcon"

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState = AppDelegateBridge.pendingAppState

        if !UserDefaults.standard.bool(forKey: Self.hideMenuBarIconDefaultsKey) {
            showStatusItem()
        }
        appState.menuBarIconController = self

        #if DEBUG
        Typography.assertFontsResolve()
        AppIconBaker.bakeIfRequested()
        #endif
    }

    /// Fires when the user relaunches the app bundle (double-click in
    /// Finder/Spotlight/Launchpad) while it's already running — the
    /// confirmed recovery path for a hidden menu bar icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showStatusItem()
        return true
    }

    func setStatusItemVisible(_ visible: Bool) {
        if visible {
            showStatusItem()
        } else {
            hideStatusItem()
        }
    }

    func showSettingsWindow() {
        settingsWindowController.show(appState: appState)
    }

    private func showStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = ShrutzStatusMarkRenderer.makeImage()
        item.button?.action = #selector(togglePanel)
        item.button?.target = self
        statusItem = item
    }

    private func hideStatusItem() {
        guard let item = statusItem else { return }
        panelWindowController?.close()
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    @objc private func togglePanel() {
        guard let button = statusItem?.button else { return }
        if panelWindowController == nil {
            panelWindowController = PanelWindowController(appState: appState, onSettingsTapped: { [weak self] in
                self?.panelWindowController?.close()
                self?.showSettingsWindow()
            })
        }
        panelWindowController?.toggle(relativeTo: button)
    }
}
