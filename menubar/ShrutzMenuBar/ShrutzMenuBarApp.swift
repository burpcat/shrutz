import SwiftUI

@main
struct ShrutzMenuBarApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Shrutz", image: "MenuBarIcon") {
            ShrutzPanelView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView()
                .environmentObject(appState)
        }
    }
}
