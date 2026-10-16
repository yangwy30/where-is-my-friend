# City Emblem Plinth Rebuild & Standardization (`scripts/emblem_plinth_rebuild`)

This directory contains the reproducible pipeline used to rebuild all 211 3D city emblems in `WhereIsMyFriend/Resources/Assets.xcassets/CityEmblems` from their pre-cleanup `@3x` masters at commit `728cbe3` (and commit `3cef555` for the 5 regional archetypes, plus the corrected Fukuoka Tower master in `masters/City_fukuoka.png`).

---

## Quick Start: Reproducing All 211 Emblems from `728cbe3`

First, install the `sharp` dependency once (or point `NODE_PATH` to an existing `node_modules` with `sharp`):

```bash
npm --prefix scripts/emblem_plinth_rebuild install
```

### Option A — Run Directly from Git History (`728cbe3` / `3cef555`)

From the repository root, run:

```bash
node scripts/emblem_plinth_rebuild/rebuild_plinths.mjs
```

This reads each `City_<name>@3x.png` directly via `git show 728cbe3:...` (and `3cef555` for the 5 `archetype_*` sets, plus `scripts/emblem_plinth_rebuild/masters/City_fukuoka.png` for `fukuoka`), cleans and reconstructs the 3D plinths, normalizes dimensions and baselines, and writes `@3x` (`512×512`), `@2x` (`341×341`), and `1x` (`170×170`) PNGs in-place.

### Option B — Extract `728cbe3` Originals to a Folder First, Then Rebuild

If you want to inspect the `728cbe3` source PNGs on disk before rebuilding:

```bash
# 1. Extract all 211 @3x masters from 728cbe3 (and 3cef555 / Fukuoka override) to /tmp/emblem_728cbe3
node scripts/emblem_plinth_rebuild/rebuild_plinths.mjs --extract-728cbe3 /tmp/emblem_728cbe3

# 2. Rebuild all 211 .imageset folders from /tmp/emblem_728cbe3
node scripts/emblem_plinth_rebuild/rebuild_plinths.mjs --orig-dir /tmp/emblem_728cbe3
```

### Rebuild Specific Cities Only

```bash
node scripts/emblem_plinth_rebuild/rebuild_plinths.mjs suzhou copenhagen tel_aviv
```

---

## Pipeline Overview

1. **Disconnected Speckle & Side-Glare Removal**
   - Connected components with `< 120` pixels (`alpha >= 8`) outside the solid plinth wall are stripped (`isSpeckle`), and any residual studio floor/corner overhang outside the horizontal plinth bounds `[xL, xR]` (`y >= yCorner - 120`, e.g., `suzhou` left speckles and `copenhagen` upper-left lip) is cleared.
2. **Bottom-Up Studio Floor & Crevice Scanner**
   - Scans upward from the bottom of each column (`y = 511 -> 0`) through low-chroma studio floor glare (`L >= 208, C <= 46`) and climbs through dark contact-shadow crevices or dark pedestal gaskets (`london`, `fukuoka`, `tokyo`) to locate the true bottom edge `yStop[x]` of the 3D plinth.
3. **Isometric Rounded-Square Plinth Contour Fitting**
   - Fits the analytical isometric V-curve with rounded front apex and side corner lift:
     $$y_V(x) = y_{\text{tip}} + c_A - \sqrt{(s \cdot |x - x_C|)^2 + c_A^2} - 8 u_{\text{side}}^2$$
   - Detects the vertical side walls `[xL, xR]` above the studio floor (`[yV(x) - 65, yV(x) - 14]`), stripping wide studio floor pads (`prague`, `milwaukee`, `lucerne`, `savannah`).
4. **Frosted-Acrylic / Light Plinth Wall Reconstruction**
   - Reverses prior white-keying holes (`A < 250`) inside the plinth wall (`y in [topPlinthY[x], yb]`) by compositing over studio white (`W_PLINTH = 246`), and repairs shadow-ink-tainted highlight holes on `tel_aviv` via warm-cream highlight restoration + 3-pass 2D neighborhood smoothing.
5. **Size, Centering & Baseline Standardization**
   - Scales each emblem to target plinth width `~368 px` (clamped to `bw <= 394 px`, `bh <= 446 px`), centers horizontally at `x = 256` (`|cx| <= 1 px`), and anchors the bottom baseline at `y = 475` (`bottomMargin = 36 px`, `topMargin >= 30 px`).

---

## Verification

Run the review scripts in `scripts/emblem_review/` to verify metrics and visual sheets:

```bash
# 1. Verify plinth bottom contour smoothness (210/211 emblems have jumps == 0)
NODE_PATH=/path/to/node_modules node scripts/emblem_review/jag.mjs \
  WhereIsMyFriend/Resources/Assets.xcassets/CityEmblems /tmp/jag_after.json

# 2. Verify bounding box, centering (|cx| <= 1), and baseline (bottomMargin == 36)
NODE_PATH=/path/to/node_modules node scripts/emblem_review/metrics.mjs \
  WhereIsMyFriend/Resources/Assets.xcassets/CityEmblems /tmp/metrics_after.json

# 3. Render Light + Dark mode contact sheets (sheet-1.png .. sheet-4.png)
NODE_PATH=/path/to/node_modules node scripts/emblem_review/sheet.mjs \
  WhereIsMyFriend/Resources/Assets.xcassets/CityEmblems /tmp/emblem_sheets
```
