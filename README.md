# shrutz

![version](https://img.shields.io/badge/version-2.1.0-blue) ![license](https://img.shields.io/badge/license-MIT-green)

**A wallpaper rotation engine for macOS that only counts time you're actually at your computer.**

Most wallpaper rotators switch on a wall-clock timer — they'll cycle while you're asleep, away from your desk, or your laptop is closed. shrutz measures *active usage* instead. The timer only ticks when your keyboard and mouse are live. Walk away, and it freezes exactly where it left off. Come back, and it resumes.

Wallpapers are applied across every Mission Control Space simultaneously, not just the one currently on screen.

---

**Contents:** [What's new](#whats-new-in-v21) · [How it works](#how-it-works) · [Requirements](#requirements) · [Installation](#installation) · [Usage](#usage) · [File layout](#file-layout) · [Configuration](#configuration) · [Weather](#weather) · [Creators Publish](#creators-publish) · [Menu Bar App](#menu-bar-app) · [Internals](#internals) · [Uninstall](#uninstall) · [Changelog](#changelog) · [License](#license)

---

## What's new in v2.1

**Weather-based auto-switching.** Set your location once and map weather conditions to your own wallpaper sets — shrutz polls the free, no-API-key [Open-Meteo](https://open-meteo.com) service and switches automatically when the weather changes. See [Weather](#weather).

**Creators Publish gallery.** shrutz ships with no bundled wallpapers now — instead, browse and download developer-curated sets (including the original `haasan` set) with `shrutz gallery list` / `shrutz gallery install`. See [Creators Publish](#creators-publish).

**A friendlier install.** The installer now asks you to name your own first wallpaper set instead of force-seeding a fixed default — see [Installation](#installation).

**A menu bar companion app.** shrutz stays terminal-first, but `shrutz menubar install` builds and installs an optional native menu bar app for people who'd rather not use the CLI. See [Menu Bar App](#menu-bar-app).

**`--json` output.** `now`, `sets`, `status`, `stats`, `config`, and `weather` all support a `--json` flag for scripting or the menu bar app to consume.

## What's new in v2

shrutz is now a full binary CLI. No shell function injection — every command runs directly from `~/.local/bin/shrutz` on your `$PATH`. The wallpaper directory is now organised into named **sets**, giving you multiple curated pools to switch between instantly.

---

## How it works

shrutz runs as a background daemon via macOS `launchd`. Every 30 seconds it queries the kernel's I/O Registry (`ioreg`) for the `HIDIdleTime` value — the number of nanoseconds since your last keyboard or trackpad input. If that idle time is under 60 seconds, you're considered active, and 30 seconds are added to a running counter. Once the counter reaches 30 minutes of genuine active use, the wallpaper advances to the next image and the counter resets.

**Multi-space coverage.** When a wallpaper switch happens, shrutz writes the new path directly into `Index.plist` — the wallpaper store maintained by macOS's wallpaper agent at `~/Library/Application Support/com.apple.wallpaper/Store/`. The file is a binary plist keyed by Space UUID. Each Space entry holds a `Configuration` field which is itself a binary plist containing the image path. shrutz rewrites that field for every Space, every per-display override within each Space, and the `SystemDefault` fallback entry, then restarts the wallpaper agent via `launchctl kickstart` so it re-reads the store and propagates the change to all Mission Control Spaces simultaneously.

**Space polling.** Every 30 seconds while you're active, shrutz reads the wallpaper currently showing on the active Space via AppleScript and compares it to what it expects. If they don't match — because a Space missed a previous write, or the agent hadn't fully reloaded yet — it reapplies the correct wallpaper immediately via AppleScript. This is a fast local call with no plist write and no agent restart.

**Wallpaper sets.** Images live in named subdirectories under `wallpapers/`. Only one set is active at a time. Switching sets changes the pool immediately without resetting the active-time counter — the clock always keeps running.

**Shuffle mode.** Any set can be put into shuffle mode. The daemon generates a random play order that covers every image before repeating, using a Fisher-Yates shuffle. The order persists across reboots.

State (current wallpaper index, accumulated active time, active set, shuffle order) is written to a plain text file on every tick, so a reboot mid-session doesn't lose your progress.

---

## Requirements

- macOS 14 Sonoma or later
- bash (ships with macOS)
- python3 (ships with macOS)
- No third-party software dependencies

The weather and Creators Publish features are entirely opt-in and only reach the network when actually used — `api.open-meteo.com` / `geocoding-api.open-meteo.com` for weather, `raw.githubusercontent.com` / `github.com` for the gallery. Building the menu bar companion app additionally requires Xcode.

---

## Installation

Clone the repository and run the installer:

```bash
git clone https://github.com/burpcat/shrutz.git
cd shrutz
chmod +x shrutz install.sh
./install.sh
```

The installer will:

1. Create the `~/.local` directory layout
2. On a fresh install (not a repair/reinstall), prompt you to name your first wallpaper set — this becomes your active set — and optionally import a folder of images into it
3. Install the binary to `~/.local/bin/shrutz`
4. Register a `launchd` agent that starts automatically at login (skipped until your active set actually has images, so it never starts in an empty-set crash loop)
5. Add `~/.local/bin` to your `PATH` and register the man page

The first-run prompt looks like this:

```
  Name your first wallpaper set (this becomes your active set).
  Set name (or Enter for 'main'): vacation

  Where are your wallpapers?
  Enter a folder path to import now, or press Enter to skip.

  Path (or Enter to skip): ~/Pictures/my-wallpapers/
  ✓  42 images imported, 0 skipped
```

Press Enter to accept the default name (`main`) or skip the import — add images later with `shrutz import`. Supported formats: `.jpg`, `.jpeg`, `.png`, `.heic`, `.webp`

shrutz ships with no bundled wallpapers. Once installed, browse developer-curated sets — including the original `haasan` set — with `shrutz gallery list` (see [Creators Publish](#creators-publish)).

Re-running `install.sh` on an existing install (repairs, `shrutz update`) skips this prompt entirely — it only ever runs once, on a genuinely fresh install.

After installation reload your shell:

```bash
source ~/.zshrc
```

---

## Usage

```bash
# Daemon
shrutz status               # check if the daemon is running
shrutz log                  # stream the live activity log
shrutz start                # start the daemon
shrutz stop                 # stop the daemon
shrutz autostart on         # start the daemon (and menu bar app) at every login
shrutz autostart off        # disable that
shrutz autostart status     # show whether it's currently enabled
shrutz --version            # print the installed version

# Playback
shrutz now                  # current wallpaper, set, timer state
shrutz next                 # skip to next wallpaper (timer unchanged)
shrutz prev                 # go back one wallpaper (timer unchanged)
shrutz pause                # freeze the active-time counter
shrutz resume               # unfreeze it
shrutz dash                 # live terminal dashboard

# Sets
shrutz sets                              # list all sets
shrutz set create dark ~/Downloads/dark/ # create a set and import in one shot
shrutz set info dark                     # image count, disk size, progress
shrutz set shuffle dark on               # enable shuffle for a set
shrutz set rename dark evening           # rename a set
shrutz set delete old-set               # delete a set (with confirmation)
shrutz set delete old-set -y            # ...or skip the prompt (scripts/GUI)
shrutz switch dark                       # switch active set
shrutz import ~/path/to/images/          # import into active set
shrutz import ~/path/ --set dark         # import into a specific set
shrutz export dark                       # zip a set to ~/Desktop

# Creators Publish (gallery)
shrutz gallery list                     # browse developer-curated sets
shrutz gallery install haasan           # download and install one

# Weather
shrutz weather                          # status, location, mappings
shrutz weather location "Boston"        # set your location (city name or lat,lon)
shrutz weather map rain rainy-set       # switch to 'rainy-set' when it's raining
shrutz weather on                       # enable auto-switching
shrutz weather check                    # force an immediate check

# Menu bar app
shrutz menubar install                  # build + install the optional GUI companion

# Info & config
shrutz stats                            # uptime, switches, totals
shrutz history 20                       # last 20 wallpaper switches
shrutz config                           # show tunables
shrutz config ACTIVE_MINS 45            # change a tunable live
shrutz update                           # pull latest and reinstall

# Any of now/sets/status/stats/config/weather also take --json
shrutz now --json
```

A man page is installed at `~/.local/share/man/man1/shrutz.1`. Run `man shrutz` for the full reference.

---

## File layout

shrutz follows the [XDG Base Directory](https://specifications.freedesktop.org/basedir-spec/latest/) convention, adapted for macOS. Everything lives under `~/.local` — nothing is scattered across system directories.

```
~/.local/
├── bin/
│   └── shrutz                                    main binary
├── lib/
│   └── shrutz/
│       ├── wallpapers/
│       │   ├── <your-first-set>/                 named at install time
│       │   │   ├── __init__                      set metadata
│       │   │   └── *.png / *.jpg / …             your images
│       │   └── <other-sets>/                     additional sets
│       ├── state                                 persisted runtime state
│       ├── weather_map                           condition → set mappings
│       ├── VERSION                                installed version
│       ├── shrutz.log                            activity log
│       └── shrutz.err                            stderr / crash output
├── etc/
│   └── launchd/
│       └── local.shrutz.plist                    launchd plist (source of truth)
└── share/
    └── man/
        └── man1/
            └── shrutz.1                          man page

~/Library/LaunchAgents/
└── local.shrutz.plist                            → symlink to ~/.local/etc/launchd/

~/Applications/
└── Shrutz.app                                     optional, via `shrutz menubar install`
```

Each set folder contains a `__init__` metadata file:

```
name=dark
created=2025-06-01 09:14:00
images=23
shuffle=true
```

---

## Configuration

Tunables live at the top of `~/.local/bin/shrutz` and can be edited in-place from the CLI:

```bash
shrutz config ACTIVE_MINS 45       # switch every 45 minutes of active use
shrutz config IDLE_THRESHOLD 120   # consider away after 2 minutes idle
shrutz config CHECK_EVERY 60       # poll every 60 seconds instead of 30
shrutz config WEATHER_POLL_MINS 30 # check the weather every 30 minutes instead of 20
```

Each `config` call patches the script in-place and restarts the daemon immediately.

---

## Weather

Set a location once, map weather conditions to your own wallpaper sets, and shrutz switches automatically when the weather changes — polled on its own schedule, independent of the active-time timer.

```bash
shrutz weather location "San Francisco"   # or a lat,lon pair: "37.77,-122.42"
shrutz weather map rain rainy-day-set
shrutz weather map snow winter-set
shrutz weather map night dark-mode-set
shrutz weather on
```

Valid conditions: `clear`, `cloudy`, `fog`, `rain`, `snow`, `storm`, `night`. Not every condition needs a mapping — unmapped conditions are simply no-ops. `night` only overrides `clear`/`cloudy` after dark; severe weather (rain/snow/storm/fog) is shown regardless of time of day.

Weather data and city-name geocoding come from the free [Open-Meteo](https://open-meteo.com) API — no signup, no API key. A manual `shrutz switch` to an unrelated set is respected until the underlying weather condition actually changes to a different mapped target, so weather won't fight you over a switch you made yourself.

Run `shrutz weather check` anytime to force an immediate check without waiting for the next scheduled poll, or `shrutz weather` to see the current status.

---

## Creators Publish

shrutz ships with no bundled wallpapers. Instead, browse and download wallpaper sets published by the developer — hosted as a small JSON manifest on GitHub — and optionally install any of them locally:

```bash
shrutz gallery list              # browse available sets
shrutz gallery install haasan    # download and install one
shrutz gallery install haasan --as my-haasan   # ...under a different local name
```

An installed set behaves exactly like one you created yourself — `shrutz gallery install` never changes your active set; switch to it afterward with `shrutz switch`.

---

## Menu Bar App

shrutz stays terminal-first — the CLI and `shrutz dash` remain the primary interface — but for anyone who'd rather not use a terminal at all, there's an optional native menu bar companion. It's a thin client: every action shells out to the real `shrutz` binary and every displayed value comes from its `--json` output, so it never duplicates the daemon's scheduling or wallpaper-apply logic.

```bash
shrutz menubar install
```

Builds the app (in `menubar/`, an Xcode project) and installs it to `~/Applications`. Ad-hoc signed — no Apple Developer account needed — requires Xcode. Gives you current wallpaper/timer status, next/prev/pause/resume, a sets switcher, daemon start/stop, weather status, a Creators Publish gallery browser with thumbnails, and a preferences window for the config tunables. See [`menubar/README.md`](menubar/README.md) for details.

Once installed, shrutz launches it for you — every time the daemon (re)starts (including the frequent automatic restarts from switching sets, editing config, or a weather-triggered switch), it checks whether `Shrutz.app` is already running and opens it in the background if not, so you never have to manually relaunch it yourself.

```bash
shrutz menubar uninstall
```

Asks `really?` to confirm, quits the app if it's running, and removes `~/Applications/Shrutz.app`. If you'd enabled "Launch at Login" from its Preferences, macOS may still show a stale Login Items entry afterward — remove it manually from System Settings → General → Login Items.

---

## Internals

| Component | What it does |
|---|---|
| `ioreg -c IOHIDSystem` | Reads `HIDIdleTime` from the kernel I/O Registry — nanoseconds since last HID input |
| `osascript` / System Events | Reads the active Space's current wallpaper and applies fast corrections |
| `Index.plist` | macOS wallpaper store — written on every switch to update all Space UUIDs simultaneously |
| `launchctl kickstart` | Restarts `com.apple.wallpaper.agent` so it re-reads the store across all Spaces |
| Space poll | Every tick: reads `picture of desktop 1`, compares to expected, corrects if mismatched |
| `launchd` | macOS init system (PID 1). Starts shrutz at login, restarts it if it exits |
| `state` file | Bash-sourceable key=value file. Persists index, timer, set, shuffle order, and weather state across reboots |
| `weather_map` file | Flat `condition=set` mapping file, edited via `shrutz weather map`/`unmap` |
| `SIGUSR1` / `SIGUSR2` | Signals sent by `next` / `prev` — wallpaper changes without touching the timer |
| `SIGHUP` | Signal sent by `pause` / `resume` — toggles the `PAUSED` flag in the running daemon |
| Fisher-Yates shuffle | Python one-liner generates a random permutation of image indices for shuffle mode |
| [Open-Meteo](https://open-meteo.com) | Free, no-key weather + geocoding API used by the weather feature |
| `http_get()` | The one HTTP entry point in the whole script — a thin python3 `urllib` wrapper, used by both weather and the gallery |

---

## Uninstall

shrutz uninstalls itself. You don't need to remember any paths.

**Remove the binary, keep your wallpapers:**

```bash
shrutz dieanddontcomeback
```

Asks `really?` — type anything containing `yes` to confirm. Stops the daemon and removes the binary. Your sets, state, and logs under `~/.local/lib/shrutz/` are left completely untouched.

**Full wipe — removes everything:**

```bash
shrutz dieanddontcomeback --ever
# or
shrutz dieanddontcomeback -e
```

Same prompt. On confirmation: stops the daemon, quits and removes the menu bar app if it's installed (`~/Applications/Shrutz.app`), removes the binary, the launchd plist, the man page, and the entire `~/.local/lib/shrutz/` tree including all your wallpaper sets. Also strips the `PATH` and `MANPATH` lines from your `.zshrc` and `.bashrc`.

There is no undo.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

---

## License

MIT