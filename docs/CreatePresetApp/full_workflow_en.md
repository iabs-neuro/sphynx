# sphynx -- Full GUI workflow (EN)

The single window of `sphynx.app.CreatePresetApp` exposes 9 numbered
tabs that together cover the whole behavioral analysis pipeline:

```
1. Create Preset -> 2. Preprocess Tracking -> 3. Define Acts
  -> 4. Analyze Session -> 5. Batch Analysis -> 6. Make Output Table
  -> 7. Plot Data
Auxiliary: 8. Preprocess Video, 9. Synthetic Data
```

This document explains the **logic** of each tab and the **how-to** for
the typical end-to-end workflow.

## What's new since R20

- Numbered tabs (1..9) in the title bar.
- Tab 2: "Check another" + "Load preprocessed" buttons.
- Tab 3: Barnes default library is now 64 acts (nose_at_<hole>,
  body_at_<hole>, platform pair, mouse_inside_<hole>,
  nose_at_any_hole); zone preview refreshes on selection;
  mouse_inside_* requires 2 s sustained.
- Tab 4: 2-row loader, etogram acts-filter listbox, default
  "Render main video" ON, restyled video overlays (white text +
  black outline, yellow square counter).
- Tab 5: pairing handles legacy DLC csvs AND
  superanimal-topviewmouse csvs; multi-digit mouse / day / trial IDs.
- Tab 4 stats header now lists Barnes metrics
  (TotalNoseHoleVisits, PrimaryErrors, TotalBodyHoleVisits,
  NumCheckedHoles, FirstCheckedHoleNumber, FirstCheckedHoleErrorDeg,
  MeanCheckedHoleErrorDeg, TargetHoleVisitOrder) -- full defs in
  `docs/Barnes/metrics.md`.
- `sphynx_defaults.jsonc` (repo root) -- single tab-organised
  defaults file auto-loaded by `sphynx.pipeline.defaultConfig`.

---

## 0. Open the app

```matlab
startup
sphynx.app.CreatePresetApp
```

The window opens maximized.

---

## 1. Create Preset *(see `user_guide_en.md` for the step-by-step
reference; freeze lifted 2026-06-03 -- edits within the Barnes spec
are allowed)*

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
- per-experiment `<root>/<expName>_PreprocessSettings.mat` -- settings
  reusable across sessions of the same experiment.
- per-session `<sessionDir>/<sessionName>_Preprocessed.mat` -- the
  actual cleaned + smoothed traces; consumed by analyzeSession.

**R24 buttons (loader row):**
- **Check another** -- keep the current per-part settings and load
  another DLC csv. Lets you spot-check several sessions with the
  same thresholds before saving.
- **Load preprocessed** -- pull a saved
  `<exp>_PreprocessSettings.mat` and apply it to the currently loaded
  DLC. Use to push a tuned configuration onto every session of the
  same experiment.

---

## 3. Define Acts

A *behavioral act* is a per-frame boolean signal. The library contains
two kinds:

**Simple act** — true on a frame iff:
  - the chosen body part is inside one of the chosen zones
    (multi-select = OR; for AND/EXCLUDE use a complex act);
    selecting `<any zone>` means "no zone gate at all",
  - **and** that body part's velocity is in `[speedMin, speedMax]`
    (`SpeedMax = Inf` means "no upper limit").

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

**Barnes default library (button "Load Barnes defaults"):** 64 acts
in total --
  - 1 + 19 `nose_at_<hole>` (target + every non-target hole),
  - 1 + 19 `body_at_<hole>`,
  - the platform pair (`on_platform`, `off_platform`),
  - 1 + 19 + 1 `mouse_inside_<hole>` (target, each non-target, plus
    `mouse_inside_any_hole`); this family requires a 2 s sustained
    run, enforced per-act via `minDurationSec=2.0`,
  - `nose_at_any_hole`.

Selecting an act in the library list now refreshes the zone preview
so you can see which hole / zone is gated.

**Output:** `<expName>_acts_library.mat`.

---

## 4. Analyze Session

Run the full pipeline on **one** session, inspect the result. UI:
- Batch-style **2-row loader** strip:
  - Row 1: Root / Preset / Video / DLC / Out dir.
  - Row 2: Preproc settings / Acts library.
- Override the rest / locomotion / freezing thresholds inline.
- Run -> result table populates with `Act / % / duration / count /
  mean dur, s` for every act (built-ins + library).
- Plots: trajectory of the body center (with an **acts-filter
  listbox on the left of the trajectory panel** to subset what is
  drawn), acts timeline (one row per act), bodycenter speed
  histogram.
- "Render main video" checkbox now **defaults ON**. The rendered
  overlay shows the info block flush top-left in white text with a
  1 px black outline (no plate behind it). The frame counter is a
  yellow square of height 10% of the frame, top-right.

The session-stats header now also reports Barnes metrics:
`TotalNoseHoleVisits`, `PrimaryErrors`, `TotalBodyHoleVisits`,
`NumCheckedHoles`, `FirstCheckedHoleNumber`,
`FirstCheckedHoleErrorDeg`, `MeanCheckedHoleErrorDeg`,
`TargetHoleVisitOrder` (see
`+sphynx/+pipeline/barnesSessionMetrics.m`). Full definitions are in
`docs/Barnes/metrics.md`.

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
- Run -> progress bar; tidy + wide tables shown on the right.
- **Save tables to CSV** -> tidy + wide csvs in the output dir.

**Session pairing (R24):** the auto-pairer that matches DLC csvs to
presets now handles BOTH csv naming families:
- legacy DeepLabCut, e.g. `WNOF_J01_1DDLC_resnet50_...csv`,
- superanimal-topviewmouse, e.g.
  `NOF_H01_1D_superanimal_topviewmouse_..csv`.

Multi-digit mouse / day / trial IDs are supported (`m23`, `m183`,
`m5718`, `12d_3t`, ...).

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
6. **Make Output Table** with metadata.csv -> `out/super_table.csv`.
7. **Plot Data** from `super_table.csv` -- preliminary bar / box /
   scatter per group. Final plots in Prism.

---

## Project-wide defaults: `sphynx_defaults.jsonc`

A single tab-organised settings file at the repo root,
`sphynx_defaults.jsonc`, is auto-loaded by
`sphynx.pipeline.defaultConfig`. Edit it to change defaults across
the whole app (e.g. default likelihood thresholds, default smoothing
windows, default plot toggles, Barnes hole count, default save
options). The sections inside the file are organised by tab so a
setting that affects Tab 4 lives in the Tab 4 block. Changing
defaults here keeps the MATLAB code untouched, which is much safer
than editing constructors.
