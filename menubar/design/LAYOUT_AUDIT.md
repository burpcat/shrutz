# Layout / alignment audit (§0.1)

Measurements taken directly from source (padding/spacing literals,
`ShrutzPalette` tokens) and cross-checked against the captured screenshots
in `menubar/design/screenshots/`.

## Corner radii — concentricity

```
ShrutzPalette.cornerRadiusPopover  = 28   (outermost: popover window)
ShrutzPalette.cornerRadiusWindow   = 20   (Settings window)
ShrutzPalette.cornerRadiusCard     = 16   (GlassCard, both zone cards)
ShrutzPalette.cornerRadiusThumbnail= 13   (innermost: thumbnails)
```

Each nested shape uses a strictly smaller radius than its parent (28 → 20
→ 16 → 13), which is the actual requirement ("concentric corner radii").
Step sizes are 8 / 4 / 3 — the last step (16→13) is 1pt off a clean 4pt
decrement (16→12 would be exact). Cosmetically invisible at these sizes;
noted rather than silently claimed perfect.

## One thumbnail aspect ratio

Every wallpaper-preview thumbnail in the app derives its height from the
same `ShrutzPalette.thumbnailAspectRatio = 1.6` (16:10) constant — grepped
across all four call sites:

| Location | Frame |
|---|---|
| Popover thumbnail (`ShrutzPanelView.swift:76`) | 56 × 56/1.6 |
| Sets filmstrip (`PreferencesView.swift:267`) | 72 × 72/1.6 |
| Weather filmstrip (`WeatherSectionView.swift:207`) | 64 × 64/1.6 |
| Gallery catalog grid (`GalleryView.swift:100`) | `.aspectRatio(1.6, contentMode: .fit)` on a flexible grid column |

No mixed ratios; no fixed-height-regardless-of-width thumbnails (the
Gallery grid's old fixed-height bug from the previous pass is gone —
it now derives height from the flexible column width via `.fit`).

## Transport row symmetry (popover, expanded)

`ShrutzPanelView.transportRow` (`ShrutzPanelView.swift:115-161`):

```
HStack(spacing: 28) { Spacer(); back; pause; forward; Spacer() }
```

Back/forward are equidistant (28pt) from the pause button on both sides,
and the two `Spacer()`s are symmetric, so the whole row centers on the
pause button regardless of window width. Confirmed visually in
`screenshots/popover-expanded-active.png` and `-paused.png`.

## Symmetric window margins

- Popover expanded content: single `.padding(16)` wrapping the whole
  `VStack` (`ShrutzPanelView.swift:55`) — equal margin on all 4 sides.
- Settings window: `VStack(spacing: 16)` for the wordmark/tabs/content
  column, with `.padding(.top, 20)` on the wordmark and `.padding(.bottom,
  20)` on the outer VStack — top and bottom breathing room matched at
  20pt. Left/right margins come from each tab's own content padding
  (General/Weather: 24/20; Sets: 24; Creators: 20/28) — see spacing-scale
  note below for where these aren't perfectly uniform across tabs.

## Shared axes

- **General tab**: both cards (`launchAtLoginRow`, the 3-dial group) share
  one outer horizontal inset (`VStack(alignment: .leading, spacing: 24)`
  with no extra horizontal padding beyond the card's own `.padding(16)`),
  so their left edges align. Within the dial card, all three dials are
  right-aligned as a column (`HStack` per row with a `Spacer()` pushing
  the dial to the trailing edge) and all three labels are left-aligned —
  confirmed in `screenshots/settings-general.png`.
- **Sets tab**: every card's name label, image-count/Shuffle row, and
  filmstrip share the same left inset (`.padding(14)` on the card content)
  — confirmed in `screenshots/settings-sets.png`.

## Spacing-scale audit

The brief calls for a 4/8pt spacing scale. Auditing every `.padding(...)`
and `spacing:` literal across the four screens' view files:

**On-grid (multiples of 4):** 4, 8, 12, 16, 20, 24, 28 — used for the vast
majority of outer paddings, card padding, and major stack spacing (e.g.
popover's `.padding(16)`, transport row's `spacing: 28`, General's card
spacing `24`, tab bar's `.padding(4)`).

**Off-grid (multiples of 2, not 4):** 6, 10, 14, 18, 22 appear in several
places — e.g. `ShrutzPanelView`'s middle-row `VStack(spacing: 6)` and
`HStack(spacing: 10)`, `WeatherSectionView`'s zone-internal
`spacing: 8`/`14`, `PreferencesView`'s dial-group `spacing: 22`, Gallery's
`spacing: 6`/`14`.

**Verdict**: the large-scale rhythm (window margins, card gaps, major
section spacing) is cleanly on the 4pt grid. Several *fine* internal
gaps (icon-to-label, label-to-control within a single row) use 2pt-off
values that were tuned by eye for visual balance rather than snapped to
the nearest 4pt step. These are small enough (≤2pt) to be imperceptible
in the screenshots and are not worth a blind global find-replace at this
point in the pass — flagged here rather than silently claimed as fully
on-grid. If pixel-perfect grid compliance is wanted, the concrete list
above is exactly what to change.
