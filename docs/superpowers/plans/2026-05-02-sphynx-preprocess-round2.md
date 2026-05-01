# Preprocess round-2 — implementation plan

**Date:** 2026-05-02
**Branch:** `sphynx-GUI`
**Goal:** apply user feedback round on Preprocess + CreatePreset.

## Slices (in execution order)

### Slice A — cosmetics + quick fixes (Task #25)

Many small items in one slice (low code, high UX impact).

**Files modified:**
- `+sphynx/+app/PreprocessTabController.m`
- `+sphynx/+app/CreatePresetApp.m`
- `+sphynx/+preprocess/cleanBodyPart.m`
- `+sphynx/+preprocess/autoThreshold.m`
- `+sphynx/+preprocess/exportTracks.m`

**Changes:**
- LeftPanel column 380 → 760 px so per-part table fits without horizontal scroll.
- Block 4 Save panel: row heights bumped, button no longer half-cut.
- Block 1 Loading: append a wide `Load` button row at the bottom (full width). Remove `Load` from the right-side switcher row.
- Block 2 ↔ Block 3 swap (Outlier filter now above Per-part settings; Compute is the last action in the workflow).
- `autoThreshold`: clamp result at `0.4` minimum; if would-be lower, log a warning `Auto[<method>]: <part> -> floor 0.40 (suggested <raw>)` and use 0.4.
- `Auto all` iterates only `use=true` parts.
- INFO buttons added to Block 2 + Block 3 (small button with help dialog).
- `exportTracks`: filter out `use=false` and `status='NotFound'` parts before writing `_Preprocessed.mat` (those parts are entirely absent in the file, not just skipped downstream).
- Auto-scroll Log: investigate `scroll(uitextarea, 'bottom')` on R2020a; if not available, use `drawnow + jScrollBar = handle.JavaPeer` workaround as last resort. Test the cleanest form that survives R2020a.
- CreatePreset left column: wrap in a scrollable container so all panels stay reachable on shorter windows.
- Plot zoom preserved across recompute: capture `XLim`/`YLim` before refreshPreview, restore after, only invalidate on body-part switch or unit change.
- New table column `%manual` next to `%out`.
- `cleanBodyPart`: change bounds check from `< 0` to `< 1` on x and y (DLC pixel coords are positive reals; 0 is invalid).

### Slice B — units + start/end frame + go-to-frame (Task #26)

**Files modified:**
- `+sphynx/+app/PreprocessTabController.m`

**Changes:**
- Y axis: if preset is loaded with `pxl2sm`, plot in cm; else plot in px with a small "(no preset)" label.
- X axis: dropdown `frame / sec / min` in switcher row. Default `sec` if preset+frameRate available, else `frame`.
- Two numeric fields under preview: `from frame` and `to frame`. Default = whole range. Trims plot xlim only (Compute still processes everything).
- Video panel: `go to frame N` numeric input + button.

### Slice C — three curves on plots (Task #27)

**Files modified:**
- `+sphynx/+app/PreprocessTabController.m`

**Changes:**
- X(t) and Y(t) plots overlay all three: raw (blue), interp (orange), smoothed (green) — same colors as the saved per-part PNGs.
- Three `uicheckbox` toggles `[x] raw [x] interp [x] smoothed` next to the start/end frame fields.
- Default: all three on.

### Slice F — Hampel sec + manual regions UX (Task #28)

**Files modified:**
- `+sphynx/+app/PreprocessTabController.m`
- `+sphynx/+preprocess/applyPerPartSettings.m`

**Changes:**
- Block 3 Hampel: `win,s` field instead of `win` (samples). Convert via frameRate at apply time.
- Manual regions:
  - Diagnose & fix the listbox bug (region not appearing after Add). Suspect: drawpolygon in a temp figure inside a uifigure context may need explicit `figure(parentFig)` after wait.
  - `scope` dropdown (per Add region): `experiment` (default) | `session`.
  - Existing `experiment`-scope regions render semi-transparent on the frame canvas when user opens Add region (so misalignment is obvious).
  - Time-axis highlight: regions matching the current part shade their flagged frames on X(t)/Y(t) (gray hatched bands).
  - Toast/dialog after double-click: "Region added (N vertices, applies: <part>)."

### Slice H — drawpolygon in CreatePreset (Task #29)

**Files modified:**
- `+sphynx/+app/CreatePresetApp.m`
- (possibly) `+sphynx/+preset/readArenaGeometry.m`

**Changes:**
- Replace ginput-style `pickPoints` for arena and objects with `drawpolygon` (and `drawcircle`/`drawellipse` where applicable).
- Vertices draggable after placement (drawpolygon supports this out-of-the-box).
- Double-click commits.
- "Is it correct?" dialog still asked — but now the user has already had the chance to refine vertices.

### Slice E — standalone video window + play (Task #30)

**Files modified:**
- `+sphynx/+app/PreprocessTabController.m`
- New: `+sphynx/+app/PreprocessVideoWindow.m`

**Changes:**
- Replace embedded video panel with a standalone uifigure (PreprocessVideoWindow class).
- Layout: large axes + slider + frame-input + step buttons + play/pause/stop + speed dropdown (0.25x / 0.5x / 1x / 2x / 4x).
- Color settings panel: colormap dropdown (plasma / viridis / parula / jet / hsv / turbo) + per-part marker size slider.
- Toggle "show all parts" vs "show selected only".
- Raw point: open circle (size from settings, color from palette).
- Smoothed point: filled circle (same color, slightly smaller).
- Play loop driven by a MATLAB `timer` at `frameRate / speedMultiplier`. Sync plays the playhead on X(t)/Y(t) at each tick.
- Stop closes the timer and resets to start.

### Slice D — Synthetic Data tab (Task #31)

**Files modified:**
- `+sphynx/+app/CreatePresetApp.m`
- New: `+sphynx/+app/SyntheticDataTabController.m`
- New: `+sphynx/+preprocess/makeSyntheticDLC.m`

**Changes:**
- 4th tab "Synthetic Data" with controls: nFrames, nBodyparts, frame size (W/H), motion model (random walk / Ornstein-Uhlenbeck / circular), outlier injection (none / spikes / long-gap / poor-likelihood / mixed), seed, output dir.
- Save button writes a DLC-style CSV + a minimal `_Preset.mat` (only Width/Height/FrameRate/pxl2sm for downstream compatibility).
- Defaults: 6000 frames, 14 parts, 800x600, random walk, mixed outliers, seed 42.
- Preprocess Block 1: add a `Load synthetic` button next to `Browse DLC` that generates a default scenario in temp and loads it directly (no save needed).

## TODO (not in this plan)
- Multi-file mode → `docs/CreatePresetApp/TODO.md` #9. Deferred.
