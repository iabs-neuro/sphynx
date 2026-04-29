# sphynx.app.CreatePresetApp

Single-window MATLAB app for building spatial presets for behavioral
video sessions. Outputs a `.mat` file in the legacy sphynx format with
`Options`, `Zones`, and `ArenaAndObjects` so it can be consumed by both
the legacy `BehaviorAnalyzer.m` and the new
`sphynx.pipeline.analyzeSession`.

Built on `uifigure` + `uigridlayout`. R2020a or newer required.

## Launch

```matlab
startup
sphynx.app.CreatePresetApp()
```

## Window layout

```
+---------------------------------------------------------------+
|                          [tabs]                               |
|  Create Preset  |  Analyze Session                            |
+---------------------------------------------------------------+
| 1. Load              |                                        |
| 2. Calibration       |          Preview                       |
| 3. Arena             |    (frame + arena +                    |
| 4. Objects           |     objects + zones)                   |
| 5. Zones             |                                        |
| 6. Save / Plot       |                                        |
|                      | [Next frame] [Frame N/M]               |
|                      | [Target ▼] [Step] [Left][Right][Up]... |
+---------------------------------------------------------------+
```

Left column: stacked panels with the preset-building workflow.
Right column: large live preview + frame navigation + transform
strip (move/rotate selected target).

## Workflow

1. **Load** — pick a project root (acts as the default starting
   directory for the other file dialogs), then choose:
   - Video file (`.mp4`, `.avi`, `.mov`)
   - Output dir (where presets and plots are saved, organized into
     subfolders per session)
   - Optional: existing preset to seed calibration values
2. **Calibration** — define pixels-per-cm by picking 4 reference
   points on the frame.
3. **Arena** — choose geometry (Polygon / Circle / Ellipse / O-maze)
   and click points on the frame.
4. **Objects** — add objects one at a time. Each Add Object pops a
   "Is it correct?" dialog with Yes / No (redo) / No (delete) so
   you can iterate without leaving stale masks on the preview.
5. **Zones** — pick a partitioning strategy and Preview / Add to set
   / Clear all. Multiple strategies can be combined (corners-walls-
   center + strips, for example). Object zones are automatically
   added when objects exist.
6. **Save / Plot** — Save preset writes
   `<output_dir>/<videobase>/<videobase>_Preset.mat` and also
   auto-saves a combined-layout PNG next to it. Make plot can save
   one PNG per zone in addition.

## Move / Rotate

Below the preview there is a transform strip:

- **Target** dropdown: Arena, Object1, Object2, ...
- **Step (px)**: pixel step for translation, or degrees for rotation
- **Left / Right / Up / Down**: translate selected target
- **Rot CCW / Rot CW**: rotate selected target around its centroid
- **Refit mask**: recompute the binary mask from the updated outline
  (you don't have to call this after every nudge — only once when
  the layout looks right, before Save preset)

Use this when loading an existing preset over a new video where
the camera shifted slightly: nudge the arena to align, then
Refit mask.

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
body-part choices) live in `sphynx.pipeline.defaultConfig` — they are
not stored in the preset.

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

The zones produced depend on the strategies you applied. Possible
names from `corners-walls-center`:

- `corners`              — corner regions inside the arena
- `walls`                — wall regions inside the arena (between corners)
- `walls_and_corners`    — union of walls and corners (inside arena)
- `center`               — interior beyond wall width
- `arena_realout`        — arena polygon inflated outward by wall width
- `walls_and_corners_realout` — walls+corners region INCLUDING the
  outside-wall ring (to absorb tracking jitter just outside arena)

From `circle-rings` (round arenas): `wall`, `middle1`, `middle2`, ...,
`center`. From `strips`: `strip1` ... `stripN`.

Object zones (added automatically when objects exist):

- `Object<N>Real`     — the object polygon itself
- `Object<N>RealOut`  — object area inflated by ObjectZoneWidthCm
- `Object<N>Out`      — the inflation ring only (surrounding zone)
- `ObjectAllReal`, `ObjectAllRealOut`, `ObjectAllOut` — combined
  (added automatically when 2 or more objects exist)

Point zones:

- `ArenaCorner1` ... `ArenaCornerN` — arena corner coordinates (Polygon)
- `Object<N>Center` — centroid of object N

### Output folder layout

```
<output_dir>/
  <videobase>/
    <videobase>_Preset.mat       # preset file
    <videobase>_layout.png       # combined layout (always)
    <videobase>_zone_<name>.png  # one per zone (only when "plot all zones")
```

## Color convention (preview & plots)

- Black line: arena boundary
- Green line: object boundary; orange thick line: currently selected
  object in the list
- Filled translucent regions with palette of 8 colors: zones (committed)
- Filled translucent regions in magenta: zones being previewed
  (not yet committed)

## Help

Each panel has an `INFO` button that opens a help dialog with the
specific instructions for that panel.

## See also

- `sphynx.preset.readArenaGeometry` — pure interactive geometry picker
  used by the app
- `sphynx.preset.buildZonesSquare` / `buildZonesCircle` — adapters
  over `sphynx.zones.classifySquare` / `classifyCircle`
- `sphynx.preset.buildObjectZones` — object zones builder
- `sphynx.pipeline.analyzeSession` — consumes the preset to compute
  behavioral acts
