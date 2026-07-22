import SwiftUI

struct PreferencesView: View {
    var body: some View {
        TabView {
            GeneralPreferencesView()
                .tabItem { Label("General", systemImage: "gearshape") }
            SetsPreferencesView()
                .tabItem { Label("Sets", systemImage: "photo.stack") }
            WeatherSectionView()
                .tabItem { Label("Weather", systemImage: "cloud.sun") }
            GalleryView()
                .tabItem { Label("Creators Publish", systemImage: "square.grid.2x2") }
        }
        .frame(width: 480, height: 380)
    }
}

struct GeneralPreferencesView: View {
    @EnvironmentObject var appState: AppState
    @State private var loginItemEnabled = LoginItemManager.isEnabled

    var body: some View {
        Form {
            if let config = appState.config {
                Stepper(
                    "Active minutes before switching: \(config.activeMins)",
                    onIncrement: { Task { await appState.setConfig("ACTIVE_MINS", config.activeMins + 1) } },
                    onDecrement: { Task { await appState.setConfig("ACTIVE_MINS", max(1, config.activeMins - 1)) } }
                )
                Stepper(
                    "Idle threshold (seconds): \(config.idleThreshold)",
                    onIncrement: { Task { await appState.setConfig("IDLE_THRESHOLD", config.idleThreshold + 5) } },
                    onDecrement: { Task { await appState.setConfig("IDLE_THRESHOLD", max(5, config.idleThreshold - 5)) } }
                )
                Stepper(
                    "Check interval (seconds): \(config.checkEvery)",
                    onIncrement: { Task { await appState.setConfig("CHECK_EVERY", config.checkEvery + 5) } },
                    onDecrement: { Task { await appState.setConfig("CHECK_EVERY", max(5, config.checkEvery - 5)) } }
                )
            } else {
                Text("Loading…")
            }

            Toggle("Launch at Login", isOn: $loginItemEnabled)
                .onChange(of: loginItemEnabled) { _, newValue in
                    LoginItemManager.setEnabled(newValue)
                }
        }
        .padding()
    }
}

struct SetsPreferencesView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Table(appState.sets) {
            TableColumn("Name", value: \.name)
            TableColumn("Images") { set in Text("\(set.images)") }
            TableColumn("Created", value: \.created)
            TableColumn("Active") { set in Text(set.active ? "✓" : "") }
        }
        .padding()
        .contextMenu(forSelectionType: WallpaperSet.ID.self) { selection in
            if let name = selection.first {
                Button("Switch to this set") {
                    Task { await appState.switchSet(name) }
                }
            }
        }
    }
}
