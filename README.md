# shrutz

**A wallpaper rotation engine for macOS that only counts time you're actually at your computer.**

Most wallpaper rotators switch on a wall-clock timer — they'll cycle while you're asleep, away from your desk, or your laptop is closed. shrutz measures *active usage* instead. The timer only ticks when your keyboard and mouse are live. Walk away, and it freezes exactly where it left off. Come back, and it resumes.

Wallpapers are applied across every Mission Control Space, not just the one currently on screen.

---

## How it works

shrutz runs as a background daemon via macOS `launchd`. Every 30 seconds it queries the kernel's I/O Registry (`ioreg`) for the `HIDIdleTime` value — the number of nanoseconds since your last keyboard or trackpad input. If that idle time is under 60 seconds, you're considered active, and 30 seconds are added to a running counter. Once the counter reaches 30 minutes of genuine active use, the wallpaper advances to the next image and the counter resets.

**Multi-space coverage.** When a wallpaper switch happens, shrutz writes the new path into every row of the Dock's wallpaper database (`desktoppicture.db`) and restarts the Dock. The Dock re-reads the database on launch and propagates the change to every Mission Control Space simultaneously. This Dock restart takes roughly one second and only happens at the moment of a wallpaper change — not on every loop tick.

**Space polling.** Every 30 seconds while you're active, shrutz reads the wallpaper currently showing on the active Space via AppleScript and compares it to what it expects. If they don't match — because you switched to a Space that missed a previous update, or because you're on a macOS version where the database approach isn't available — it reapplies the correct wallpaper immediately. This correction is a fast AppleScript call with no Dock restart.

State (current wallpaper index and accumulated active time) is written to a plain text file on every tick, so a reboot mid-session doesn't lose your progress.

---

## Requirements

- macOS 12 Monterey or later
- bash (ships with macOS)
- sqlite3 (ships with macOS)
- No third-party dependencies

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
| `osascript` / System Events | Reads the active Space's current wallpaper and applies corrections instantly |
| `desktoppicture.db` | Dock's SQLite wallpaper database — written on every switch to propagate across all Spaces |
| Dock restart | Triggered once per wallpaper switch so the Dock re-reads the database |
| Space poll | Every tick: reads `picture of desktop 1`, compares to expected, corrects if mismatched |
| `launchd` | macOS init system (PID 1). Starts shrutz at login, restarts it if it exits |
| `state` file | Bash-sourceable key=value file. Persists index and active-time counter across reboots |

**macOS Sonoma / Sequoia note.** Apple changed the wallpaper storage backend in macOS 14. If the Dock database is absent or uses a different schema, shrutz logs the fallback and switches to applying wallpapers to the active Space only via AppleScript. The poll loop then acts as the cross-space correction mechanism — each Space gets the right wallpaper the moment you land on it.

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
