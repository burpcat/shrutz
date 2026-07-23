import Foundation
import AppKit

/// Lets AppState (which has no AppKit imports) ask the AppDelegate to
/// show/hide the status item, without AppState needing to know about
/// NSStatusItem directly.
protocol MenuBarIconControlling: AnyObject {
    func setStatusItemVisible(_ visible: Bool)
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var now: NowInfo?
    @Published private(set) var sets: [WallpaperSet] = []
    @Published private(set) var daemonStatus: DaemonStatus?
    @Published private(set) var stats: Stats?
    @Published private(set) var config: ShrutzConfig?
    @Published private(set) var weather: WeatherStatus?
    @Published var lastError: String?
    @Published private(set) var shrutzInstalled: Bool = ShrutzCLI.isInstalled
    @Published private(set) var wallpaperPalette: WallpaperPalette?

    weak var menuBarIconController: MenuBarIconControlling?

    private let watcher = StateWatcher()

    private var lastPaletteSourcePath: String?
    private var paletteTask: Task<Void, Never>?

    private var daemonDownSince: Date?
    private let daemonDownGrace: TimeInterval = 8

    init() {
        watcher.onChange = { [weak self] in
            Task { @MainActor in await self?.refresh() }
        }
        watcher.start()
        Task { await refresh() }
    }

    func refresh() async {
        shrutzInstalled = ShrutzCLI.isInstalled
        guard shrutzInstalled else { return }

        async let n = try? ShrutzCLI.runJSON(["now", "--json"], as: NowInfo.self)
        async let s = try? ShrutzCLI.runJSON(["sets", "--json"], as: [WallpaperSet].self)
        async let st = try? ShrutzCLI.runJSON(["status", "--json"], as: DaemonStatus.self)
        async let stt = try? ShrutzCLI.runJSON(["stats", "--json"], as: Stats.self)
        async let c = try? ShrutzCLI.runJSON(["config", "--json"], as: ShrutzConfig.self)
        // Weather status/mapping commands don't crash if unset — they
        // just report an empty/off state, so this always has something
        // sane to show.
        async let w = try? ShrutzCLI.runJSON(["weather", "--json"], as: WeatherStatus.self)

        let (nowResult, setsResult, statusResult, statsResult, configResult, weatherResult) =
            await (n, s, st, stt, c, w)

        now = nowResult
        sets = setsResult ?? []
        daemonStatus = statusResult
        stats = statsResult
        config = configResult
        weather = weatherResult

        updatePaletteIfNeeded()
        evaluateDaemonLiveness()
    }

    // MARK: - Live tinting

    /// Only recomputes when the wallpaper path actually changes — a nil
    /// `now` (failed/decode-error refresh cycle, e.g. mid daemon-restart)
    /// leaves `wallpaperPalette` untouched, so a momentary blip never
    /// flashes the panel to a default tint.
    private func updatePaletteIfNeeded() {
        guard let path = now?.wallpaperPath, path != lastPaletteSourcePath else { return }
        paletteTask?.cancel()
        lastPaletteSourcePath = path
        paletteTask = Task { [weak self] in
            guard let palette = try? await WallpaperPaletteExtractor.extractPalette(fromImageAt: path),
                  !Task.isCancelled else { return }
            await MainActor.run { self?.wallpaperPalette = palette }
        }
    }

    // MARK: - Daemon-down debounce

    /// A normal set-switch/config-change restarts the daemon within ~1s
    /// (launchd's KeepAlive relaunches it) — that must never quit the app.
    /// Only a genuine, sustained absence (grace window, ~8s) should. A
    /// nil DaemonStatus (transient exec/decode failure) is treated as "no
    /// evidence either way," not as confirmation of down.
    private func evaluateDaemonLiveness() {
        guard let loaded = daemonStatus?.loaded else { return }
        if loaded {
            daemonDownSince = nil
            watcher.setFastPolling(false)
        } else {
            let since = daemonDownSince ?? Date()
            daemonDownSince = since
            watcher.setFastPolling(true)
            if Date().timeIntervalSince(since) >= daemonDownGrace {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func runAction(_ args: [String]) async {
        do {
            _ = try await ShrutzCLI.run(args)
            await refresh()
        } catch {
            lastError = "\(error)"
        }
    }

    func next() async { await runAction(["next"]) }
    func prev() async { await runAction(["prev"]) }

    func togglePause() async {
        await runAction([now?.paused == true ? "resume" : "pause"])
    }

    func switchSet(_ name: String) async { await runAction(["switch", name]) }
    func startDaemon() async { await runAction(["start"]) }
    func stopDaemon() async { await runAction(["stop"]) }
    func setConfig(_ key: String, _ value: Int) async { await runAction(["config", key, String(value)]) }

    func setWeatherEnabled(_ enabled: Bool) async { await runAction(["weather", enabled ? "on" : "off"]) }
    func setWeatherLocation(_ input: String) async { await runAction(["weather", "location", input]) }

    /// `shrutz weather on` dies if no location is set yet, so location
    /// must be set first when enabling from a blank/first-time state.
    func enableWeather(location: String) async {
        await setWeatherLocation(location)
        await setWeatherEnabled(true)
    }

    func mapWeather(condition: String, set: String) async { await runAction(["weather", "map", condition, set]) }
    func unmapWeather(condition: String) async { await runAction(["weather", "unmap", condition]) }
}
