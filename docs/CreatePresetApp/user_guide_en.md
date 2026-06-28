# CreatePresetApp -- user guide (English)

Step-by-step walkthrough for building a spatial preset for one
behavioral video session.

## What's new since R20

- Tabs are now numbered in the title bar:
  1. Create Preset, 2. Preprocess Tracking, 3. Define Acts,
  4. Analyze Session, 5. Batch Analysis, 6. Make Output Table,
  7. Plot Data, 8. Preprocess Video, 9. Synthetic Data.
- Tab 2: two new buttons -- "Check another" (reuse current per-part
  settings on another DLC csv) and "Load preprocessed" (pull a saved
  `<exp>_PreprocessSettings.mat` onto the currently loaded DLC).
- Tab 3: the Barnes default-library button now loads 64 acts
  (nose_at_<hole> 1+19, body_at_<hole> 1+19, platform pair,
  mouse_inside_<hole> 1+19+1, nose_at_any_hole). The mouse_inside_*
  family requires a 2 s sustained run (per-act minDurationSec=2.0).
  Zone preview now refreshes on act selection.
- Tab 4: redesigned 2-row loader strip (Root / Preset / Video / DLC /
  Out dir on row 1; Preproc settings / Acts library on row 2). An
  acts-filter listbox is added on the left of the trajectory panel.
  "Render main video" checkbox now defaults ON. The info block on the
  rendered video is white text with a 1 px black outline at the
  top-left (no background plate); the frame counter is a yellow square
  (10% of frame height) top-right.
- Tab 5: session pairing accepts BOTH legacy DeepLabCut csvs
  (`...DLC_resnet50_...csv`) AND superanimal-topviewmouse csvs
  (`..._superanimal_topviewmouse_..csv`). Multi-digit mouse / day /
  trial IDs work (m23, m183, m5718, 12d_3t, ...).
- Tab 4 now reports Barnes-specific metrics in the session-stats
  header (TotalNoseHoleVisits, PrimaryErrors, TotalBodyHoleVisits,
  NumCheckedHoles, FirstCheckedHoleNumber, FirstCheckedHoleErrorDeg,
  MeanCheckedHoleErrorDeg, TargetHoleVisitOrder). Full definitions:
  see `docs/Barnes/metrics.md`.
- New repo-root file `sphynx_defaults.jsonc` -- single tab-organised
  defaults file auto-loaded by `sphynx.pipeline.defaultConfig`. Edit
  there to change defaults without touching code.

## Before you start

You need:
- The video file of your session (`.mp4`, `.avi`, `.mov`)
- A rough idea of one or two real-world reference distances on the
  arena (e.g., the inside length of a wall in cm)
- A folder to save outputs into

## 1. Open the app

```matlab
startup
sphynx.app.CreatePresetApp()
```

The window opens maximized with 9 numbered tabs (see "What's new"
list above). This guide focuses on **1. Create Preset** (used below)
and **2. Preprocess Tracking** (per-bodypart DLC preprocessing -- see
the dedicated section at the end of this guide). For the remaining
tabs (3 Define Acts through 9 Synthetic Data) see
`full_workflow_en.md`.

## 2. Block 1 — Load

Each row has a labeled **Browse** button on top and a short text
field showing the current path below it.

- **Project root** — default starting directory for the other file
  dialogs.
- **Video** — your session video. The first frame appears on the
  right in the Preview.
- **Output dir** — where presets and plots will be saved. The app
  auto-creates a subfolder named after your video.
- **Preset** (optional) — load an existing preset to seed
  calibration values.

## 3. Block 2 — Calibration

Convert pixels to cm using 4 reference points.

1. Type the real-world Y distance (cm) into **cm Y**.
2. Type the real-world X distance into **cm X**.
3. Click **Choose points** (red). A picture window opens.
4. Click 4 points in this order:
   - point 1 — top of vertical reference
   - point 2 — bottom of vertical reference
   - point 3 — left of horizontal reference
   - point 4 — right of horizontal reference

   The window auto-closes after the 4th click.
5. Click **Compute** (red). The app shows pxl/cm for both axes
   (`Y:`, `X:`), the average (`avg:`), and the X/Y correction factor
   (`kcorr:`). If `kcorr` is far from 1 (more than a few percent),
   re-check the click order.

Choose your **Exp** (Experiment type) from the dropdown.

## 4. Block 3 — Arena

1. Click one of the geometry buttons (yellow): **Polygon**, **Circle**,
   **Ellipse**, **O-maze**. The selected one stays toggled.
2. Click **Pick arena points** (red).
3. In the picture window, click points on the arena boundary, then
   press ENTER. The window auto-closes.
   - Polygon: click corners.
   - Circle: at least 3 points anywhere on the rim.
   - Ellipse: at least 5 points on the rim.
   - O-maze: 3+ points on the OUTER rim, ENTER, then 3+ points on
     the INNER rim, ENTER.

The arena outline appears in black on the Preview.

## 5. Block 4 — Objects

1. Click a geometry button (Polygon / Circle / Ellipse).
2. Click **+ Add** (red). Click points, ENTER.
3. A dialog asks: "Is Object1 correct?" — three options:
   - **Yes** — keep.
   - **No (redo)** — discards this object and re-opens the picker.
     The old mask is removed from the preview before you re-pick.
   - **No (delete)** — deletes without re-asking.

   The dialog keeps re-asking until you pick **Yes** or **No (delete)**.
4. To remove or change an existing object, select it in the list,
   then click **Remove**, **Replace**, or **Rename**.
   - **Remove** — deletes the selected object.
   - **Replace** — re-opens the picker for that object's mask
     (preserves its label).
   - **Rename** — opens an input dialog for a new label.

Selected object is highlighted in orange on the Preview.

## 6. Block 5 — Zones

You can stack multiple partitioning strategies — they accumulate.

1. Pick a **Strategy**:
   - `corners-walls-center` — square / polygon arenas.
     Set **Wall** (cm).
   - `strips` — N equal horizontal or vertical strips.
     Set **Strips** (count) and **Dir**.
   - `circle-rings` — round arenas. Set **Wall** and **Middle**.
   - `none` — no spatial subdivision.
2. If objects exist, set **Obj zone** (cm) — the inflation radius for
   the interaction zone around each object.
3. Click **Preview** to see the proposed partition (outlines shown in
   palette colors).
4. Click **Add to set** to commit them. The "Added: ..." label
   updates with the strategy tag (e.g. `corners-walls-center +
   strips_horizontal_3`).
5. **Clear** removes every committed zone.

Zones are auto-cleared (with a warning in the Log) whenever you
move / rotate / rename / replace / add an object — because committed
zones built off old geometry would be wrong.

## 7. Block 6 — Save

- **Save preset** (red) writes
  `<output_dir>/<videobase>/<videobase>_Preset.mat` AND saves the
  combined-layout PNG (`<videobase>_layout.png`) next to it.
- If **plot all zones** is checked, it also saves one PNG per
  individual zone (`<videobase>_zone_<name>.png`).

## 8. Re-using a preset on a new video

If your camera is approximately stable across days:

1. Click **Browse** on the **Video** row and pick the new video.
   Calibration / arena / objects / zones remain in memory.
2. If the layout aligns with the new frame, **Save preset**
   (subfolder will be auto-named after the new video).
3. If something is misaligned, use the strip below the Preview:
   - **Target** dropdown: `All`, `Arena`, `Object1`, `Object2`, ...
   - **Step (px)** — pixel step for translation, or degrees for
     rotation.
   - **Left / Right / Up / Down** — translate.
   - **Rot ↺ / Rot ↻** — rotate around the target's centroid
     (CCW / CW). Note: with target `All`, each child currently
     rotates around its own centroid (see `TODO.md` #6 — fix
     pending).
4. After nudging, click **Preview** or **Add to set** in Zones (the
   masks are auto-recomputed from the transformed outlines).
5. **Save preset**.

## 9. Help inside the app

Every panel has an `INFO` button (blue). Click it for a short
panel-specific dialog.

## 10. Log

Right column, bottom: a scrollable text area mirroring the MATLAB
Command Window output for the app. The last 500 messages are kept.
*Auto-scroll to the latest message is on R2021a+; on R2020a you can
scroll manually (see `TODO.md` #2).*

## 11. Troubleshooting

- **Preview empty** — load a video first.
- **Need at least 3 corners** — click more points before ENTER.
- **kcorr far from 1** — calibration clicks were probably out of
  order (Y pair first, X pair second).
- **Object Out zones look like solid disks** — should be rings.
  Make sure `Obj zone (cm)` is greater than 0.
- **Zones lost after a move/rotate** — that's by design;
  auto-cleared because old zone masks would no longer match the
  new geometry. Re-Add to set when ready.

---

# Preprocess Tracking tab — user guide

The second tab applies per-body-part preprocessing to a DeepLabCut
trace and saves the result so `sphynx.pipeline.analyzeSession` can
consume it.

## Workflow

1. **Block 1 — Loading.** Click **DLC** and pick the `.csv`. Optionally
   load a **Video** (needed for the embedded viewer) and a **Preset**
   (needed for frame size / pxl-per-cm calibration / manual regions).
   Click **Load** in the switcher row to read the DLC into the table.
2. **Block 2 — Per-part settings.** A row appears per body part with
   editable columns: `use`, `thr` (likelihood threshold), `win,s`
   (smoothing window in seconds), `interp` method, `smooth` method,
   `NF%` (status threshold). Read-only columns fill on Compute:
   `%NaN`, `%lowL`, `%out`, `status`. Click a row to switch the
   preview to that body part. Editing any setting triggers a live
   recompute for that row.
3. **Auto thresholds.** The `Auto:` row picks a likelihood threshold
   from the distribution. Try `otsu` first; for borderline cases switch
   to `quantile` (param `0.05`) or `preset` (param `moderate`). The
   suggestion is overlaid as a red vertical line on the histogram.
4. **Block 3 — Outlier filter.** velocity-jump (default ON, capped at
   50 cm/s) catches single-frame DLC teleports. Hampel (off by default)
   adds a robust median ± k·MAD detector. Kalman (off; activated by
   choosing `kalman` in the smooth column) replaces the regular
   smoother — its `Q` and noise-scale parameters live here too.
5. **Manual exclusion regions** (right column). Click `Add region`,
   draw a polygon on the frame, double-click to commit. Use the
   `applies-to` dropdown to attach the region to one body part or
   `all`. Points inside the polygon are flagged as bad before
   interpolation. Stored per-session.
6. **Embedded video viewer.** Toggle `[Video]` in the switcher row.
   The frame appears with a red `+` at the active body-part's (x, y).
   Slider + step buttons drive the playhead; a red vertical line
   appears on X(t) and Y(t) at the current frame.
7. **Block 4 — Save.** Pick an output dir, choose whether to write
   per-part PNGs, click **Save preprocessed**. Two files appear:
   - `<root>/<expName>_PreprocessSettings.mat` — the per-experiment
     settings (reuse this on other sessions of the same experiment).
   - `<outputDir>/<dlcBase>_Preprocessed.mat` — the actual traces +
     manual regions for this session.

## Pipeline order

```
likelihood → bounds → velocity-jump → Hampel → manual regions
  → interpolate → smooth (sgolay/movmean/movmedian/gaussian) OR Kalman
```

Outlier detection runs PRE-interpolation. Smoothing flattens
single-frame jumps; if you ran the detector after smoothing, those
jumps would no longer trip the threshold.

## Tips

- Limbs (`leftforelimb`, `righforelimb`, etc.) get the small smoothing
  window by default; `bodycenter` and `tailbase` get the bigger one.
  For very fast movements lower the body-center window to 0.15s.
- For poorly-tracked parts (`miniscope*`), set `use = false` and ignore
  the NotFound status. The orchestrator just skips them.
- If `Auto[otsu]` returns a sensible threshold but you want it slightly
  more conservative, switch to `Auto[quantile]` with param `0.10`.
- Manual regions are useful when DLC consistently confuses one part
  with a fixed visual feature (e.g., a cable hanging in one corner).

## New in Tab 2 (R24): reuse settings

Two buttons live in the loader row next to the DLC browser:

- **Check another** -- keeps the current per-part settings in memory
  and prompts you for another DLC csv. The table refills with the new
  trace but the thresholds / windows / outlier flags stay as you set
  them. Use this to spot-check several sessions before saving.
- **Load preprocessed** -- pulls a previously saved
  `<exp>_PreprocessSettings.mat` and applies its per-part values to
  the currently loaded DLC. Use this to bring a tuned config from a
  pilot session onto every new session of the same experiment.

---

## Tab-level pointer

For Define Acts, Analyze Session, Batch Analysis, Make Output Table,
Plot Data, Preprocess Video and Synthetic Data see
`full_workflow_en.md` -- their UI and outputs are described there. The
Barnes-specific session metrics that now appear in the Tab 4 stats
header are listed in `docs/Barnes/metrics.md`.

## Project-wide defaults: `sphynx_defaults.jsonc`

The file `sphynx_defaults.jsonc` at the repo root is a single
tab-organised settings file auto-loaded by
`sphynx.pipeline.defaultConfig`. Edit it to change defaults (default
thresholds, default smoothing windows, default plot toggles, Barnes
hole count, etc.) without touching MATLAB code. Sections inside the
file are organised by tab so a setting that affects Tab 2 lives in
the Tab 2 block.
