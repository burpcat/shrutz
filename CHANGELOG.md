# Changelog

## v2.5.0

**Menu bar app: rebuilt to match the approved mockups exactly.** A first redesign pass missed the mark visually — this pass rebuilds the popover, wordmark, and every Settings tab against nine approved mockups, with a screenshot-by-screenshot fidelity check against them (see `menubar/design/FIDELITY.md`). Highlights: the popover is now a two-state card (a ~200×90 wordmark-only collapsed tile that spring-expands to a ~340×180 now-playing view on click), the wordmark is a real ornate script "S" (Pinyon Script, OFL) + plain serif "hrut" + barred red "z" instead of a hand-drawn approximation, the ambient glass tint now samples wallpaper colors spatially (by quadrant/center) instead of by frequency so it reads as a genuine multi-tone mesh instead of one muddy color, every accent is the same red (`#E5342B`, no blue anywhere), Sets/Creators Publish content uses Cormorant Garamond with its true small-caps sibling for author/count labels, and "Launch at login" now mirrors the daemon's own launchd registration (new `shrutz autostart on|off`) instead of a separate app-only login item, so the app and daemon truly start together. Also fixes a real bug found via user report: the Settings window could render completely blank, because it checked `window.contentView == nil` to decide whether to attach content — a freshly-created `NSWindow` is never actually nil there, so the real view was never attached.

**`shrutz autostart on|off|status`.** Enables/disables the daemon's LaunchAgent starting at login (`RunAtLoad`), separate from `start`/`stop` (which only affect the current session). Reported in `status --json` as `autostart_enabled`.

## v2.4.1

**Fixed `shrutz update` printing garbled output/errors on its own run.** `install.sh` overwrote `~/.local/bin/shrutz` in place with `cp` — since `shrutz update` runs *from* that very file, the currently-executing process could read misaligned data from the file while it was being rewritten out from under it, producing spurious "command not found"/syntax errors in that one invocation's tail output (the file on disk was always written correctly; only the live update run's own terminal output was affected). Now writes to a temp file in the same directory and atomically renames it into place instead.

## v2.4.0

**Menu bar app: ground-up visual and interaction redesign.** The dropdown is now a compact "now-playing"-style frosted card, tinted live from the current wallpaper's own colors (a native, cheap dominant-color extraction — re-tints on switch, settles to a calm grey while paused). Content is deliberately minimal: the "Shrutz" wordmark (with a hand-drawn crossed z, matching the brand mark), a settings button, and playback controls — no status text, no set picker, no other chrome. Typography moves to a bundled old-style serif (Cormorant Garamond) for headings/wordmark and a companion sans (Libre Franklin) for dense UI, both OFL and embedded in the app bundle. Settings gained: an always-on-top window (fixing a bug where it could open behind the frontmost app), a tactile rotary dial for every duration setting (with an info popover explaining each one), an editorial Sets browser with lazily-loaded, bounded, cancellable thumbnails, a two-step Weather flow (an enable prompt, then a weather-tinted condition-to-set mapping editor), a two-step Creators Publish flow (a disclaimer, then a gallery styled like the Sets tab, with the ability to unload installed sets), and a menu-bar-icon hide toggle (recoverable by relaunching the app). The app and daemon now start each other: an installed menu bar app launches automatically whenever the daemon starts and it isn't already running, and the app itself quits shortly after the daemon has been genuinely stopped (debounced so a normal restart-on-config-change never triggers it).

**`shrutz sets --json` now includes `image_paths`.** An array of every image's absolute path in the set, in the same order/count as the existing `images` field — powers the menu bar app's lazy thumbnail grid.

**`shrutz weather --json` now includes `mappings`.** The full condition→set mapping table as structured data (previously only available as human-readable text), so the menu bar app can render and edit it directly.

**`shrutz set delete` gained `-y`/`--yes`.** Skips the interactive confirmation prompt, for scripted or GUI-driven callers that provide their own confirmation.

## v2.3.1

**`shrutz dieanddontcomeback --ever` now also removes the menu bar app.** The full wipe previously left `~/Applications/Shrutz.app` behind entirely untouched. It now quits and removes it too (sharing the same logic `menubar uninstall` uses), with the same note about a possible stale Login Items entry.

## v2.3.0

**`shrutz menubar uninstall`.** Counterpart to `shrutz menubar install` — prompts `really?`, quits the app if it's running, and removes `~/Applications/Shrutz.app`. Reports cleanly if the app isn't installed rather than prompting for nothing to do. Notes that a "Launch at Login" registration may leave a stale Login Items entry macOS itself has no CLI-triggerable way to remove.

## v2.2.0

**Menu bar app rebranded and redesigned as "Shrutz."** The app now builds and displays as `Shrutz.app` everywhere (Activity Monitor, Finder, the system About panel) instead of the old lowercase `shrutz` / `ShrutzMenuBar.app`, with a real app icon and logo mark. The dropdown is now a custom-drawn card (a `MenuBarExtra` in `.window` style) matching a cream/navy design — logo header, a "Wallpaper Set" picker, a playback row, and an overflow menu for daemon control / the terminal dashboard / About / Quit — instead of a flat native menu. No behavior changed: every control still calls the same CLI commands as before.

**Creators Publish now points at a dedicated content repo.** The gallery manifest fetch (and the manifest's own thumbnail/download URLs) now point at `burpcat/shrutz-wallpaper-repo` instead of this code repo, matching the single-source-of-truth design the feature was always meant to have.

**Fixed `shrutz menubar install`.** The installer still looked for the old `ShrutzMenuBar.app` product name — updated to match the app's new `Shrutz.app` product name so the documented install path works again.

## v2.1.1

**Fixed `next` / `prev` only updating the active Space.** A previous hotfix had `_sig_next`/`_sig_prev` apply the new wallpaper to only the frontmost Space, relying on the ~30s space-poll loop to correct every other Space. They now call the same all-spaces application path (`Index.plist` write + wallpaper agent reload) already used by `switch` and weather auto-switching, so every Space updates together immediately instead of drifting until the next poll.

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
