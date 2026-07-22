# Changelog

## v2.1.0

**Fixed `next` / `prev` / `pause` / `resume` latency.** The daemon's main loop blocked on a plain foreground `sleep`, which defers bash trap execution until the sleep finishes — so these commands could take up to `CHECK_EVERY` seconds (30s by default) to actually apply. The loop now backgrounds the sleep and `wait`s on it, so signals are handled immediately.

**Tightened `daemon_pid()`.** Its `pgrep` pattern is now anchored to end-of-string so it matches only the launchd-spawned daemon (invoked with no arguments), not any currently-running `shrutz` subcommand whose own argv happens to contain the same script path.

**Weather-based automatic wallpaper switching.** Set a location once (`shrutz weather location`, city name or lat,lon — geocoded via the free Open-Meteo API) and map weather conditions to your own wallpaper sets (`shrutz weather map <condition> <set>`). Once enabled (`shrutz weather on`), the daemon polls on its own schedule (`WEATHER_POLL_MINS`) and switches in-process — no daemon restart — when the mapped condition changes. A manual `shrutz switch` is respected until the underlying condition actually changes to a different mapped target.

**Creators Publish gallery.** `shrutz gallery list` / `shrutz gallery install <name>` browse and download wallpaper sets published by the developer, hosted as a JSON manifest on GitHub. A gallery-installed set behaves exactly like a locally-created one.

**Redesigned install flow.** A fresh install now prompts you to name your own first wallpaper set instead of force-seeding a fixed default — that name becomes `ACTIVE_SET` directly, with no separately-hardcoded name left to drift out of sync. The original `haasan` set is no longer bundled by default; it's available via the gallery. Also fixes an empty-set crash loop: the installer no longer loads the daemon until the active set actually has images.

**`--json` output** on `now`, `sets`, `status`, `stats`, `config`, and `weather`, for scripting or the new menu bar app.

**Swift menu bar companion app** (`shrutz menubar install`). shrutz stays terminal-first; this is an optional thin-client GUI for people who'd rather not use the CLI — current wallpaper/timer status, next/prev/pause/resume, a sets switcher, weather status, a gallery browser, and a preferences window, all driven by the CLI's `--json` output.

**`shrutz --version` / `-v`.** Prints the installed version from a new `VERSION` file.

## v2.0.0

**Wallpaper sets.** Images are now organised into named sets under `wallpapers/<set>/`. Use `shrutz switch <set>` to change pools instantly. The active-time counter is never reset by a switch — it always keeps ticking.

**Binary CLI.** shrutz is now a direct binary on `$PATH`. No shell function is injected into `.zshrc` or `.bashrc` (beyond the `PATH` export). Every subcommand — `next`, `switch`, `import`, `dash` — is a real binary invocation.

**`shrutz dieanddontcomeback [--ever|-e]`.** Self-uninstall command. Without flags: removes the binary after confirmation, leaving wallpaper sets and state intact. With `--ever` or `-e`: full wipe — binary, launchd agent, man page, all sets and state, and the installer's shell RC entries. Both modes prompt `really?` and require a response containing `yes` to proceed.

**`shrutz import <path> [--set <name>]`.** Copy images from a file or directory into a set. Deduplicates by filename. Refreshes the set's `__init__` image count automatically.

**`shrutz set create / delete / rename / info / shuffle`.** Full set lifecycle management. `create` optionally accepts a source path to import from in one shot. `delete` guards against deleting the active set and requires confirmation. `rename` patches `ACTIVE_SET` in state if the active set is renamed. `shuffle` toggles per-set random play order.

**`shrutz next` / `shrutz prev`.** Advance or retreat one wallpaper immediately via `SIGUSR1` / `SIGUSR2`. The active-time counter is not touched.

**`shrutz pause` / `shrutz resume`.** Freeze and unfreeze the active-time accumulator via `SIGHUP`. The daemon keeps running; only the timer stops.

**`shrutz now`.** Snapshot of current wallpaper, set, position, timer progress, and paused state.

**`shrutz dash`.** Live terminal dashboard. Refreshes every 5 seconds in an alternate screen buffer. Shows wallpaper, set, position, ASCII progress bar, timer, uptime, switch count, and last five history entries.

**`shrutz stats`.** Daemon uptime, total switches, set count, total image count, current timer.

**`shrutz history [n]`.** Last n wallpaper switches from the log formatted as a table. Defaults to 10.

**`shrutz config [key] [value]`.** View and edit tunables from the CLI without opening the script. Restarts the daemon on any change.

**`shrutz export <set> [dest]`.** Zip a set to a destination directory (default `~/Desktop`) for backup or sharing.

**`shrutz update`.** Pull the latest version from the recorded git repo and re-run the installer.

**Man page.** `man shrutz` works after installation. Covers every command, all tunables, the full file layout, signals, and examples.

**Shuffle mode.** Per-set Fisher-Yates shuffle. Generates a full random permutation before repeating. Persisted in state across reboots.

**`__init__` metadata.** Each set carries a plain-text metadata file recording its name, creation date, image count, and shuffle flag.

## v1.0.0

Initial release. Single flat `wallpapers/` directory. Active-time timer via `ioreg` `HIDIdleTime`. All-spaces wallpaper application via `Index.plist` write and `launchctl kickstart`. Space-poll mismatch correction via AppleScript. State persistence across reboots. `launchd` agent with `KeepAlive`. Shell function injected into `.zshrc` / `.bashrc` for `status`, `log`, `start`, `stop`.
