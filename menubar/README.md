# ShrutzMenuBar

A lightweight macOS menu bar companion for [shrutz](../README.md). shrutz stays
TUI-first — this app is a thin client for people who'd rather not use the
terminal: it shells out to the `shrutz` CLI for every action and reads its
`--json` output for status, exactly like the terminal dashboard (`shrutz
dash`) does with plain text. It never reimplements scheduling, idle
detection, or wallpaper-apply logic.

## Build

Either open `ShrutzMenuBar.xcodeproj` in Xcode and hit Run, or from the
terminal:

```bash
xcodebuild -project ShrutzMenuBar.xcodeproj -scheme ShrutzMenuBar -configuration Release build
```

Ad-hoc signed ("Sign to Run Locally") — no Apple Developer account needed.

Normally you won't do this by hand: `shrutz menubar install` (see the CLI's
own `--help`) builds this project and copies the result into
`~/Applications` for you.

## Project structure

- `project.yml` — [xcodegen](https://github.com/yonaskolb/XcodeGen) spec;
  the source of truth. Run `xcodegen generate` after editing it to
  regenerate `ShrutzMenuBar.xcodeproj`.
- `ShrutzMenuBar/AppState.swift` — the one place that talks to the CLI and
  holds published state for the views.
- `ShrutzMenuBar/Services/ShrutzCLI.swift` — `Process` wrapper. Always
  invokes `~/.local/bin/shrutz` by absolute path (a GUI app launched from
  Finder/Login Items never sources the `PATH` export install.sh adds to
  `.zshrc`/`.bashrc`).
- `ShrutzMenuBar/Services/StateWatcher.swift` — watches shrutz's state file
  for writes (near-instant updates whenever the daemon does anything) plus
  a slow poll, since daemon *liveness* is a launchd-level fact a file watch
  can't see.
- `ShrutzMenuBar/Services/LoginItemManager.swift` — `SMAppService`-based
  "Launch at Login" toggle.
- `ShrutzMenuBar/Models/ShrutzState.swift` — `Codable` structs matching the
  JSON shapes `shrutz now/sets/status/stats/config/weather --json` emit.
  Keep these in lockstep with the bash side if either changes.
- `ShrutzMenuBar/Views/` — `MenuContentView` (the dropdown), `PreferencesView`
  (General/Sets/Weather/Creators Publish tabs).

## Requirements

macOS 14 Sonoma+ (matches shrutz's own floor), Xcode 15+.
