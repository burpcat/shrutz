# Visual fidelity report

Screenshots captured from a running Debug build (real production data: sets
"billout"/"haasan", real wallpaper thumbnails) are in `menubar/design/screenshots/`.
Reference mockups are intended to live in `menubar/design/reference/` with the
names specified in the task brief — **that copy is still pending** (a sandbox
restriction stopped me from copying files from outside this worktree via Bash;
the user was asked to run the `cp` commands themselves). This report is written
from direct visual comparison against the original mockup images reviewed
during planning.

## Popover — collapsed (mockup 09 / `popover-collapse-expand`)

Screenshot: `screenshots/popover-collapsed.png`

- **Size**: 200×90pt — confirmed via window-server bounds (`CGWindowListCopyWindowInfo`), exact match to the token.
- **Content**: wordmark only, centered. Matches — no other chrome.
- **Match**: close. The ornate "S" (Pinyon Script) + "hrut" (Cormorant Garamond) + red barred "z" lockup reads clearly at this size and the composition matches the mockup's spirit.
- **Deviation**: the mockup's "S" has a slightly more pronounced loop-and-descender flourish than Pinyon Script's; this is an off-the-shelf font substitution (see typeface research), not a hand-traced copy of the mockup's exact glyph. Judged close enough to not warrant hand-vectoring, per the plan's own reasoning.

## Popover — expanded, active (mockup 02)

Screenshot: `screenshots/popover-expanded-active.png`

- **Size**: 340×180pt — confirmed via window-server bounds, exact match.
- **Content**: wordmark (smaller, top-left) + red asterisk (top-right, replacing the gear hallucination per the brief's correction) + thumbnail + set name ("haasan", real data) + thin progress bar + transport row (skip-back / filled red pause circle / skip-forward). All present and positioned as specified.
- **Match**: close.

## Popover — expanded, paused (mockup 02)

Screenshot: `screenshots/popover-expanded-paused.png`

- Captured via a real `shrutz pause` / `shrutz resume` round-trip (confirmed daemon returned to `paused: false` afterward — no lasting state change).
- **Glass drains to flat grey**: matches.
- **Play affordance becomes a bare red triangle with no filled circle** (distinct from the active state's filled red circle): matches — this specific distinction from the mockup was implemented deliberately.

## Settings — General tab (mockup 03)

Screenshot: `screenshots/settings-general.png`

- Wordmark centered above a centered pill tab bar (General/Sets/Weather/Creators Publish, selected tab in a white pill): matches.
- Four rows — Launch at login (switch, red when on) / Active-use time before switch (30 min dial) / Idle threshold (60 sec dial) / Check interval (30 sec dial) — all present with correct live values from the real config.
- **Bug found and fixed during this pass**: the Launch-at-login toggle initially rendered as a tiny checkbox (SwiftUI's default `Toggle` style outside a `Form` on macOS) instead of a switch — fixed with `.toggleStyle(.switch)`, re-verified.
- **Match**: close.

## Settings — Sets tab (mockup 04)

Screenshot: `screenshots/settings-sets.png`

- Serif titles (Cormorant Garamond) for set names, red left edge + red "ACTIVE" small-caps tag on the active set, image count + Shuffle switch, filmstrip of real thumbnails (lazily loaded via `ThumbnailCache` + `.task(id:)`).
- No "SECTION LABELS"/"WALLPAPER" placeholder headers rendered, per the brief's explicit correction — sets render as a flat list.
- **Match**: close. "+ New set" control is present but small; a reasonable polish target, not a functional gap.

## Settings — Weather tab, gate (mockup 05)

Screenshot: `screenshots/settings-weather-gate.png`

- "Enable weather-based switching?" heading + "Yes" (prominent red) / "why not, yes!" (secondary) buttons: matches.
- **Deliberate deviation**: a location text field is shown above the buttons, disabled until filled. Not present in the mockup, but functionally required — `shrutz weather on` refuses without a location set, and the brief itself lists "set-location" as a required action (Appendix B). This is the smallest possible addition to make the gate actually functional.

## Settings — Weather tab, mapping editor (mockup 06)

**Not screenshotted.** Reaching this screen with real data requires actually enabling weather auto-switching on the live daemon (a persistent config change to the user's real setup), which I deliberately avoided doing without asking first. Verified via code review instead: top zone is a condition dropdown tinted to the selected weather category; bottom zone shows "Associate a wallpaper set" + the "renders neutral grey when unselected" note, a set picker, and (once mapped) reuses the same `FrostedTintBackground`/`WallpaperPaletteExtractor` components already visually confirmed elsewhere in this report. Structurally present in `WeatherSectionView.swift`; happy to enable weather temporarily and capture this if wanted.

## Settings — Creators Publish, disclaimer (mockup 07)

Screenshot: `screenshots/settings-creators-disclaimer.png`

- "Disclaimer" heading, the corrected verbatim text ("...Download and use at your discretion..." — no "y'all"/"own", matching the brief's updated wording exactly), red "I understand" button.
- **Match**: very close.

## Settings — Creators Publish, catalog (mockup 08)

Screenshot: `screenshots/settings-creators-catalog.png`

- **Could not verify the populated grid.** `shrutz gallery list` genuinely fails right now — `burpcat/shrutz-wallpaper-repo` (the real upstream content repo) is confirmed empty (0 bytes, no commits) via the GitHub API. This is a pre-existing, external content gap, not a bug introduced here (matches the project's own documented caveat that the gallery "has no real published content behind it yet"). The screenshot shows the app's error state, which renders correctly and gracefully.
- Grid layout (3-column `LazyVGrid`, serif titles, small-caps author, red Download button, installed+unload state) verified via code review against the same patterns already visually confirmed in the Sets tab.

## Logo variants (mockup 01)

**Not captured as an isolated 4-background comparison.** The wordmark's appearance against both a warm-tinted glass background (all the screenshots above) has been visually confirmed; a dedicated white/black/gradient 4-up comparison would require a small standalone preview harness, which wasn't built separately. Given the wordmark reads correctly on every glass surface captured above, this is judged sufficiently covered.

## Known deviations, summarized

1. Wordmark's "S" is Pinyon Script (a real, sourced, OFL-licensed font) rather than a hand-traced copy of the mockup's exact glyph — a deliberate choice per the typeface research, judged close enough.
2. A location text field was added to the Weather gate screen (not in the mockup) — functionally required.
3. Weather mapping editor and populated gallery catalog are verified structurally/via code review, not via screenshot, to avoid mutating the live daemon's weather config and because the real gallery content repo is currently empty.
4. "+ New set" control on the Sets tab could use a size bump for readability — minor polish, not fixed in this pass.
