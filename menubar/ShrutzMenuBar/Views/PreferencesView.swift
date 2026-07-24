import SwiftUI
import AppKit

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case sets = "Sets"
    case weather = "Weather"
    case creators = "Creators Publish"
}

struct PreferencesView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        ZStack {
            FrostedTintBackground(palette: appState.wallpaperPalette, isPaused: appState.now?.paused ?? false)

            VStack(spacing: 16) {
                ShrutzWordmark(size: 40)
                    .padding(.top, 20)

                pillTabBar

                Group {
                    switch selectedTab {
                    case .general: GeneralPreferencesView()
                    case .sets: SetsPreferencesView()
                    case .weather: WeatherSectionView()
                    case .creators: GalleryView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.bottom, 20)
        }
        .frame(minWidth: 520, idealWidth: 640, minHeight: 460, idealHeight: 580)
    }

    private var pillTabBar: some View {
        HStack(spacing: 2) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(selectedTab == tab ? Color.white.opacity(0.9) : Color.clear)
                        )
                        .foregroundColor(selectedTab == tab ? .black : ShrutzPalette.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.white.opacity(0.15)))
    }
}

struct GeneralPreferencesView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLaunchAtLoginHelp = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                launchAtLoginRow
                    .padding(16)
                    .glassCard()

                if appState.config != nil {
                    VStack(alignment: .leading, spacing: 22) {
                        RotaryDurationDial(
                            label: "Active-use time before switch",
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
                    }
                    .padding(16)
                    .glassCard()
                }
            }
            .padding(24)
        }
    }

    private var launchAtLoginRow: some View {
        HStack {
            HStack(spacing: 4) {
                Text("Launch at login")
                    .font(.system(size: 13))
                    .foregroundColor(ShrutzPalette.textPrimary)
                Button {
                    showLaunchAtLoginHelp = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(ShrutzPalette.textSecondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showLaunchAtLoginHelp, arrowEdge: .top) {
                    Text("Starts the shrutz daemon — and this app, which the daemon launches on its own — automatically every time you log in.")
                        .font(.system(size: 12))
                        .padding(10)
                        .frame(maxWidth: 220)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { appState.daemonStatus?.autostartEnabled ?? false },
                set: { newValue in Task { await appState.setAutostart(newValue) } }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(ShrutzPalette.accent)
        }
    }

    private func configBinding(_ key: String, get: @escaping (ShrutzConfig) -> Int) -> Binding<Int> {
        Binding(
            get: { appState.config.map(get) ?? 0 },
            set: { newValue in Task { await appState.setConfig(key, newValue) } }
        )
    }
}

struct SetsPreferencesView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingNewSetSheet = false
    @State private var newSetName = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                HStack {
                    Spacer()
                    Button("+ New set") { showingNewSetSheet = true }
                        .buttonStyle(.plain)
                        .font(.shrutzSmallCaps(13, weight: .medium))
                        .tracking(1.2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(ShrutzPalette.accent))
                }

                if appState.sets.isEmpty {
                    Text("No sets yet.")
                        .font(.system(size: 13))
                        .foregroundColor(ShrutzPalette.textSecondary)
                } else {
                    ForEach(appState.sets) { set in
                        setCard(set)
                    }
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showingNewSetSheet) {
            newSetSheet
        }
    }

    private var newSetSheet: some View {
        VStack(spacing: 16) {
            Text("New Set").font(.shrutzSerif(18, weight: .medium))
            TextField("Name", text: $newSetName).textFieldStyle(.roundedBorder).frame(width: 220)
            HStack {
                Button("Cancel") { showingNewSetSheet = false }
                Button("Create") {
                    let name = newSetName
                    showingNewSetSheet = false
                    newSetName = ""
                    Task { await appState.createSet(name) }
                }
                .disabled(newSetName.isEmpty)
                .buttonStyle(.borderedProminent)
                .tint(ShrutzPalette.accent)
            }
        }
        .padding(24)
    }

    private func setCard(_ set: WallpaperSet) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(set.active ? ShrutzPalette.accent : Color.clear)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(set.name)
                        .font(.shrutzSerif(22, weight: .medium))
                        .foregroundColor(ShrutzPalette.textPrimary)
                    if set.active {
                        Text("ACTIVE")
                            .font(.shrutzSmallCaps(11))
                            .tracking(1.5)
                            .foregroundColor(ShrutzPalette.accent)
                    }
                    Spacer()
                    Text("\(set.images) images")
                        .font(.shrutzSmallCaps(11))
                        .tracking(1)
                        .foregroundColor(ShrutzPalette.textSecondary)
                    Toggle("Shuffle", isOn: Binding(
                        get: { set.shuffle },
                        set: { newValue in Task { await appState.toggleShuffle(set.name, on: newValue) } }
                    ))
                    .tint(ShrutzPalette.accent)
                    .toggleStyle(.switch)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(set.imagePaths, id: \.self) { path in
                            FilmstripThumbnail(path: path)
                        }
                    }
                }
            }
            .padding(14)
        }
        .glassCard()
        .contentShape(RoundedRectangle(cornerRadius: ShrutzPalette.cornerRadiusCard))
        .onTapGesture {
            guard !set.active else { return }
            Task { await appState.switchSet(set.name) }
        }
        .contextMenu {
            Button("Switch to this set") { Task { await appState.switchSet(set.name) } }
                .disabled(set.active)
            Button("Delete", role: .destructive) { Task { await appState.deleteSet(set.name) } }
                .disabled(set.active)
        }
    }
}

private struct FilmstripThumbnail: View {
    let path: String
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Shimmer()
            }
        }
        .frame(width: 72, height: 72 / ShrutzPalette.thumbnailAspectRatio)
        .clipShape(RoundedRectangle(cornerRadius: ShrutzPalette.cornerRadiusThumbnail, style: .continuous))
        .task(id: path) {
            image = await ThumbnailCache.shared.thumbnail(for: path)
        }
    }
}
