# shrutz

**A wallpaper rotation engine for macOS that only counts time you're actually at your computer.**

Most wallpaper rotators switch on a wall-clock timer — they'll cycle while you're asleep, away from your desk, or your laptop is closed. shrutz measures *active usage* instead. The timer only ticks when your keyboard and mouse are live. Walk away, and it freezes exactly where it left off. Come back, and it resumes.

Wallpapers are applied across every Mission Control Space simultaneously, not just the one currently on screen.

---

## How it works

shrutz runs as a background daemon via macOS `launchd`. Every 30 seconds it queries the kernel's I/O Registry (`ioreg`) for the `HIDIdleTime` value — the number of nanoseconds since your last keyboard or trackpad input. If that idle time is under 60 seconds, you're considered active, and 30 seconds are added to a running counter. Once the counter reaches 30 minutes of genuine active use, the wallpaper advances to the next image and the counter resets.

**Multi-space coverage.** When a wallpaper switch happens, shrutz writes the new path directly into `Index.plist` — the wallpaper store maintained by macOS's wallpaper agent at `~/Library/Application Support/com.apple.wallpaper/Store/`. The file is a binary plist keyed by Space UUID. Each Space entry holds a `Configuration` field which is itself a binary plist containing the image path. shrutz rewrites that field for every Space, every per-display override within each Space, and the `SystemDefault` fallback entry, then restarts the wallpaper agent via `launchctl kickstart` so it re-reads the store and propagates the change to all Mission Control Spaces simultaneously.

**Space polling.** Every 30 seconds while you're active, shrutz reads the wallpaper currently showing on the active Space via AppleScript and compares it to what it expects. If they don't match — because a Space missed a previous write, or the agent hadn't fully reloaded yet — it reapplies the correct wallpaper immediately via AppleScript. This is a fast local call with no plist write and no agent restart.

State (current wallpaper index and accumulated active time) is written to a plain text file on every tick, so a reboot mid-session doesn't lose your progress.

---

## Requirements

- macOS 14 Sonoma or later
- bash (ships with macOS)
- python3 (ships with macOS)
- No third-party dependencies

---

## Installation

Clone the repository and run the installer:

```bash
git clone https://github.com/yourusername/shrutz.git
cd shrutz
chmod +x shrutz install.sh
./install.sh
```

The installer will:

1. Create the `~/.local` directory layout
2. Install the script to `~/.local/bin/shrutz`
3. Register a `launchd` agent that starts automatically at login
4. Inject a `shrutz` shell function into your `.zshrc` or `.bashrc`

After installation, drop your wallpaper images into:

```
~/.local/lib/shrutz/wallpapers/
```

Supported formats: `.jpg`, `.jpeg`, `.png`, `.heic`, `.webp`

---

## Usage

Once installed, the `shrutz` shell function gives you quick access to everything:

```bash
shrutz status   # check if the daemon is running
shrutz log      # stream the live activity log
shrutz stop     # stop the daemon
shrutz start    # start it again
```

You may need to reload your shell once after installation for the function to be available:

```bash
source ~/.zshrc   # or ~/.bashrc
```

---

## File layout

shrutz follows the [XDG Base Directory](https://specifications.freedesktop.org/basedir-spec/latest/) convention, adapted for macOS. Everything lives under `~/.local` — nothing is scattered across system directories.

```
~/.local/
├── bin/
│   └── shrutz                          main executable
└── lib/
│   └── shrutz/
│       ├── wallpapers/                 your images go here
│       ├── state                       persisted index + active timer
│       ├── shrutz.log                  activity log
│       └── shrutz.err                  stderr / crash output
└── etc/
    └── launchd/
        └── local.shrutz.plist          launchd agent definition (source of truth)

~/Library/LaunchAgents/
└── local.shrutz.plist                  → symlink to ~/.local/etc/launchd/
```

`~/Library/LaunchAgents/` is where macOS reads login agents from. Rather than putting the plist there directly, shrutz keeps it in `~/.local/etc/launchd/` and symlinks it over. This means all your configuration stays in one place and is easy to back up, version-control, or move to a new machine.

---

## Configuration

Open `~/.local/bin/shrutz` in any text editor. The tunables are at the top of the file:

```bash
ACTIVE_MINS=30        # minutes of real use before switching
IDLE_THRESHOLD=60     # seconds without input → considered away
CHECK_EVERY=30        # polling interval in seconds
```

After editing, restart the daemon:

```bash
shrutz stop && shrutz start
```

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
| `state` file | Bash-sourceable key=value file. Persists index and active-time counter across reboots |

**How `Index.plist` is structured.** The file at `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist` is a binary plist with four top-level keys: `SystemDefault` (fallback for unassigned Spaces), `Spaces` (a dict keyed by Space UUID), `Displays` (top-level display overrides), and `AllSpacesAndDisplays` (idle/screensaver config, left untouched). The image path is not stored directly — it lives inside a `Configuration` field which is itself a binary plist of the form `{'type': 'imageFile', 'url': {'relative': 'file:///path/to/image'}}`. shrutz rewrites this blob for every Space and display entry, then restarts the wallpaper agent to apply.

---

## Uninstall

```bash
shrutz stop
rm ~/Library/LaunchAgents/local.shrutz.plist
rm -rf ~/.local/bin/shrutz ~/.local/lib/shrutz ~/.local/etc/launchd/local.shrutz.plist
```

Then remove the `shrutz()` function block from your `.zshrc` or `.bashrc`.

---

## License

MIT
