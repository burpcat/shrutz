import Foundation

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

    private let watcher = StateWatcher()

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
}
