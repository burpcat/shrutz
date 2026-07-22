# shrutz — project context for Claude

This document is written to stand on its own. It's meant to be read either by Claude Code working inside this repository (where it can also go read the actual source) or by Claude on the web, pasted into a Project's knowledge files with no repository access at all — in that second case, whatever is written here *is* the entire ground truth available. Every mechanism below is explained in enough detail to reason about concretely, not just pointed at.

Use this to think about new features, evaluate whether an idea fits the product's shape, or orient yourself before touching the code. It is not a user manual (that's `README.md`) and not a command reference (that's the `shrutz.1` man page) — it's the builder's mental model: what the product does, how it actually works underneath, what conventions its code follows, and what's still rough around the edges.

---

## 1. What shrutz is, and its load-bearing philosophy

shrutz is a macOS wallpaper rotation tool with one distinguishing idea: it rotates based on **active-use time**, not wall-clock time. Most wallpaper rotators cycle every N minutes regardless of whether you're at your computer — shrutz's timer only advances while your keyboard/mouse have been active recently, and freezes the moment you walk away, resuming exactly where it left off when you come back.

Everything else in the product has grown outward from that core idea: named wallpaper "sets" you can curate and switch between, weather-driven automatic set-switching, a small marketplace-style gallery for sharing sets, a scripting-friendly JSON API, and an optional GUI. None of that changes the core premise — active-time is still the only thing that advances the rotation clock.

Design values worth defaulting to when thinking about changes:
- **Single self-contained bash script.** The entire CLI and background daemon is one ~2100-line file called `shrutz`. There's no build step, no compiled artifact, no `src/` directory to navigate — the script *is* the source. This is a deliberate simplicity choice, not an oversight; don't propose splitting it into multiple files or introducing a build/bundling step without a very strong reason.
- **Zero third-party software dependencies.** Only bash and python3 are required, both of which ship with macOS. Python3 is used as a "do real work" escape hatch (JSON/plist parsing, zip extraction, network calls) rather than adding `jq`, `curl`, or similar. Any new feature that needs structured-data handling should follow this same pattern rather than introducing a new dependency.
- **Network access is opt-in and narrow.** For most of its life shrutz made zero network calls. Two features now do — weather and the content gallery — and both share one HTTP helper function, only ever calling out when the user has actually turned that feature on and is actively using it. Nothing phones home by default.
- **macOS-only, and deeply so.** launchd (process supervision), `ioreg` (idle detection), AppleScript/`osascript` and a direct binary-plist rewrite (wallpaper application), and macOS's Login Item API are all load-bearing integrations, not incidental. Any feature idea should assume this is a macOS-native tool, not a cross-platform one.
- **Terminal-first, even with a GUI available.** A native menu bar companion app exists, but it is explicitly a thin, optional front-end for people who don't want to use a terminal. The CLI and its terminal dashboard (`shrutz dash`) remain the primary, authoritative interface.

---

## 2. The product today, at a glance

Everything below already exists and works. Scan this before proposing something new, so ideas build on the current surface rather than re-proposing it:

- **Active-time wallpaper rotation** across every macOS Mission Control Space simultaneously, with idle detection so time away from the computer doesn't count.
- **Named wallpaper sets** — create, delete, rename, inspect, switch between, import images into, export as a shareable zip. One set active at a time; switching sets never resets the active-time clock.
- **Shuffle mode** per set — a random play order that covers every image before repeating.
- **Manual playback controls** — skip to next/previous image instantly (independent of the timer), pause/resume the timer, a live-updating terminal dashboard.
- **Weather-based automatic switching** — set a location once, map weather conditions (clear/cloudy/fog/rain/snow/storm/night) to your own sets, and the daemon switches automatically as the weather changes, on its own polling schedule.
- **Creators Publish gallery** — browse and download wallpaper sets published by the developer from a small hosted catalog, without any of them being force-installed by default.
- **A menu bar companion app** (macOS, Swift/SwiftUI) — an optional native GUI alternative to the terminal for people who don't want to use the CLI directly.
- **Scripting support** — a `--json` flag on the main status-reporting commands, so any of this can be driven or observed programmatically (this is also exactly how the menu bar app talks to the CLI).
- **Self-update and self-uninstall** — `shrutz update` pulls the latest version from the recorded git checkout and reinstalls; `shrutz dieanddontcomeback` removes itself (with a "keep my wallpapers" soft mode and a "wipe everything" full mode).

---

## 3. Repo map

```
shrutz              the entire CLI + background daemon — one bash script (~2100 lines)
install.sh           one-shot/idempotent installer — deploys shrutz, seeds state, registers the daemon
shrutz.1             man page (troff)
shrutz.bats          core CLI test suite (bats-core)
install.bats         install-flow test suite
weather.bats         weather feature test suite
gallery.bats         gallery feature test suite
json.bats            --json output test suite
gallery/             the Creators Publish content catalog
  manifest.json        the JSON catalog of downloadable sets
  README.md             how a developer publishes a new set into the catalog
menubar/             the Swift menu bar companion app (a full Xcode project, xcodegen-managed)
README.md            user-facing usage documentation
CHANGELOG.md         version history
VERSION              single-line current version string, installed alongside the binary
.github/workflows/   CI (see caveats, §9 — currently stale relative to how the last merge happened)
```

There is no `src/` directory and no build artifacts to check in — `shrutz` itself is both the source and the thing that gets copied to `~/.local/bin/shrutz` at install time, unmodified.

---

## 4. How the one script plays two roles

The exact same file is both the daemon and the CLI, distinguished purely by how it's invoked. The very last thing in the file is a dispatch statement keyed on the first argument: if there are no arguments at all, it falls into the daemon's main loop; if there's a subcommand, it routes to the matching handler function and exits. launchd (macOS's process supervisor) is configured to invoke the script with **no arguments**, which is exactly what makes it start the background daemon at login; a person typing `shrutz next` in a terminal is a completely separate, short-lived process invocation of the same file that sends a signal to the already-running daemon and exits immediately.

The file is organized into six clearly-marked sections, in this order: shared utilities (logging, state persistence, small helpers used everywhere), daemon internals (idle detection, the two ways a wallpaper actually gets applied), weather (the condition-fetching and bucketing logic), the daemon's main loop itself, all of the CLI command handlers (by far the largest section), and finally the dispatch statement described above.

---

## 5. The active-time rotation model

This is the mechanism everything else sits on top of, so it's worth understanding precisely:

**Idle detection.** The daemon reads a kernel-level idle-time value (via macOS's I/O Registry) that reports nanoseconds since the last keyboard or trackpad/mouse input, converts it to seconds. On a fixed tick interval (30 seconds by default, configurable), if that idle time is under a threshold (60 seconds by default), the user is considered "active" and the tick interval's worth of seconds gets added to a running active-time counter. Once that counter crosses a configured number of minutes (30 by default) of genuine active use, the wallpaper advances to the next image and the counter resets to zero. If the user has been idle longer than the threshold, or the rotation is explicitly paused, no time accumulates at all — walking away truly freezes progress rather than merely slowing it.

**Applying the wallpaper — two different paths, deliberately.** macOS keeps a separate "current wallpaper" record for every Mission Control Space (virtual desktop) and every physical display, in a binary property-list file maintained by its own wallpaper background agent. For an actual rotation advance, shrutz directly rewrites that store — patching every Space's entry, every per-display override, and the system-wide default — then restarts the wallpaper agent so it picks up the change everywhere at once. That's the "real" switch. Separately, on every single tick while the user is active, shrutz does a much cheaper check: it asks (via AppleScript) what wallpaper the *currently visible* Space thinks it has, and if that doesn't match what shrutz expects (because a previous write was missed, or the agent hadn't fully reloaded), it corrects just that one visible Space instantly via AppleScript, without touching the full plist rewrite. The same fast AppleScript-only path is also used for the instant feedback when a user manually skips to the next/previous image, since in that case only the currently-visible Space needs to change immediately — the tick-based correction pass will catch up any other Space within one cycle.

**Sets and shuffle.** Wallpaper images live in named subdirectories, each with its own small metadata file recording its name, creation date, image count, and whether shuffle is on. Exactly one set is "active" at a time; switching which set is active changes the pool of images immediately but explicitly does **not** reset the active-time counter — the clock is a property of *time spent using the computer*, not of any particular set. When shuffle is enabled for a set, the daemon generates a full random permutation covering every image before any repeat (a Fisher-Yates shuffle), and persists that play order so a reboot mid-shuffle doesn't restart it from scratch.

**One shared "activate a set" primitive, two callers with different needs.** There's a single internal function responsible for "load this set's images, resolve its shuffle state if any, and apply the resulting wallpaper" — used in two places that need subtly different behavior. When the daemon itself starts up (including every time it's restarted), it needs to *resume* exactly where a previous run left off if that's still valid — same image index, same shuffle order — rather than starting over. When something switches to a *different* set on purpose (whether a person typing a switch command, or the weather feature deciding to switch automatically), it should always start that set fresh at its first image. The same underlying function handles both cases via a mode flag, so the "rebuild the image list, figure out shuffle state, apply the wallpaper" logic only exists once. One more distinction matters here: a person explicitly switching sets from the terminal is a *separate, short-lived process* — it updates the persisted state and then signals the long-running daemon to restart (which macOS's process supervisor immediately relaunches, now reading the freshly-updated state). The weather feature, by contrast, makes its switching decision *from inside* the already-running daemon process itself, so it must not use that restart trick — restarting the very process that's making the decision would be redundant and racy. It calls the shared "activate a set" logic directly, in-process, instead.

---

## 6. Command surface

Every command below is a first-argument dispatch to a specific handler inside the one script. Grouped by category:

**Daemon control** — check whether the background daemon is running and its process ID; start it; stop it; stream its live activity log; pull the latest version from wherever it was originally cloned from and reinstall; print the installed version.

**Playback** — show the current wallpaper, active set, position, and time remaining until the next switch; skip forward or backward one image immediately without touching the timer; freeze/unfreeze the active-time counter; open a live full-screen terminal dashboard.

**Sets** — list every set; create one (optionally importing images from a folder in the same step); delete one (refusing to delete whichever is currently active); rename one; show detailed info about one; toggle shuffle for one; switch which one is active; import images into a set; export a set as a zip archive suitable for backup or for publishing to the gallery.

**Creators Publish (gallery)** — list the sets currently published in the hosted catalog, noting which are already installed locally; download and install one, optionally under a different local name.

**Weather** — show current weather-automation status (enabled or not, configured location, last observed condition, the condition→set mapping table); turn automatic switching on or off; set the location (by city name or by coordinates); add or remove a condition→set mapping; force an immediate weather check right now instead of waiting for the next scheduled poll.

**Info & scripting** — daemon uptime and total switch counts; a table of the last N wallpaper switches; view or change the handful of tunable numbers (how many minutes of active use trigger a switch, the idle threshold, the poll interval, the weather-check interval); most of the status-reporting commands above additionally accept a flag that makes them print machine-readable JSON instead of human text.

**Menu bar app** — build the optional Swift companion app from source and install it.

**Uninstall** — remove just the installed binary (leaving all wallpapers and settings untouched), or wipe everything shrutz ever created on the machine, each behind an explicit confirmation prompt.

---

## 7. Feature deep-dives

**Weather auto-switching.** A user sets a location exactly once — either a city name (which gets resolved to coordinates via a free geocoding service) or raw coordinates directly. They then map whichever weather conditions they care about to their own wallpaper sets (not every condition needs a mapping; unmapped ones are simply ignored). Once turned on, the daemon polls a free weather API on its own schedule (independent of the tick-based active-time loop) and buckets the response's numeric weather code into one of seven categories: clear, cloudy, fog, rain, snow, storm, or night. The "night" category is a special override that only ever replaces "clear" or "cloudy" after dark — severe weather (rain/snow/storm/fog) is shown as such regardless of time of day, since a storm is more salient information than the hour. To avoid fighting a person's own manual choices, the feature specifically remembers *the last set that weather itself chose*, separately from whatever set is currently active — so if someone manually switches to something unrelated, weather leaves it alone as long as the underlying condition hasn't actually changed to a *different* mapped target; once it does change, weather reasserts control. Every failure mode (no network, malformed response, an unmapped condition, a mapped set that's been deleted or emptied since) is handled by logging and quietly doing nothing — the background daemon must never crash over a transient network hiccup.

**Creators Publish gallery.** This is a lightweight content-distribution feature: a small JSON catalog file, hosted on GitHub, lists published wallpaper sets (name, author, description, image count, a thumbnail image, and a download link, plus an optional integrity checksum). Listing the catalog and downloading/installing an entry are both ordinary CLI commands. Before extracting a downloaded archive, the code validates that every single file inside it would land *inside* the intended destination directory — rejecting anything that tries to write outside of it — before extracting anything at all; this guards against a maliciously crafted archive using path traversal to write files elsewhere on the machine. The archive format a published set is expected to be in is exactly what the existing "export a set to a zip" command already produces, so publishing a set is literally: export it, upload the resulting zip somewhere, add one entry to the catalog file. A downloaded set becomes completely indistinguishable from one a person built by hand locally — installing from the gallery never touches which set is currently active; the person still switches to it explicitly afterward.

The catalog is fetched from exactly one place: a dedicated `burpcat/shrutz-wallpaper-repo` GitHub repository, entirely separate from this code repo. This is a deliberate single-source design, not an oversight — the maintainer is the sole publisher, pushes new sets there manually on their own schedule, and there is intentionally no automated publishing pipeline and no secondary/fallback content source "for resilience." Any change that introduces a second source or an automated push-to-gallery pipeline goes against this design.

**The shared network-fetch helper.** There is exactly one place in the entire script that makes an HTTP request, and both the weather feature and the gallery feature call it — nothing else in shrutz touches the network. It's a thin wrapper that shells out to a small python3 snippet, with a timeout, and is designed to be swapped out for a canned response during testing so none of the automated tests ever hit the real network.

**The JSON scripting interface.** The commands that report status (current wallpaper/timer state, the list of sets, whether the daemon is running, usage statistics, the current tunable values, weather status, the gallery catalog) each accept a flag that switches their output from human-readable text to machine-readable JSON. This exists specifically so other programs — most notably the menu bar app — can consume shrutz's state reliably instead of scraping text meant for a person to read. Wherever this JSON is produced, it's built using a real JSON-serialization library rather than assembled by hand, because set names and filenames are arbitrary user-chosen text that can contain characters (quotes, unicode, etc.) that would corrupt a hand-built string.

**The menu bar companion app.** This is a small, separate native macOS app (Swift/SwiftUI) that lives in its own subdirectory as a full Xcode project. Architecturally it is a strict thin client: it never reimplements any scheduling, idle-detection, or wallpaper-application logic itself. Every button it exposes shells out to the real installed CLI binary as a subprocess, and every piece of information it displays comes from that same binary's JSON output — there is a one-to-one correspondence between what the app can show and what the CLI's JSON flag exposes, deliberately, and its data model is explicitly written to be kept in lockstep with those JSON shapes (a change to one side without the matching change to the other is exactly the kind of bug this coupling should make obvious rather than silent). Because it always invokes the CLI by its full installed path rather than relying on a shell `PATH` variable — a background GUI app has no shell profile to source that PATH from — it works reliably regardless of how it was launched. To stay responsive without constantly re-invoking the CLI, it watches the daemon's small persisted state file directly for changes (which get rewritten on virtually every daemon action) as its primary signal, backed by an occasional slow poll to catch the one thing a file-watch can't see on its own: whether the daemon process is running at all. The app builds and runs without needing a paid Apple Developer account — it's signed only well enough to run on the machine that built it, which matches how the CLI itself is only ever built and copied locally rather than distributed as a signed release.

The app is branded end-to-end as "Shrutz" — product name, bundle display name, menu bar status item, and a system About panel all read "Shrutz," with a real app icon and logo mark (a custom glyph, not a generic system symbol). Its main dropdown is a custom-drawn card (a `MenuBarExtra` in `.window` style, not a native `.menu` dropdown), styled to a specific cream/navy palette, so it can hold a proper header, a styled "Wallpaper Set" picker, and a playback control row instead of a flat list of native menu items. Actions that don't fit that compact card (starting/stopping the daemon, opening the terminal dashboard, quitting the helper) live behind a small overflow control inside the same card rather than a separate native menu — the thin-client principle above still holds throughout: none of this visual layer changes what gets called or how.

**The install flow.** Running the installer for the very first time (detected by the absence of a previously-created settings file) prompts a person to name their own first wallpaper set — whatever they type becomes that set's directory name *and* the name recorded as currently active, from the exact same single value, with no separate hardcoded name anywhere else that could ever drift out of sync with it. This one-value-flows-everywhere design specifically closes an entire historical class of bugs this project used to have, where a default name baked into one part of the installer and a default name assumed by another part could disagree. Running the installer again later (to repair or upgrade an existing install) detects that the settings file already exists and skips this prompt entirely, leaving the existing active set untouched. One more safety detail: the installer will not start the background daemon at all if the resulting active set has zero images in it — starting a daemon with nothing to show would otherwise cause it to immediately exit and then get relaunched forever in a tight loop, since the process supervisor is configured to always restart it.

---

## 8. Conventions worth preserving in new work

- Errors go through one small shared "print a message and exit" helper, used consistently via guard clauses (check a condition, fail loudly with a clear message if it's not met) rather than deeply nested conditionals. The main script does not use bash's automatic-exit-on-error mode — failure handling is explicit throughout; the installer script, being a simpler one-shot linear process, does use automatic-exit-on-error.
- Any time real structured-data work is needed (parsing or producing JSON, reading or writing a binary property list, extracting a zip archive safely), the pattern is to shell out to an inline python3 snippet, passing inputs in via exported environment variables rather than interpolating them directly into a string — this avoids a whole class of quoting/injection bugs and is used consistently everywhere structured data is touched.
- Any new value that needs to persist across restarts gets added to both the "load defaults" step and the "write everything back out" step of the settings file's read/write logic, as a matching pair — and if it's free-form text that might contain spaces or punctuation, it needs to be safely quoted when written, unlike a couple of older plain fields that have a known (and not yet fixed) fragility around exactly that.
- New features get their own dedicated test file, following the same sandboxing convention every existing test file already uses: run everything against a throwaway fake home directory, and replace every macOS-specific command the tests would otherwise invoke for real (the process supervisor, process-finding, AppleScript, idle-time reporting) with tiny stand-in scripts earlier on the command search path — so no test run ever touches a real background process or a real desktop. Anything that would otherwise make a real network call gets the same treatment, swapped out for a canned response.
- The daemon's main loop deliberately does *not* use a plain blocking pause between ticks — it backgrounds that pause and explicitly waits on it instead. This is load-bearing: bash normally defers handling an incoming signal until whatever it's currently running in the foreground finishes, which would otherwise make commands like "skip to next image" or "pause" take up to a full tick interval to actually take effect instead of responding instantly.

---

## 9. Known caveats

- The CI workflow still triggers on pushes to an old, now-stale branch name and auto-merges that branch into the main branch — that is not how the most recent large feature merge actually reached the main branch (it went through an ordinary pull request from a differently-named branch instead). Treat the CI configuration as needing a fresh look rather than assuming it's validated and current.
- The gallery catalog currently has exactly one entry, and it's an intentional placeholder — no real image count, no integrity checksum, and no real download link behind it yet. The gallery feature itself is fully built and tested; it simply has no real published content behind it yet. The fetch URL now correctly points at the dedicated `burpcat/shrutz-wallpaper-repo` (previously it pointed at this code repo itself, which was a bug); the placeholder entry's own JSON still lives in this repo's `gallery/manifest.json` as a maintainer-facing template/reference, not as served content.
- The gallery catalog currently has exactly one entry, and it's an intentional placeholder — no real image count, no integrity checksum, and no real download link behind it yet. The gallery feature itself is fully built and tested; it simply has no real published content behind it yet.
- The menu bar app's Xcode project has no explicitly committed build "scheme" file — building it relies on Xcode's automatic scheme generation for its one target, which works but is worth knowing about if a build ever behaves unexpectedly.
- A `wallpapers` entry appears untracked in version control at the repo root even though it's meant to be ignored — this is because it's a symbolic link (pointing at the real wallpaper storage location) rather than a plain directory, and the ignore pattern in use only matches plain directories. Cosmetic, not a functional issue.

---

## 10. Quick reference: where would a change like this live?

- **A new CLI command** → follow the existing pattern used by the weather and gallery commands: a small top-level dispatcher function that routes to more specific handler functions, wired into the final dispatch statement, plus matching updates to the built-in help text, the man page, and the README.
- **Changing daemon/scheduling behavior** → the main daemon loop and the shared "activate a set" primitive described in §5.
- **A new thing that should persist across restarts** → the settings file's read/write pair, per the convention in §8.
- **A new network-touching feature** → reuse the single shared HTTP helper (§7); don't add a second way of making requests.
- **Anything the menu bar app should show or control** → add the corresponding JSON field/flag on the bash side first, then update the Swift app's matching data model and view — these two are meant to move together.
