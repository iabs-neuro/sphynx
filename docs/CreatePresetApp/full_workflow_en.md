# sphynx — Full GUI workflow (EN)

The single window of `sphynx.app.CreatePresetApp` exposes 9 tabs that
together cover the whole behavioral analysis pipeline:

```
Create Preset → Preprocess Tracking → Define Acts → Analyze Session
              → Batch Analysis → Make Output Table → Plot Data
Auxiliary: Preprocess Video, Synthetic Data
```

This document explains the **logic** of each tab and the **how-to** for
the typical end-to-end workflow.

---

## 0. Open the app

```matlab
startup
sphynx.app.CreatePresetApp
```

The window opens maximized.

---

## 1. Create Preset *(frozen — see `README.md` and `user_guide_en.md`
for the full reference)*

For every video session you want to analyze you build a *preset* — a
.mat file with: pixel-to-cm calibration, the arena outline, object
outlines, and the spatial zones (corners / walls / center / object
neighborhoods / etc.).

**Output:** `<videobase>_Preset.mat` next to the video.

---

## 2. Preprocess Tracking

The DLC csv contains raw (x, y, likelihood) per body part per frame.
The preprocessing pipeline cleans it:

```
likelihood → bounds → velocity-jump → Hampel → manual regions
  → interpolate → smooth (sgolay / movmean / movmedian / gaussian)
                  OR Kalman 2D (replaces sgolay)
```

Per-part settings (threshold / window / interp / smooth method) live
in the table on the right. Outlier filters (velocity-jump, Hampel) are
global and live in Block 2. Manual exclusion regions are drawn on the
preset's frame for spots where DLC systematically misfires (e.g. a
cable shadow always recognized as an ear).

**Outputs:**
- per-experiment `<root>/<expName>_PreprocessSettings.mat` — settings
  reusable across sessions of the same experiment.
- per-session `<sessionDir>/<sessionName>_Preprocessed.mat` — the
  actual cleaned + smoothed traces; consumed by analyzeSession.

---

## 3. Define Acts

A *behavioral act* is a per-frame boolean signal. The library contains
two kinds:

**Simple act** — true on a frame iff:
  - the chosen body part is inside the chosen zone(s), combined via
    `AND` / `OR` / `EXCLUDE` (e.g., "in corners but not in object
    neighborhood"),
  - **and** that body part's velocity is in `[speedMin, speedMax]`.

**Complex act** — combine N already-defined acts with a logical
operation:
  - `intersect` — both A and B are happening,
  - `union` — A or B,
  - `exclude` — A but not B,
  - `sequence` — A then B within `seqDelaySec` seconds.

There are also **special acts**:
  - `freezing` — head + center velocity below threshold simultaneously,
  - `rears` — tailbase-paws distance below threshold (cm).

The library is loaded with sane defaults (rest / walk / locomotion /
freezing / rears) on tab open. Save/Load button persists the library
to a `.mat` so you can reuse it across experiments of the same type.

**Output:** `<expName>_acts_library.mat`.

---

## 4. Analyze Session

Run the full pipeline on **one** session, inspect the result. UI:
- Browse DLC csv, preset .mat, output dir, optional acts library.
- Override the rest / locomotion / freezing thresholds inline.
- Run → result table populates with `Act / % / duration / count /
  mean dur, s` for every act (built-ins + library).
- Plots: trajectory of the body center, acts timeline (one row per
  act), bodycenter speed histogram.

Use this tab to validate that your library + thresholds produce
sensible results before running a batch. Results are saved as
`<sessionDir>/<sessionName>_WorkSpace.mat` (consumed by Make Output
Table).

---

## 5. Batch Analysis

Run analyzeSession across a set of (DLC, Preset) pairs. UI:
- `+ Session` adds one DLC + Preset pair to the list.
- One **Output dir** for everything (subfolders auto-created per
  session).
- One optional **Acts library** for the whole batch.
- Toggles: save plots / save per-session .mat / build aggregate tables.
- Run → progress bar; tidy + wide tables shown on the right.
- **Save tables to CSV** → tidy + wide csvs in the output dir.

The aggregate **wide** table here is a quick preview. For a more
controlled, Prism-friendly export with metadata, use Make Output Table.

---

## 6. Make Output Table

Aggregates per-session WorkSpace.mat files into a wide table optimized
for GraphPad Prism (and Excel). UI:
- **Batch dir** — folder produced by step 5.
- **Metadata CSV** (optional) — columns
  `session_name, mouse, session, group, line`. If omitted, mouse and
  session are parsed from filenames (`<exp>_<mouse>_<session>D`).
- **Metrics** — multi-select listbox (ActPercent, ActDuration,
  ActNumber, ActMeanTime, …). Distance and Velocity per session are
  always added.
- **NaN policy** — keep (default) or zero. Some downstream tools
  prefer zeros for missing cells.
- **Sort by** — primary sort key for the rows.
- **Build table** → wide and tidy tables previewed in the right column.
- **Save CSV** → `super_table.csv` (wide, Prism-ready) and
  `super_table_tidy.csv` (long format).

Wide format: one row per mouse, columns = `mouse / group / line /
<act>_<metric>_<session> / distance_cm_<session> / velocity_cm_per_s_<session>`.

---

## 7. Plot Data

Quick preliminary plots from the wide CSV. UI:
- Browse + Load → numeric columns auto-populate the dropdowns.
- **Plot column** — which numeric metric to draw.
- **Group by** — `group` / `line` / `<none>` etc. (any non-numeric
  column).
- **Plot type** — bar (mean ± SEM), box, scatter.
- **Colormap** — parula / jet / hsv / cool / hot / plasma / viridis.
- **Error bars** — SEM / SD / none.
- **Overlay individual points** — adds a jittered scatter on top.
- Plot button renders. Save PNG button exports.

This tab is for quick inspection — the real publication-grade plots
should be done in Prism / Python.

---

## 8. Preprocess Video *(auxiliary)*

Wraps the legacy scripts in the `/Preprocess` folder. UI:
- **Browse** a folder of videos → table of files with FPS / frames /
  resolution / duration.
- **Fix FPS metadata** — corrects metadata in-place when a video was
  recorded with a wrong declared frame rate.

Useful when raw videos from the camera have wrong FPS metadata which
would mislead DLC and downstream analyses.

---

## 9. Synthetic Data *(auxiliary)*

Generates synthetic DLC csv + minimal preset for testing the
preprocessing / analysis pipeline without a real animal. Motion models
(random walk / circular / Ornstein-Uhlenbeck), outlier modes (none /
spikes / long_gap / poor_likelihood / mixed), likelihood models
(bimodal_high_quality / bimodal_borderline / unimodal_high /
unimodal_low). Save to a folder or load directly into Preprocess
Tracking via the **Load synthetic** button there.

---

## End-to-end example: WNOF experiment

```
Project root: <root>/
  videos/   WNOF_J01_1D.mp4, WNOF_J01_2D.mp4, ... WNOF_J05_1D.mp4, ...
  dlc/      WNOF_J01_1DDLC_resnet152....csv, ...
  presets/  WNOF_J01_1D_Preset.mat, ...
  metadata.csv  (session_name, mouse, session, group, line)
  preprocess/   <expName>_PreprocessSettings.mat
  acts/         WNOF_acts_library.mat
  out/          <-- batch output dir
```

1. **Create Preset** for each session → `presets/`.
2. **Preprocess Tracking**: load one DLC + preset, tune per-part
   settings, save the experiment-wide `_PreprocessSettings.mat`.
3. **Define Acts**: build a library specific to WNOF (object visits
   per object, time-in-corners, etc.), save to `acts/`.
4. **Analyze Session** on one (DLC, preset, acts library) — sanity
   check trajectory + acts %.
5. **Batch Analysis** for all sessions with the same acts library →
   `out/<session>_WorkSpace.mat` for each.
6. **Make Output Table** with metadata.csv → `out/super_table.csv`.
7. **Plot Data** from `super_table.csv` — preliminary bar / box /
   scatter per group. Final plots in Prism.
