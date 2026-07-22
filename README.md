# shrutz

![version](https://img.shields.io/badge/version-2.1.0-blue) ![license](https://img.shields.io/badge/license-MIT-green)

**A wallpaper rotation engine for macOS that only counts time you're actually at your computer.**

Most wallpaper rotators switch on a wall-clock timer — they'll cycle while you're asleep, away from your desk, or your laptop is closed. shrutz measures *active usage* instead. The timer only ticks when your keyboard and mouse are live. Walk away, and it freezes exactly where it left off. Come back, and it resumes.

Wallpapers are applied across every Mission Control Space simultaneously, not just the one currently on screen.

---

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
2. Prompt for a folder of wallpapers to import into the `default` set
3. Install the binary to `~/.local/bin/shrutz`
4. Register a `launchd` agent that starts automatically at login
5. Add `~/.local/bin` to your `PATH` and register the man page

The wallpaper prompt looks like this:

```
  Where are your wallpapers?
  Enter a folder path to import now, or press Enter to skip.

  Path (or Enter to skip): ~/Pictures/my-wallpapers/
  ✓  42 images imported, 0 skipped
```

Press Enter to skip and add images later with `shrutz import`. Supported formats: `.jpg`, `.jpeg`, `.png`, `.heic`, `.webp`

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
shrutz switch dark                       # switch active set
shrutz import ~/path/to/images/          # import into active set
shrutz import ~/path/ --set dark         # import into a specific set
shrutz export dark                       # zip a set to ~/Desktop

# Info & config
shrutz stats                            # uptime, switches, totals
shrutz history 20                       # last 20 wallpaper switches
shrutz config                           # show tunables
shrutz config ACTIVE_MINS 45            # change a tunable live
shrutz update                           # pull latest and reinstall
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
│       │   ├── default/                          default wallpaper set
│       │   │   ├── __init__                      set metadata
│       │   │   └── *.png / *.jpg / …             your images
│       │   └── <other-sets>/                     additional sets
│       ├── state                                 persisted runtime state
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
```

Each `config` call patches the script in-place and restarts the daemon immediately.

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
| `state` file | Bash-sourceable key=value file. Persists index, timer, set, shuffle order across reboots |
| `SIGUSR1` / `SIGUSR2` | Signals sent by `next` / `prev` — wallpaper changes without touching the timer |
| `SIGHUP` | Signal sent by `pause` / `resume` — toggles the `PAUSED` flag in the running daemon |
| Fisher-Yates shuffle | Python one-liner generates a random permutation of image indices for shuffle mode |

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

Same prompt. On confirmation: stops the daemon, removes the binary, the launchd plist, the man page, and the entire `~/.local/lib/shrutz/` tree including all your wallpaper sets. Also strips the `PATH` and `MANPATH` lines from your `.zshrc` and `.bashrc`.

There is no undo.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

---

## License

MIT