import SwiftUI

@main
struct ShrutzMenuBarApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("shrutz", systemImage: "photo.on.rectangle.angled") {
            MenuContentView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            PreferencesView()
                .environmentObject(appState)
        }
    }
}
