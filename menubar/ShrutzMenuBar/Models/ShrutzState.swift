import Foundation

// Codable mirrors of the JSON shapes shrutz's `--json` flags emit.
// Field names/keys must stay in lockstep with shrutz:cmd_now/cmd_sets/
// cmd_status/cmd_stats/cmd_config/cmd_weather_status/cmd_gallery_list.

struct NowInfo: Codable {
    let wallpaper: String
    let wallpaperPath: String
    let set: String
    let position: Int
    let total: Int
    let activeSeconds: Int
    let activeMinutesNeeded: Int
    let secondsRemaining: Int
    let paused: Bool
    let shuffle: Bool

    enum CodingKeys: String, CodingKey {
        case wallpaper
        case wallpaperPath = "wallpaper_path"
        case set, position, total
        case activeSeconds = "active_seconds"
        case activeMinutesNeeded = "active_minutes_needed"
        case secondsRemaining = "seconds_remaining"
        case paused, shuffle
    }
}

struct WallpaperSet: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let images: Int
    let created: String
    let active: Bool
    let shuffle: Bool
}

struct DaemonStatus: Codable {
    let loaded: Bool
    let pid: Int
    let lastExitStatus: Int

    enum CodingKeys: String, CodingKey {
        case loaded, pid
        case lastExitStatus = "last_exit_status"
    }
}

struct Stats: Codable {
    let uptimeSeconds: Int
    let uptimeHuman: String
    let totalSwitches: Int
    let setCount: Int
    let totalImages: Int
    let activeSet: String
    let paused: Bool
    let activeSeconds: Int
    let activeMinutesNeeded: Int

    enum CodingKeys: String, CodingKey {
        case uptimeSeconds = "uptime_seconds"
        case uptimeHuman = "uptime_human"
        case totalSwitches = "total_switches"
        case setCount = "set_count"
        case totalImages = "total_images"
        case activeSet = "active_set"
        case paused
        case activeSeconds = "active_seconds"
        case activeMinutesNeeded = "active_minutes_needed"
    }
}

struct ShrutzConfig: Codable {
    let activeMins: Int
    let idleThreshold: Int
    let checkEvery: Int
    let weatherPollMins: Int

    enum CodingKeys: String, CodingKey {
        case activeMins = "active_mins"
        case idleThreshold = "idle_threshold"
        case checkEvery = "check_every"
        case weatherPollMins = "weather_poll_mins"
    }
}

struct WeatherStatus: Codable {
    let enabled: Bool
    let location: String
    let condition: String
    let temperatureF: Double?
    let autoSwitch: Bool
    let lastChecked: String

    enum CodingKeys: String, CodingKey {
        case enabled, location, condition
        case temperatureF = "temperature_f"
        case autoSwitch = "auto_switch"
        case lastChecked = "last_checked"
    }
}

struct GalleryEntry: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let author: String
    let description: String
    let images: Int
    let thumbnailUrl: String
    let installed: Bool

    enum CodingKeys: String, CodingKey {
        case name, author, description, images
        case thumbnailUrl = "thumbnail_url"
        case installed
    }
}
