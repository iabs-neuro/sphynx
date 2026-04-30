# Preprocess Tracking GUI tab — implementation plan

**Goal:** Implement the Preprocess Tracking tab per `docs/superpowers/specs/2026-04-30-sphynx-preprocess-tab-design.md` (sprint mode, 8 slices).

**Architecture:** Extend `sphynx.app.CreatePresetApp` with a second tab. Logic in `sphynx.app.PreprocessTabController` (separate class to keep CreatePresetApp focused on presets). New algorithms in `+sphynx/+preprocess/`. Per-experiment settings file + per-session preprocessed file.

**Tech Stack:** R2020a, uifigure, uigridlayout, uitable, Image Processing, Signal Processing, Statistics ML.

---

## Slice 1: Loading + Preview canvas (Task #17)

**Files:**
- Create: `+sphynx/+app/PreprocessTabController.m`
- Modify: `+sphynx/+app/CreatePresetApp.m` — register new tab
- Test: `tests/smoke/test_preprocessTab_smoke.m`

### Steps
- [ ] Add `Preprocess Tracking` tab to `uitabgroup` in CreatePresetApp.
- [ ] Build left scrollable column with placeholder Block 1 (root, DLC, video, preset uigetfile widgets, "Load all" button).
- [ ] Build right column: 3-row gridlayout for X(t) / Y(t) / likelihood histogram + bodypart dropdown + frame slider.
- [ ] Wire "Load all" → `readDLC`, populate bodypart dropdown, draw raw X/Y/histogram for first part.
- [ ] Smoke test: instantiate app headless, load Demo csv, switch parts, no errors.

### Verify
```matlab
matlab -batch "addpath(genpath(pwd)); runtests('tests/smoke/test_preprocessTab_smoke.m')"
```
Expected: PASS.

### Commit
`feat(app): preprocess tab — loading + preview skeleton`

---

## Slice 2: Per-part settings table + Compute (Task #18)

**Files:**
- Modify: `+sphynx/+app/PreprocessTabController.m`
- Create: `+sphynx/+preprocess/applyPerPartSettings.m`
- Modify: `+sphynx/+pipeline/defaultConfig.m` — add `preprocess.perPart` template
- Test: `tests/unit/test_applyPerPartSettings.m`

### Steps
- [ ] In controller: build Block 2 panel with `uitable` (rows = bodyparts, columns per spec).
- [ ] Defaults: thr=0.95, win=0.10s for limbs / 0.25s for center+tailbase, interp='pchip', smooth='sgolay-3', NotFound=90%.
- [ ] Defaults seeded from `defaultConfig.preprocess.perPart` (move heuristic out of `pickSmoothWindow`).
- [ ] Wire `Default this` (selected row) and `Default all` buttons.
- [ ] Wire `Compute this` and `Compute all` — call `applyPerPartSettings` and update preview + status columns.
- [ ] `applyPerPartSettings(rawX, rawY, likelihood, settings)` returns `cleaned, interpolated, smoothed, percentNaN, percentLowL, status`.
- [ ] Unit test: synthetic trace with known NaN pattern → expected output.

### Commit
`feat(preprocess): per-part settings table with Compute`

---

## Slice 3: Auto thresholds (Task #19)

**Files:**
- Create: `+sphynx/+preprocess/autoThreshold.m`
- Modify: `+sphynx/+app/PreprocessTabController.m` — wire UI
- Test: `tests/unit/test_autoThreshold.m`

### Steps
- [ ] Implement `autoThreshold(likelihood, method, param)` with branches: 'otsu', 'knee', 'quantile', 'preset'.
- [ ] Otsu: `multithresh(likelihood, 1)`. Fallback to preset moderate if all values identical.
- [ ] Knee: simple curvature-max on sorted CDF.
- [ ] Quantile: `quantile(likelihood, param)`.
- [ ] Preset: enum aggressive=0.99, moderate=0.95, lax=0.6.
- [ ] In UI: dropdown method + numeric param + apply-to-selected/all buttons + "preview on histogram" overlay (vertical line at suggested threshold).
- [ ] Unit test: synthetic bimodal/unimodal/uniform inputs.

### Commit
`feat(preprocess): auto threshold — 4 methods`

---

## Slice 4: Outlier filters (Task #20)

**Files:**
- Create: `+sphynx/+preprocess/velocityJumpFilter.m`
- Create: `+sphynx/+preprocess/hampelFilter.m`
- Create: `+sphynx/+preprocess/kalmanFilter2D.m`
- Modify: `+sphynx/+preprocess/applyPerPartSettings.m` — chain filters
- Modify: `+sphynx/+app/PreprocessTabController.m` — wire Block 3 UI + max velocity field
- Test: `tests/unit/test_velocityJumpFilter.m`, `test_hampelFilter.m`, `test_kalmanFilter2D.m`

### Steps
- [ ] `velocityJumpFilter(X, Y, fps, pxlPerCm, maxCmS)` → marks bad frames where between-frame displacement exceeds biological max.
- [ ] `hampelFilter(X, Y, win, nSigma)` → wraps `hampel()` for both axes, returns logical bad mask.
- [ ] `kalmanFilter2D(X, Y, likelihood, processNoise, measNoiseScale)` → 2D constant-velocity, smoothed (X, Y).
- [ ] Chain in `applyPerPartSettings`: clean → outlier filters (in order velocityJump → Hampel → Kalman) → interp → smooth.
- [ ] UI Block 3: 3 checkboxes + max velocity field (default 50). Live recompute on change.
- [ ] Unit tests with synthetic spike injections.

### Commit
`feat(preprocess): outlier filters — velocity-jump + Hampel + Kalman`

---

## Slice 5: Manual exclusion regions (Task #21)

**Files:**
- Modify: `+sphynx/+app/PreprocessTabController.m`
- Modify: `+sphynx/+preprocess/applyPerPartSettings.m` — accept regions

### Steps
- [ ] Add Block 5 right-side panel: `[Add region]` + `appliesTo` dropdown + region listbox + delete/clear.
- [ ] On `Add region`: open frame canvas (use video frame from preset), `drawpolygon`/`drawrectangle`, store vertices.
- [ ] In `applyPerPartSettings`: for each region, if `appliesTo == part || appliesTo == 'all'`, mark frames where (x,y) inside polygon → bad → NaN.
- [ ] Persist regions to `_Preprocessed.mat` (per-session, not per-experiment).
- [ ] Trigger live recompute on region add/delete.

### Commit
`feat(preprocess): manual exclusion regions`

---

## Slice 6: Embedded video viewer (Task #22)

**Files:**
- Modify: `+sphynx/+app/PreprocessTabController.m`

### Steps
- [ ] Add toggle button `[Show video]` under preview.
- [ ] When enabled: small `uiaxes` shows `VideoReader.read(currentFrame)` + dot at `(x, y)` of selected bodypart.
- [ ] Frame slider + step ±1 / play buttons.
- [ ] Vertical line on X(t) / Y(t) plots at currentFrame, syncs with video.
- [ ] Click on X/Y plot → set currentFrame.
- [ ] Cache last 100 frames to avoid re-decoding on slider drag.

### Commit
`feat(preprocess): embedded video viewer with frame sync`

---

## Slice 7: Live recompute + Save (Task #23)

**Files:**
- Create: `+sphynx/+preprocess/exportTracks.m`
- Create: `+sphynx/+io/writeTracksSettings.m`
- Create: `+sphynx/+io/readTracksSettings.m`
- Modify: `+sphynx/+app/PreprocessTabController.m`
- Modify: `+sphynx/+pipeline/analyzeSession.m` — read `_Preprocessed.mat` if present

### Steps
- [ ] Debounce `CellEditCallback` (300ms timer); after fire, recompute affected part and refresh preview.
- [ ] Add column "outliers detected %" to per-part table.
- [ ] `exportTracks(controller)` → writes per-experiment `_PreprocessSettings.mat` + per-session `_Preprocessed.mat` + optional plots.
- [ ] Plots: 3-panel figure per bodypart (X, Y, likelihood) with raw/interp/smooth overlays.
- [ ] Save button: warn if any part stale (settings changed since last Compute) and offer Compute all.
- [ ] `analyzeSession`: if `_Preprocessed.mat` exists alongside DLC, load BodyPartsTraces from it and skip clean/interp/smooth stages.

### Commit
`feat(preprocess): save tracks + live recompute + analyzeSession integration`

---

## Slice 8: Tests + docs (Task #24)

**Files:**
- Modify: `docs/CreatePresetApp/README.md`
- Modify: `docs/CreatePresetApp/user_guide_en.md`, `user_guide_ru.md`
- Possibly: `docs/superpowers/logs/{claude_log.md, user_log.md}`

### Steps
- [ ] Add Preprocess section to README with screenshot description.
- [ ] Workflow walkthrough in en+ru guides.
- [ ] Run full test suite: `runtests('tests', 'IncludeSubfolders', true)`.
- [ ] Document how batch script (future) consumes `_PreprocessSettings.mat`.

### Commit
`docs(preprocess): README + user guides for new tab`

---

## After completion

- Move CreatePresetApp TODO #4 (drag-and-drop ROI) to consider dovetailing with Manual exclusion regions tooling — same drawing primitives.
- Decide with user whether batch runner is next or we go to Stage E (analyzeSession TODO).
