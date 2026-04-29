# CreatePresetApp — user guide (English)

Step-by-step walkthrough for building a spatial preset for one
behavioral video session.

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

The window opens maximized with two tabs: **Create Preset** (used
below) and **Analyze Session** (a placeholder for the future
batch-run UI).

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
