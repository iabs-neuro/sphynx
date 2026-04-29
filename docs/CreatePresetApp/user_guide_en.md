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

A two-tab window appears: **Create Preset** and **Analyze Session**.
The Analyze Session tab is a placeholder for now; everything below
is on the first tab.

## 2. Block 1 — Load

- Click **Browse** next to **Project root** and pick a folder you'll
  re-use. The other file dialogs in this session will start there.
- Click **Browse** next to **Video file** and select your video.
  The first frame appears in the Preview.
- Click **Browse** next to **Output dir** and select where presets
  and plots will be saved. The app will auto-create a subfolder
  named after your video.
- Optional: click **Browse** next to **Existing preset** if you want
  to seed the calibration values from a previous session.

If the preview shows the frame, you're ready to calibrate.

## 3. Block 2 — Calibration

You convert pixels to centimeters by clicking 4 reference points and
telling the app how many cm those distances correspond to.

1. Type the real-world distance (cm) for the **vertical** reference
   into **cm Y**.
2. Type the real-world distance (cm) for the **horizontal** reference
   into **cm X**.
3. Click **Calibration. Choose points**. A picture window opens.
4. Click 4 points in this order:
   - point 1 — top of vertical reference
   - point 2 — bottom of vertical reference
   - point 3 — left of horizontal reference
   - point 4 — right of horizontal reference

   The window closes automatically after the 4th click.
5. Click **Calibration. Calculation**. The app shows pxl/cm for
   both axes (`Y:`, `X:`), the average (`avg:`), and the X/Y
   correction factor (`kcorr:`). If `kcorr` is far from 1.000
   (more than a few percent), check whether you clicked the points
   in the right order.

Choose your **Experiment type** from the dropdown.

If you need to see another frame to better identify reference points,
click **Next frame** below the Preview.

## 4. Block 3 — Arena

1. Click one of the geometry buttons: **Polygon**, **Circle**,
   **Ellipse**, or **O-maze**. The selected one stays highlighted
   in yellow.
2. Click **Pick arena points** (red).
3. In the picture window, click points on the arena boundary,
   then press ENTER.
   - **Polygon**: click corners. The app fits a closed polygon.
   - **Circle**: at least 3 points anywhere on the rim.
   - **Ellipse**: at least 5 points on the rim.
   - **O-maze**: 3+ points on the OUTER rim, ENTER, then 3+ points
     on the INNER rim, ENTER.

The arena outline appears in black on the Preview.

## 5. Block 4 — Objects

If your session has objects (food bowls, novel objects, etc.):

1. Click a geometry button (Polygon / Circle / Ellipse).
2. Click **+ Add** (red).
3. Click points on the object boundary, then ENTER.
4. A dialog asks: "Is Object1 correct?" with three options:
   - **Yes**: keep it.
   - **No (redo)**: discards it and re-opens the picker. The old
     mask is removed from the preview before you re-pick.
   - **No (delete)**: deletes it without re-asking.

The dialog keeps re-asking until you pick **Yes** or **No (delete)**.

To remove or replace an existing object, click it in the list, then
click **Remove** or **Replace**. The selected object is highlighted
in orange on the preview.

## 6. Block 5 — Zones

You can apply one or more partitioning strategies. They accumulate.

1. Pick a strategy from the dropdown:
   - `corners-walls-center` — for square / polygon arenas. Set
     **Wall (cm)** to your wall-zone width.
   - `strips` — divides the arena into N equal horizontal or
     vertical strips. Set **N strips** and **Strip dir**.
   - `circle-rings` — for round arenas. Set **Wall (cm)** and
     **Middle (cm)**; the app builds wall, optional middle1/2/...,
     and center rings.
   - `none` — no spatial subdivision.
2. If you have objects, set **Object zone (cm)** — the inflation
   radius for the interaction zone around each object.
3. Click **Preview zones** (red) to see the proposed partition on
   the Preview in magenta.
4. When happy, click **Add to set** (red) to commit those zones to
   the final list. The "Committed zones" counter updates.
5. To start over, click **Clear all** (red).

You can call **Add to set** multiple times with different strategies
to combine partitions.

## 7. Block 6 — Save / Plot

- **Save preset** (red): writes the `.mat` file to
  `<output_dir>/<videobase>/<videobase>_Preset.mat` and also
  saves the combined-layout PNG next to it.
- **Make plot** (red): saves the combined PNG. If **plot all zones**
  is checked, it also saves one PNG per individual zone.

## 8. Re-using a preset on a new video

If your camera position is approximately stable across days, you
can re-use a preset:

1. Click **Browse** for **Video file** and pick the new video.
   The new frame appears in the Preview. Calibration / arena /
   objects / zones are still loaded from before.
2. Look at the Preview. If everything aligns with the new video,
   skip to **Save preset** under the new video's name (the
   subfolder will be auto-named after the new video).
3. If something is misaligned, use the **Move / Rotate** strip
   below the Preview:
   - **Target** dropdown: pick Arena or a specific object
   - **Step (px)**: pixel step for translation (or degrees for
     rotation)
   - **Left / Right / Up / Down**: translate
   - **Rot CCW / Rot CW**: rotate around the target's centroid
4. After nudging, click **Refit mask** to regenerate the binary
   mask from the new outline.
5. Click **Save preset**.

## 9. Where to find help inside the app

Each panel has an `INFO` button (light blue). Click it to open a
short help dialog about that panel.

## 10. Troubleshooting

- **Preview is empty**: load a video first. The picture appears
  only when a video file is selected.
- **"Need at least 3 corners"**: you selected too few points for
  a polygon. Click again with more points.
- **kcorr far from 1**: you may have clicked the calibration
  points in the wrong order (Y pair first, X pair second).
- **Object masks look wrong on saved plot**: ring-shaped object
  zones (`Object<N>Out`) should look like rings (with a hole),
  not solid disks. If they look solid, check that
  `ObjectZoneWidthCm` is greater than zero.
- **Status messages**: appear in the MATLAB Command Window with
  `[INFO] [App] ...` prefix.
