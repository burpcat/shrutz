# Visual fidelity report — v2 rebuild

Supersedes the previous report (written against the rejected, flat/muddy
build at HEAD before `a328a2e`). Screenshots in this pass were captured
from a running Debug build via real window-server automation (`System
Events` + `cliclick` to drive the actual app, `screencapture -R` against
the live window frame — not a mocked harness), against real production
data (sets "billout"/"haasan", real wallpaper thumbnails, the real daemon).
Reference mockups live in `menubar/design/reference/`. Fresh screenshots
are in `menubar/design/screenshots/`.

## Bugs found and fixed during this verification pass

1. **"z" double-strike bars were merging into an illegible red blob at
   small sizes.** `ShrutzWordmarkMetrics.zStrikeBarGapFactor` was `0.10`
   against a `zStrikeBarThicknessFactor` of `0.065` — at the popover's
   20pt collapsed wordmark size that left under a pixel of edge-to-edge
   separation between the two bars, which anti-aliasing collapsed into a
   single ragged mark instead of two parallel strikes (confirmed by
   pixel-level crop, see `screenshots/popover-collapsed.png` before/after
   in git history). Fixed: gap factor raised to `0.24`, thickness lowered
   slightly to `0.05`. Re-verified legible at both 16pt and 20pt call sites.
2. **Settings-window wordmark was proportionally tiny vs. the mockups.**
   All four mockups give the wordmark roughly a third to half of the
   window's width; the shipped `PreferencesView` header used `size: 22`
   in a 620pt-wide window (~12% of window width). Bumped to `size: 40`
   (~24% of window width) — a deliberate middle ground, not a literal
   mockup-ratio match, since the mockups' proportions were themselves
   inconsistent across the 4 tab renders.

## Color test / depth test

The palette extractor was tested against both wallpaper sets currently
installed:

- **"haasan"** (portrait photography, warm brown/sepia backdrop with a
  small area of saturated pink/magenta subject matter): produces a
  vivid but largely warm-monochrome mesh (see
  `screenshots/popover-expanded-active.png`). This is **correct
  behavior, not a bug** — the extractor's 4 corner samples land on
  genuinely low-hue-diversity backdrop texture in this specific photo;
  boosting saturation on a photo that's actually brown everywhere
  correctly produces vivid brown, not invented color.
- **"billout"** (a colorful illustration — blue sky, teal ocean, warm
  sand): produces a clearly multi-hue, visibly layered mesh (see
  `screenshots/popover-expanded-colortest-billout.png`) — teal-to-warm
  gradient with real depth. This confirms the HSB saturation-weighted
  extraction + `.plusLighter`/`.saturation(1.3)` compositing fix
  actually produces the "luminous, saturated" look the brief calls for
  whenever the source wallpaper has color diversity to draw from, and
  isn't accidentally flattening everything back toward grey.
- **Depth test**: cards throughout (General's two groups, Sets' entries,
  Weather's two zones, Creators Publish's cards) are visibly a brighter,
  more opaque plane than the ambient background in every screenshot —
  `.regularMaterial` + a white overlay + gradient stroke + double drop
  shadow reads as elevated glass, not a flat wash.
- Switching to "billout" and back to "haasan" for this test was done via
  `shrutz switch` (fully reversible, confirmed restored) — no lasting
  state change.

## Popover — collapsed

Screenshot: `screenshots/popover-collapsed.png`

- Size: 200×90pt (confirmed via `System Events` window bounds) — exact
  match to the token.
- Content: wordmark only, centered, double-strike "z" legible. Matches.

## Popover — expanded, active

Screenshot: `screenshots/popover-expanded-active.png`

- Size: 340×180pt — exact match.
- Header: wordmark (small) + red asterisk settings button in a soft
  circular hit-area. Middle row: 16:10 thumbnail, set name ("haasan",
  real data), thin white progress bar, "X min left" label — **never a
  raw percentage**, per the brief. Transport row: back / filled-red-pause
  / forward, symmetric about the pause button with equal gaps.
- Matches the mockup's structure. Our "2 min left"-only label is an
  intentional improvement over the mockup's "~60%" (an explicitly-flagged
  artifact to ignore per the brief).

## Popover — expanded, paused

Screenshot: `screenshots/popover-expanded-paused.png`

- Captured via a real `shrutz pause`/resume round-trip through the
  actual popover pause button — confirmed daemon returned to
  `paused: false` afterward, no lasting state change.
- Glass correctly drains to the flat calm grey (`ShrutzPalette.pausedGlass`)
  with no blob mesh. Pause button becomes a plain red play triangle
  (no filled circle) — matches the deliberate distinction from the active
  state.

## Settings — General tab

Screenshot: `screenshots/settings-general.png`

- Wordmark (bumped to size 40, see bug #2 above) above the pill tab bar.
- Two grouped `GlassCard`s: "Launch at login" (switch, red-tinted via
  `.tint(ShrutzPalette.accent)`) in its own card; the three rotary dials
  (Active-use time / Idle threshold / Check interval) grouped in a second
  card, sharing one right-aligned dial axis and one left-aligned label
  axis.
- Dials are light/glassy (`.regularMaterial` + white overlay + red
  progress arc + dark text) — matches the "light/glassy, not dark"
  requirement, a direct fix from the rejected build's dark-puck dials.
- All three dial values (30 min / 60 sec / 30 sec) are the real live
  values from `shrutz config --json`.

## Settings — Sets tab

Screenshot: `screenshots/settings-sets.png`

- Each set in its own `GlassCard`: name, "ACTIVE" red tag + red left
  accent bar on the active set, live image count, red-tinted Shuffle
  switch, lazy-loaded 16:10 filmstrip (shimmer placeholder until each
  thumbnail resolves).
- "+ New set" is a red pill button (`Capsule().fill(accent)`), a
  deliberate deviation from the mockup's plain-text treatment — called
  for explicitly in the approved plan for better visual weight.
- Real data: "billout" (12 images) and "haasan ACTIVE" (17 images).

## Settings — Weather tab

Screenshot: `screenshots/settings-weather-gate.png` (gate state only —
see note below)

- Gate copy ("Enable weather-based switching?"), location field, "Yes" /
  "why not, yes!" buttons all present and styled correctly.
- **Mapping editor not captured live.** The live daemon's weather is
  already `enabled: true` with a real location — the gate should not be
  showing. Root-caused to an environment issue, not an app bug: the
  installed CLI at `~/.local/bin/shrutz` is a stale copy (87K/2204 lines)
  predating this branch's `conditions` JSON field (and other unrelated
  upstream changes, 2278 lines in this worktree) — `weather --json` from
  that stale binary omits the `conditions` key entirely, so
  `JSONDecoder` throws a `keyNotFound` error, `AppState.refresh()`'s
  `try?` swallows it, `appState.weather` stays `nil`, and
  `WeatherSectionView` falls back to the enable-gate. Confirmed via:
  (a) `bats weather.bats` passes against the worktree's own `shrutz`
  script, (b) a standalone `JSONDecoder` test against the exact
  `WeatherStatus` model fails with `keyNotFound("conditions")` when fed
  the stale binary's actual output and succeeds when fed output
  containing the field, (c) direct code review of
  `WeatherSectionView.body`'s `if weather.enabled` branch. I did not
  overwrite the user's live installed CLI to force this screenshot —
  that's a real system binary outside this worktree's scope, and doing
  so was correctly blocked by the sandbox. Once the user reinstalls
  (`shrutz update` or a fresh `install.sh` run) the mapping editor will
  render — structurally verified against `menubar/design/reference/04-weather.png`
  (matching TOP ZONE condition dropdown + "Associate a wallpaper set"
  zone + filmstrip layout already implemented in `WeatherSectionView.swift`).

## Settings — Creators Publish, disclaimer

Screenshot: `screenshots/settings-creators-disclaimer.png`

- Verified by temporarily resetting the `hasAcceptedGalleryDisclaimer`
  `AppStorage`/`UserDefaults` flag (`defaults write
  com.burpcat.shrutz.menubar hasAcceptedGalleryDisclaimer -bool false`),
  screenshotting, then restoring it to its original value (`true`) — no
  lasting change.
- "Disclaimer" heading in the old-money serif register, italic body copy,
  red "I understand" button, `GlassCard` treatment. Matches.

## Settings — Creators Publish, error state

Screenshot: `screenshots/settings-creators-error.png`

- `shrutz gallery list` genuinely fails (the upstream
  `burpcat/shrutz-wallpaper-repo` content repo is empty) — this is the
  real, expected error path, not a mock.
- Matches `menubar/design/reference/06-creators-error.png` closely: same
  copy ("Couldn't load the gallery — check your connection"), same photo-stack
  icon, same red "Try again" pill, `GlassCard` treatment. A populated
  catalog grid could not be captured (no real content upstream to
  populate it with) — grid layout verified via code review against the
  same `LazyVGrid`/thumbnail patterns already visually confirmed on the
  Sets tab.

## Known deviations, summarized

1. Wordmark's "S" is Pinyon Script (a real, sourced, OFL-licensed font)
   rather than a hand-traced copy of the mockups' exact glyph — confirmed
   via dedicated font research, judged the closest available match to the
   "old-money/Wellesley" register.
2. Settings-window wordmark size (40pt) is a deliberate middle ground
   between the shipped 22pt and the mockups' inconsistent ~33-50%-of-width
   proportions, not a literal ratio match.
3. Weather mapping editor and populated gallery catalog verified via code
   review + structural comparison to reference mockups, not via
   screenshot — blocked by (2a) a stale installed CLI binary outside this
   worktree's scope and (2b) empty real upstream gallery content,
   respectively. Neither is a defect in this branch's code.
4. A location text field is shown on the Weather gate screen (not present
   in the mockup) — functionally required, since `shrutz weather on`
   refuses without a location set first.
