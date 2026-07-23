import SwiftUI
import AppKit

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
        .frame(minWidth: 520, idealWidth: 620, minHeight: 420, idealHeight: 520)
        .background(ShrutzPalette.panelBackground)
    }
}

struct GeneralPreferencesView: View {
    @EnvironmentObject var appState: AppState
    @State private var loginItemEnabled = LoginItemManager.isEnabled
    @AppStorage(AppDelegate.hideMenuBarIconDefaultsKey) private var hideMenuBarIcon = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let config = appState.config {
                    dialsSection(config)
                }

                Divider()

                togglesSection

                Divider()

                wallpaperSetSection

                Divider()

                daemonSection

                Divider()

                aboutSection
            }
            .padding(20)
        }
    }

    private func dialsSection(_ config: ShrutzConfig) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timing").font(.shrutzSerif(16, weight: .semibold))
            HStack(alignment: .top, spacing: 28) {
                RotaryDurationDial(
                    label: "Active time",
                    value: configBinding("ACTIVE_MINS", get: \.activeMins),
                    range: 1...180, step: 1, unit: "min",
                    helpText: "Minutes of actual keyboard/mouse use before the wallpaper advances — time away from the machine doesn't count."
                )
                RotaryDurationDial(
                    label: "Idle threshold",
                    value: configBinding("IDLE_THRESHOLD", get: \.idleThreshold),
                    range: 5...600, step: 5, unit: "sec",
                    helpText: "Seconds of no input before you're counted as away and the clock freezes."
                )
                RotaryDurationDial(
                    label: "Check interval",
                    value: configBinding("CHECK_EVERY", get: \.checkEvery),
                    range: 5...300, step: 5, unit: "sec",
                    helpText: "How often the daemon polls idle time and re-checks the visible wallpaper."
                )
                RotaryDurationDial(
                    label: "Weather poll",
                    value: configBinding("WEATHER_POLL_MINS", get: \.weatherPollMins),
                    range: 1...180, step: 1, unit: "min",
                    helpText: "How often the daemon checks the weather when auto-switching is enabled."
                )
            }
        }
    }

    private func configBinding(_ key: String, get: @escaping (ShrutzConfig) -> Int) -> Binding<Int> {
        Binding(
            get: { appState.config.map(get) ?? 0 },
            set: { newValue in Task { await appState.setConfig(key, newValue) } }
        )
    }

    private var togglesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Launch at Login", isOn: $loginItemEnabled)
                .onChange(of: loginItemEnabled) { _, newValue in
                    LoginItemManager.setEnabled(newValue)
                }
            Toggle("Hide menu bar icon", isOn: $hideMenuBarIcon)
                .onChange(of: hideMenuBarIcon) { _, hidden in
                    appState.menuBarIconController?.setStatusItemVisible(!hidden)
                }
            if hideMenuBarIcon {
                Text("Relaunch Shrutz.app (Finder, Spotlight, or Launchpad) to bring the icon back.")
                    .font(.shrutzSans(11))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var wallpaperSetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wallpaper Set").font(.shrutzSerif(16, weight: .semibold))
            Picker("Active set", selection: Binding(
                get: { appState.sets.first(where: { $0.active })?.name ?? "" },
                set: { newValue in Task { await appState.switchSet(newValue) } }
            )) {
                ForEach(appState.sets) { set in
                    Text(set.name).tag(set.name)
                }
            }
            .labelsHidden()
            .disabled(appState.sets.isEmpty)
        }
    }

    private var daemonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daemon").font(.shrutzSerif(16, weight: .semibold))
            HStack {
                Text(appState.daemonStatus?.loaded == true ? "Running" : "Stopped")
                    .foregroundColor(.secondary)
                Spacer()
                Button(appState.daemonStatus?.loaded == true ? "Stop Daemon" : "Start Daemon") {
                    Task {
                        if appState.daemonStatus?.loaded == true {
                            await appState.stopDaemon()
                        } else {
                            await appState.startDaemon()
                        }
                    }
                }
            }
            Button("Open Dashboard in Terminal") { DashboardLauncher.openInTerminal() }
                .disabled(!appState.shrutzInstalled)
        }
    }

    private var aboutSection: some View {
        HStack {
            Button("About Shrutz") {
                NSApplication.shared.orderFrontStandardAboutPanel(options: [:])
            }
            Spacer()
            Button("Quit Shrutz") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

struct SetsPreferencesView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if appState.sets.isEmpty {
                    Text("No sets yet — create one from the terminal: shrutz set create <name>")
                        .font(.shrutzSans(13))
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(appState.sets) { set in
                        setRow(set)
                    }
                }
            }
            .padding(20)
        }
    }

    private func setRow(_ set: WallpaperSet) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(set.name)
                    .font(.shrutzSerif(20, weight: .medium))
                    .foregroundColor(ShrutzPalette.navy)
                if set.active {
                    Text("active")
                        .font(.shrutzSans(11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Switch") {
                    Task { await appState.switchSet(set.name) }
                }
                .disabled(set.active)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(set.imagePaths, id: \.self) { path in
                        ThumbnailCell(path: path)
                    }
                }
            }
        }
    }
}

private struct ThumbnailCell: View {
    let path: String
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(ShrutzPalette.controlBackground)
            }
        }
        .frame(width: 96, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task(id: path) {
            image = await ThumbnailCache.shared.thumbnail(for: path)
        }
    }
}
