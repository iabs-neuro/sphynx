# sphynx.app.CreatePresetApp

Single-window MATLAB app for building spatial presets for behavioral
video sessions. Outputs a `.mat` file in the legacy sphynx format with
`Options`, `Zones`, and `ArenaAndObjects` so it can be consumed by both
the legacy `BehaviorAnalyzer.m` and the new
`sphynx.pipeline.analyzeSession`.

Built on `uifigure` + `uigridlayout`. R2020a or newer required.

> Status: v10 — production-ready for preset building.
> Backlog of planned improvements is in `TODO.md`.

## Launch

```matlab
startup
sphynx.app.CreatePresetApp()
```

The window opens maximized. Three tabs: **Create Preset** (this doc),
**Preprocess Tracking** (per-bodypart DLC preprocessing — see
section "Preprocess Tracking tab" below), and **Analyze Session**
(placeholder for future batch UI).

## Window layout

```
+--------------------------------------------------------------------+
|                          [Create Preset] [Analyze Session]         |
+--------------------------------------------------------------------+
| 1. Load                          |                                 |
| 2. Calibration                   |        Preview                  |
| 3. Arena                         |   (frame + arena outlines +     |
| 4. Objects                       |    object outlines +            |
| 5. Zones                         |    zone outlines)               |
| 6. Save                          |                                 |
|  (left column scrollable)        +---------------------------------+
|                                  | [Next frame] [Frame N/M]        |
|                                  | [Target ▾] [Step] (nav strip)   |
|                                  +---------------------------------+
|                                  | [Left][Right][Up][Down]         |
|                                  | [Rot ↺][Rot ↻]                  |
|                                  +---------------------------------+
|                                  |  Log (scrollable, last 500)     |
+--------------------------------------------------------------------+
```

The left column is wrapped in a `Scrollable` panel — when the window
is short, all panels stay readable, scrollbar appears.

## Color convention (buttons & overlays)

Buttons:
- **pale yellow** — geometry selectors (Polygon / Circle / Ellipse / O-maze)
- **pale rose**   — actions (Browse, Pick, Add, Save, etc.)
- **pale teal**   — `INFO` help buttons

Preview & saved plots:
- **black**           — arena boundary
- **green**           — object boundary
- **orange thick**    — currently selected object in the list
- **palette colors**  — committed zones (each zone gets its own color)
- **magenta tint**    — preview-only zones (not yet committed)

## Workflow

1. **Load** — pick a project root (default starting directory for
   subsequent dialogs), select Video, Output dir, optionally an
   existing preset to seed the calibration.
2. **Calibration** — click 4 reference points on the frame, type the
   real-world cm distances for the Y and X pairs, then **Compute**.
   The app shows pxl/cm separately for Y and X, plus the `kcorr`
   correction factor.
3. **Arena** — pick a geometry (Polygon / Circle / Ellipse / O-maze)
   and click points on the frame.
4. **Objects** — add objects one at a time. After each Add, an
   "Is it correct?" dialog (Yes / No (redo) / No (delete)) loops
   until the user confirms. Selected object highlights orange on
   the preview.
5. **Zones** — pick a strategy and **Preview** then **Add to set**.
   Multiple strategies stack. Object zones added automatically
   when objects exist. Zones are auto-cleared with a warning when
   geometry changes (move / rotate / rename / replace / new object)
   so committed zones never reflect stale geometry.
6. **Save** — writes the `.mat` to
   `<output_dir>/<videobase>/<videobase>_Preset.mat` and saves
   the combined-layout PNG next to it. If `plot all zones` is
   checked, also one PNG per individual zone.

## Move / Rotate

Below the preview:
- **Target** dropdown: `All` (arena + every object), `Arena`,
  `Object1`, `Object2`, ...
- **Step (px)** numeric field — pixels for translation, degrees
  for rotation.
- **Left / Right / Up / Down** translate the selected target.
- **Rot ↺ / Rot ↻** rotate around the target's centroid (CCW / CW).
  *Known issue: when target is `All`, each child rotates around
  its own centroid instead of a shared pivot. See `TODO.md` #6.*
- Masks are auto-recomputed from the (possibly transformed) outline
  on `Preview` and `Add to set` — no separate Refit button needed.

## Output: the preset file

`<videobase>_Preset.mat` contains three top-level structs.

### Options

```
Options.ExperimentType        : string (e.g. 'Novelty OF')
Options.pxl2sm                : float (pixels per cm, average)
Options.pxl2smY               : float (pixels per cm along Y)
Options.pxl2smX               : float (pixels per cm along X)
Options.x_kcorr               : float (X / Y correction factor)
Options.FrameRate             : Hz
Options.NumFrames             : int
Options.Height                : int (pixels)
Options.Width                 : int (pixels)
Options.ArenaGeometry         : 'Polygon' | 'Circle' | 'Ellipse' | 'O-maze'
Options.GoodVideoFrame        : H x W x 3 uint8 (the displayed frame)
Options.GoodVideoFrameGray    : H x W uint8
Options.ObjectsNumber         : int
Options.WallWidthCm           : float
Options.MiddleWidthCm         : float
Options.NumStrips             : int
Options.StripDirection        : 'horizontal' | 'vertical'
Options.ObjectZoneWidthCm     : float
```

Pipeline-side parameters (likelihood threshold, velocity thresholds,
body-part choices) live in `sphynx.pipeline.defaultConfig`, NOT in
the preset.

### ArenaAndObjects

A struct array. Element 1 is the arena. Subsequent elements are
objects. Each element:

```
type              : 'Arena' | 'Object1' | 'Object2' | ...
geometry          : 'Polygon' | 'Circle' | 'Ellipse' | 'O-maze'
maskfilled        : H x W single (1 inside, 0 outside)
border_x, border_y: dense polyline along the boundary
border_separate_x, _y : per-side boundaries (Polygon only); cell array
```

### Zones

A struct array. Each entry has:

```
name        : zone identifier (see below)
type        : 'area' | 'point'
maskfilled  : H x W logical (for 'area') OR 1x2 [x y] (for 'point')
```

Zones produced depend on the strategies you applied (you can stack
several).

**`corners-walls-center`** strategy (square / polygon arena):
- `corners`                    — corner regions inside the arena
- `walls`                      — wall segments inside the arena
- `walls_and_corners`          — union of walls + corners (inside)
- `center`                     — interior beyond wall width
- `arena_realout`              — arena polygon inflated outward by `wallW`
- `corners_realout`            — corners + outside-ring near corners
- `walls_realout`              — walls + outside-ring near walls (not corners)
- `walls_and_corners_realout`  — combined inside + outside ring

**`strips`** strategy:
- `strip1` ... `stripN`             — N equal strips inside arena
- `strip1_realout` ... `stripN_realout` — same N strips, computed
  on arena inflated outward by `wallW` (catches tracking jitter
  outside arena)

**`circle-rings`** strategy (round arenas):
- `wall`, `middle1`, `middle2`, ..., `center`

**`none`** strategy:
- `arena` (single zone covering the whole arena)

**Object zones** (added automatically when objects exist):
- `Object<N>Real`     — object polygon
- `Object<N>RealOut`  — object inflated by `ObjectZoneWidthCm`
- `Object<N>Out`      — the inflation ring only (surrounding zone)
- `ObjectAllReal`, `ObjectAllRealOut`, `ObjectAllOut` (when ≥2 objects)

**Point-type zones** (auto-added for layout introspection):
- `ArenaCorner1` ... `ArenaCornerN` — arena corner coordinates (Polygon)
- `Object<N>Center` — centroid of object N

### Output folder layout

```
<output_dir>/
  <videobase>/
    <videobase>_Preset.mat       # preset file (always)
    <videobase>_layout.png       # combined preview (always on Save)
    <videobase>_zone_<name>.png  # one per zone (when "plot all zones")
```

## Help inside the app

Each panel has an `INFO` button that opens a short help dialog with
panel-specific instructions. Long-form how-to is in
`user_guide_en.md` and `user_guide_ru.md`.

## Preprocess Tracking tab

Second tab. Built around `sphynx.app.PreprocessTabController`.

### Layout

```
+---------------------------------------------------------------------+
| 1. Loading                       | X(t) trace                       |
|   Root / DLC / Video / Preset    |                                  |
|                                  | Y(t) trace                       |
| 2. Per-part settings             |                                  |
|   uitable: thr/win/interp/smooth | likelihood histogram (red line   |
|   + Default this/all             |   = current threshold)           |
|   + Compute this/all             +----------------------------------+
|   + Auto: dropdown method/param  | < bodypart > [Load][log Y][Video]|
|     (otsu/knee/quantile/preset)  |                  Frame N/M       |
|                                  +----------------------------------+
| 3. Outlier filter                | Manual exclusion regions:        |
|   [x] velocity-jump max=50 cm/s  | [Add region] applies-to: [▾]     |
|   [ ] Hampel  win=7 sigma=3      | • region 1 (all)                 |
|   Kalman: Q=1e-2  noise=1.0      | • region 2 (nose)                |
|                                  +----------------------------------+
| 4. Save                          | Log (last 500 lines)             |
|   Output dir                     |                                  |
|   [x] save plots per body part   +----------------------------------+
|   [Save preprocessed]            | Video panel (toggle)             |
|                                  | <<  <  --slider--  >  >>         |
+---------------------------------------------------------------------+
```

### Pipeline order (locked)

```
1. likelihood < threshold      -> NaN
2. out-of-frame bounds         -> NaN
3. velocity-jump filter        -> NaN  (pre-interp; default ON)
4. Hampel filter               -> NaN  (pre-interp; default OFF)
5. manual exclusion regions    -> NaN  (pre-interp)
6. interpolateGaps             -> fill (pchip / linear / spline / makima)
7. ONE OF:
   a. smoothTrace              -> sgolay / movmean / movmedian / gaussian
   b. kalmanFilter2D           -> 2D constant-velocity Kalman (replaces 7a)
```

Outlier filters are pre-interpolation by design — smoothing flattens
single-frame jumps so they become invisible to a post-smooth detector.

### Settings storage

- **Per-experiment**: `<root>/<expName>_PreprocessSettings.mat` —
  per-part likelihood threshold, smoothing window, interpolation/smoothing
  method, NotFound% threshold, plus global outlier-filter flags. Reused
  across sessions of the same experiment.
- **Per-session**: `<outputDir>/<dlcBase>_Preprocessed.mat` — the actual
  raw/interp/smoothed traces, manual exclusion regions (per-session
  because they depend on camera angle), source paths.
- **Per-session plots** (optional): `<outputDir>/<dlcBase>_traces/<part>.png`
  — three-panel figure (X / Y / likelihood) with raw/interp/smoothed
  overlays.

### analyzeSession integration

When `<dlcBase>_Preprocessed.mat` sits next to the DLC csv, the next
call to `sphynx.pipeline.analyzeSession` consumes it and skips the
clean/interp/smooth stages. Schema mismatch (different bodyparts) falls
back to the legacy recompute path.

### Auto-threshold methods

`sphynx.preprocess.autoThreshold(likelihood, method, param)`:
- `'otsu'` — `multithresh` of the likelihood histogram
- `'knee'` — max-curvature point on the smoothed CDF
- `'quantile'` — quantile (default 0.05)
- `'preset'` — `'aggressive'` (0.99), `'moderate'` (0.95), `'lax'` (0.6)

In the GUI: Auto row in Block 2; the suggested threshold appears as a
red vertical line on the likelihood histogram of the current part.

### Manual exclusion regions

Click `[Add region]` → a frame appears (uses the preset's GoodVideoFrame).
Click vertices, double-click to commit. The region is attached to the
body part chosen in the dropdown next to the button (`'all'` or a
specific part name). Points inside the polygon are flagged as bad
before interpolation. Stored per-session.

### Embedded video viewer

Toggle `[Video]` in the switcher row → a 240px panel appears at the
bottom with the current frame and a red `+` at the active body-part's
(x, y). Slider + four step buttons drive `currentFrame`; a red playhead
appears on X(t) and Y(t) plots.

## See also

- `sphynx.preset.readArenaGeometry` — pure interactive geometry picker
- `sphynx.preset.buildZonesSquare` / `buildZonesCircle` — adapters
  over `sphynx.zones.classifySquare` / `classifyCircle`
- `sphynx.preset.buildObjectZones` — object-zone builder
- `sphynx.pipeline.analyzeSession` — consumes the preset to compute
  behavioral acts
- `TODO.md` (this folder) — backlog of planned improvements
