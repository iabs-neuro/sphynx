# Sphynx Stage C — Audit & Refactoring Design

**Date:** 2026-04-27
**Branch:** `sphynx-GUI`
**MATLAB target:** R2020a
**Project:** sphynx (Segmented PHYsical aNalysis of eXploration) — behavioral analysis of animals in neuroscience experiments
**Stage:** C — correctness, reliability, bug fixes, tests, small features

---

## 1. Context and goals

Sphynx is a MATLAB pipeline that ingests DeepLabCut tracking output, post-processes body-part trajectories, computes behavioral acts (rest, walk, locomotion, freezing, rear, zone visits) and produces aggregate tables for downstream analysis.

The codebase has evolved over time without external review and accumulated technical debt: monolithic functions (`BehaviorAnalyzer.m` — 698 lines, `CreatePreset.m` — 808 lines), 18 experiment-specific forks under `Projects/`, 18 commanders under `Cross-analysis/`, debug code left in production, hardcoded paths, no tests.

The work is structured into three goals:

- **Goal C — Correctness, reliability, tests, small features (this design).** The short-term and primary goal.
- **Goal B — Universalize across experiments and species.** Future work; out of scope here.
- **Goal A — Publication / open-source.** Long-term horizon; out of scope here.

This document specifies Goal C only.

---

## 2. Goals (Stage C)

1. Fix four known bugs (zones at frame edge, angle wrap, edge smoothing artifacts, velocity outliers).
2. Decompose the two monolithic core files (`BehaviorAnalyzer.m`, `CreatePreset.m`) into focused, testable functions.
3. Add a test suite (unit, synthetic, golden-regression, smoke).
4. Add new spatial-zone partitioning options for square and round arenas.
5. Build an App Designer GUI for preset creation.
6. Lightly audit and fix the `Preprocess/` subproject.

---

## 3. Non-goals (Stage C)

- Unifying the 18 experiment-specific forks in `Projects/` (Goal B).
- Unifying the 18 Commander files in `Cross-analysis/` (Goal B).
- Refactoring 3DM-specific code (`Three_DM_z_coordinate.m`, `analyze_movement_3D.m`, `create_3d_trajectory_gif.m`).
- CI / GitHub Actions setup (Goal A).
- Publication-grade documentation (Goal A).
- Unified preset format across experiments (Goal B).
- GUI for batch analysis (Goal A/B).
- Backwards-compatibility shims for the old API. The user explicitly accepted that the new core may break the old API; downstream files that break will be patched later.

---

## 4. Known bugs (to fix in Stage C)

| ID | Bug | Location |
|---|---|---|
| Bug-1 | Square-arena corner/wall/center zones break when arena boundary is close to frame edge | `CreatePreset.m:488–509` (`bwdist(~ArenaReal)` reads outside frame as background) |
| Bug-2 | Head and body rotation angles take values outside `[-π, π]`; smoothing across the `±π` discontinuity produces artifacts | `BehaviorAnalyzer.m:546–547` (HeadDirection: `cart2pol` then `smooth(...)` without unwrap); also derivative paths |
| Bug-3 | Signal preprocessing (Savitzky-Golay smoothing) inflates values at trace edges | `BehaviorAnalyzer.m:222–223`, `547`, `440` |
| Bug-4 | Animal velocity sometimes spikes (DLC tracking outliers); biological max is ≤ 50 cm/s | `BehaviorAnalyzer.m:438–440` (no clipping before smoothing) |

## 5. Additional findings from initial reading

These are not in the user's known-bug list but were flagged during exploration; they will be addressed where they fall within Stage C scope.

| Finding | Location | Disposition |
|---|---|---|
| Debug loop `for k = 4000:4100` instead of `1:n_frames` | `BehaviorAnalyzer.m:385` | Fix in slice 6 (will be `config.viz.frameRange = 'all'` by default) |
| Hardcoded paths overwriting input arguments | `Preprocess/processVideos.m:16–18` | Fix in slice 10 |
| `*_WorkSpace.mat` saved 9 times in a single function | `BehaviorAnalyzer.m:161, 278, 351, 453, 626, 696` (and others) | Replace with single save in slice 6 (`+sphynx/+io/saveSession.m`) |
| Body-part X and Y processing duplicated as two near-identical branches | `BehaviorAnalyzer.m:163–267` | Refactor in slice 4 (`+sphynx/+preprocess/cleanBodyPart.m`) |
| Plot/save logic interleaved with compute | throughout `BehaviorAnalyzer.m`, `CreatePreset.m` | Strict separation in new package: compute in `+sphynx/+{preprocess,acts,zones,...}/`, viz in `+sphynx/+viz/`, I/O in `+sphynx/+io/` |
| Hardcoded UI default paths to `c:\Users\Plusnin\...` and `c:\Users\User\...` | `BehaviorAnalyzer.m:51–53`, `CreatePreset.m:23–24, 52` | New CLI accepts paths via `config`; new GUI manages them via state |
| 3 commented-out blocks of obsolete code | `BehaviorAnalyzer.m:354–374`, `CreatePreset.m:114–146`, `BehaviorAnalyzer.m:405–417` | Remove during decomposition (legacy file untouched, but new code is clean) |
| `datestr(now)` deprecation pending | `Preprocess/processVideos.m:36` | Replace with `datetime("now")` in slice 10 |

A more exhaustive defect catalogue is not produced as a separate audit document. Each slice does its own targeted re-audit of the code it touches and addresses findings inline.

---

## 6. Constraints

- **MATLAB version:** R2020a. Use only constructs available in R2020a. Notably: `arguments` block is available but `inputParser` is preferred for clarity; string-`switch` is fine; MATLAB packages (`+pkg/`) are fully supported; App Designer is mature; `matlab.unittest` is available.
- **Toolboxes available:** Signal Processing, Image Processing, Statistics, Mapping (assumed full set per user). Ask if a newer toolbox feature is needed.
- **API freedom:** The new core is free to change function signatures and data structures. Old code in the repository continues to call old `BehaviorAnalyzer.m` and is not affected.
- **`functions/` policy:** Functions in `functions/*.m` that the new code needs are brought into `+sphynx/` (in the appropriate subpackage), audited, fixed if necessary, and unit-tested. The original copies in `functions/` are left untouched because legacy code still references them.
- **Old folders untouched:** `Projects/`, `Cross-analysis/`, root-level legacy files (`BehaviorAnalyzer.m`, `Commander_behavior*.m`, `BOWL_make_pic_vel_acts.m`, `LNOF_make_video_acts.m`, `NOF_make_video_acts.m`, `BehaviorAnalyzerTest.m`), `tools/`, `Demo/`, `functions/` are not modified on the `sphynx-GUI` branch.

---

## 7. Architecture

### 7.1 Package layout

All new code lives in a MATLAB package `+sphynx/` at the repo root. The package is self-contained — it does not call legacy `functions/*.m`. Old code at root continues to work as before (it calls legacy `functions/*.m` via `addpath(genpath(...))` from `startup.m`).

```
sphynx/                                  (repo root)
├── +sphynx/                             ✨ all new code
│   ├── +io/
│   │   ├── readDLC.m                    parse DLC csv → struct
│   │   ├── readPreset.m                 load .mat preset → Preset struct
│   │   ├── savePreset.m                 save Preset struct → .mat
│   │   ├── readVideoMeta.m              VideoReader → struct (no full read)
│   │   └── saveSession.m                single end-of-pipeline save (replaces 9× saves)
│   ├── +preprocess/
│   │   ├── cleanBodyPart.m              NaN/clip/likelihood-mask (replaces 165–267)
│   │   ├── interpolateGaps.m            pchip with edge-aware extrapolation
│   │   ├── smoothTrace.m                sgolay with mirror-padding (Bug-3)
│   │   ├── computeVelocity.m            ≤50 cm/s clip + smooth (Bug-4)
│   │   ├── deriveTrace.m                Nth derivative
│   │   └── +kalman/
│   │       ├── tune.m                   from auto_tune_kalman
│   │       ├── filterOrder1.m           from kalman_order1
│   │       ├── filterOrder2.m           from kalman_order2
│   │       └── detectOutliers.m         from detect_outliers_kalman
│   ├── +bodyparts/
│   │   ├── identifyParts.m              explicit synonym registry (replaces find_bodyPart)
│   │   ├── computeCenter.m              fallback to (Left+Right)/2 if no Center
│   │   └── relativeCoords.m             tailbase-relative + cart2pol + wrap
│   ├── +zones/
│   │   ├── classifySquare.m             corner/wall/center, edge-aware (Bug-1) + N strips
│   │   ├── classifyCircle.m             wall/middle*/center, ring-based, generalized
│   │   ├── partitionStrips.m            N equal strips top↓bottom or left→right
│   │   └── inMaskSafe.m                 safe mask query at (x,y) with frame-edge padding
│   ├── +angles/
│   │   ├── wrap.m                       [-π, π] (replaces ad-hoc usage)
│   │   ├── unwrapForSmooth.m            unwrap → smooth → re-wrap
│   │   └── headDirection.m              end-to-end safe head direction
│   ├── +acts/
│   │   ├── refineAct.m                  min-length filter (from RefineLine)
│   │   ├── speedActs.m                  rest/walk/locomotion (refactor 456–493)
│   │   ├── freezing.m                   registry of 3 modes
│   │   ├── rear.m                       registry of 2 modes
│   │   ├── zoneAct.m                    generic zone presence
│   │   ├── actStats.m                   Number/Percent/MeanTime/Duration/Distance
│   │   └── actParams.m                  from behavior_act_params
│   ├── +pipeline/
│   │   ├── analyzeSession.m             ✨ main entry — replaces BehaviorAnalyzer
│   │   ├── defaultConfig.m              all default parameters in one place
│   │   ├── runBatch.m                   batch + SuperTable (refactors Commander_behavior.m)
│   │   └── +legacy/
│   │       └── toLegacyOutput.m         convert new output to legacy {Acts, BodyPartsTraces, Point}
│   ├── +viz/                            ✨ all plotting; compute does not call plot
│   │   ├── plotTraces.m
│   │   ├── plotActs.m
│   │   ├── plotKinematogramma.m
│   │   ├── plotZones.m
│   │   └── makeOverlayVideo.m
│   ├── +preset/
│   │   ├── pickGoodFrame.m              find good frame for arena/object marking
│   │   ├── readArenaGeometry.m          ginput-based geometry definition
│   │   ├── readObjects.m                ginput-based object definition
│   │   ├── buildZonesSquare.m           uses +zones/classifySquare
│   │   ├── buildZonesCircle.m           uses +zones/classifyCircle
│   │   ├── adjustExistingPreset.m       refactor of arrow-key+rotation UI loop
│   │   ├── maskFromBorder.m             from MaskCreator (Bug-1 edge case fix)
│   │   └── pixelsPerCm.m                from CalculatePxlInCm
│   ├── +util/
│   │   ├── circleFit.m                  from circfit
│   │   ├── ellipseFit.m                 from my_fit_ellipse
│   │   ├── polygonFit.m                 from PolygonFit
│   │   ├── getLineEquation.m            from GetLineEquation
│   │   ├── linesIntersection.m          from LinesPoint
│   │   ├── replaceNaNinStruct.m         from replaceNaNinStruct
│   │   ├── progress.m                   waitbar wrapper (no-op in tests)
│   │   └── log.m                        simple logger with verbose levels
│   ├── +testing/                        synthetic data generators for tests
│   │   ├── makeStationaryDLC.m
│   │   ├── makeWalkingDLC.m
│   │   ├── makeRearDLC.m
│   │   ├── makeZoneCrossDLC.m
│   │   ├── makeJumpyDLC.m
│   │   ├── makeRotatingMouseDLC.m
│   │   └── makeArenaAtFrameEdgeDLC.m
│   └── +app/
│       └── CreatePresetApp.mlapp        ✨ App Designer GUI
│
├── tests/
│   ├── runAllTests.m                    one-shot entry: runtests('tests', ...)
│   ├── unit/                           unit tests for pure functions
│   ├── synthetic/                      synthetic-DLC tests with known answers
│   ├── golden/                         regression vs Demo/NOF_H01 baselines
│   │   ├── snapshots/                   tracked .mat snapshots (~few KB each)
│   │   └── buildSnapshots.m             one-shot script: legacy → snapshots
│   └── smoke/
│       └── demoPipelineTest.m
│
├── docs/superpowers/specs/2026-04-27-sphynx-stage-c-design.md   (this document)
│
└── (all legacy files stay where they are: BehaviorAnalyzer.m, CreatePreset.m,
    Commander_behavior.m, Projects/, Cross-analysis/, functions/, tools/,
    Preprocess/, Demo/, README.md, startup.m, downloadDemoVideos.m, ...)
```

### 7.2 Naming and namespace policy

- New code is invoked by namespace: `sphynx.zones.classifySquare(...)`, `sphynx.pipeline.analyzeSession(...)`.
- New names deliberately differ from legacy names (`circleFit` vs `circfit`, `ellipseFit` vs `my_fit_ellipse`, `maskFromBorder` vs `MaskCreator`, `refineAct` vs `RefineLine`). This guarantees no `addpath`/`genpath` collision.
- `startup.m` is left as is.

### 7.3 API shape

The new entry point is:

```matlab
result = sphynx.pipeline.analyzeSession(config)
```

`config` is a single struct produced by `sphynx.pipeline.defaultConfig()` and overridden by the caller. Fields include:

- `paths.video`, `paths.dlc`, `paths.preset`, `paths.outDir`
- `range.startFrame`, `range.endFrame`
- `acts.enabled` — cell array of act names to compute
- `viz.enabled` — bool, master switch for plots
- `viz.makeVideo` — bool, opt-in for `*_BodyParts.mp4` and `*_act_*.mp4`
- `viz.headless` — bool, set true in batch and tests
- `io.saveWorkspace` — bool (default true), single end-of-pipeline `*_WorkSpace.mat`
- `io.saveFeaturesCsv` — bool (default true), `*_Features.csv` as in legacy
- `preprocess.maxVelocityCmS` — default 50
- `preprocess.smoothMethod` — `'sgolay'` (default) or `'kalman'`

`result` is a struct with fields `Acts`, `BodyPartsTraces`, `Point`, `Options`, `Zones`, `ArenaAndObjects`, `Features`, `Kinematogramma`. The shape is similar to the legacy outputs but cleaned up; a converter `sphynx.pipeline.legacy.toLegacyOutput(result)` returns the exact legacy shape if needed.

### 7.4 Function inventory from `functions/` brought into `+sphynx/`

| Source `functions/*.m` | Destination | Action |
|---|---|---|
| `find_bodyPart.m` | `+sphynx/+bodyparts/identifyParts.m` | Refactor with explicit registry of synonyms |
| `RefineLine.m` | `+sphynx/+acts/refineAct.m` | Audit min-length semantics; unit-test |
| `behavior_act_params.m` | `+sphynx/+acts/actParams.m` | Audit and unit-test |
| `MaskCreator.m` | `+sphynx/+preset/maskFromBorder.m` | Frame-edge handling for Bug-1 |
| `circfit.m` | `+sphynx/+util/circleFit.m` | Unit-test on synthetic |
| `my_fit_ellipse.m` | `+sphynx/+util/ellipseFit.m` | Audit and unit-test |
| `PolygonFit.m` | `+sphynx/+util/polygonFit.m` | Audit and unit-test |
| `GetLineEquation.m` | `+sphynx/+util/getLineEquation.m` | Audit and unit-test |
| `LinesPoint.m` | `+sphynx/+util/linesIntersection.m` | Audit and unit-test |
| `CalculatePxlInCm.m` | `+sphynx/+preset/pixelsPerCm.m` | Audit |
| `kalman_order1.m`, `kalman_order2.m`, `auto_tune_kalman.m`, `detect_outliers_kalman.m` | `+sphynx/+preprocess/+kalman/` | Audit; will serve as alternative smoothing in slice 3 |
| `replaceNaNinStruct.m` | `+sphynx/+util/replaceNaNinStruct.m` | Audit and unit-test |
| `Three_DM_z_coordinate.m`, `analyze_movement_3D.m`, `create_3d_trajectory_gif.m`, `analyze_data.m`, `TrackTransformerFC.m`, `create_rectangle_around_line.m`, `plot_kalman_results.m` | **Not migrated in Stage C** | 3DM-specific or visualization-only; rebuild later if Stage B/A needs |

`RefineLine.m` is referenced both by act calculation (slice 5) and by preset code (slice 8) — the single new home is `+sphynx/+acts/refineAct.m`, called from both packages.

### 7.5 Compute / viz / I/O separation

A strict rule for new code:

- `+sphynx/+{preprocess,bodyparts,zones,angles,acts,pipeline}/*.m` — **pure compute**. No `figure`, no `save`, no `VideoReader/VideoWriter`, no `imshow`. Pure functions with no side effects on the filesystem or display.
- `+sphynx/+viz/*.m` — **all plotting and video writing**. Honor `config.viz.headless` (set figure `Visible='off'` and never call `figure` interactively).
- `+sphynx/+io/*.m` — **all reading and writing of files** (DLC csv, preset .mat, workspace .mat, features csv, video metadata).

This rule is enforced by code review, not by tooling.

---

## 8. Test infrastructure

### 8.1 Framework

`matlab.unittest` (built into MATLAB R2020a, no external dependency). Functional test syntax (`function tests = nameTest`) is used because it is shorter and friendlier for first-time test writers.

### 8.2 Test layout

```
tests/
├── runAllTests.m                       runs everything by default; supports ('tag', 'fast'|'full')
├── unit/                              unit tests for pure functions
│   ├── wrapTest.m
│   ├── classifySquareTest.m
│   ├── classifyCircleTest.m
│   ├── partitionStripsTest.m
│   ├── computeVelocityTest.m
│   ├── smoothTraceTest.m
│   ├── refineActTest.m
│   ├── circleFitTest.m
│   ├── ellipseFitTest.m
│   ├── polygonFitTest.m
│   └── ...
├── synthetic/                         tests with synthetic-DLC fixtures
│   ├── freezingDetectionTest.m
│   ├── rearDetectionTest.m
│   ├── speedActsTest.m
│   ├── velocityClippingTest.m          ← Bug-4
│   ├── zoneVisitTest.m                 ← Bug-1
│   ├── headDirectionContinuityTest.m   ← Bug-2
│   └── edgeSmoothingTest.m             ← Bug-3
├── golden/
│   ├── buildSnapshots.m                one-shot: legacy BehaviorAnalyzer → tests/golden/snapshots/
│   ├── snapshots/
│   │   ├── NOF_H01_1D_Acts.mat         numeric Acts fields + body-parts aggregates only
│   │   ├── NOF_H01_2D_Acts.mat
│   │   ├── NOF_H01_3D_Acts.mat
│   │   └── NOF_H01_4D_Acts.mat
│   ├── NOF_H01_1D_GoldenTest.m
│   ├── NOF_H01_2D_GoldenTest.m
│   ├── NOF_H01_3D_GoldenTest.m
│   └── NOF_H01_4D_GoldenTest.m
└── smoke/
    └── demoPipelineTest.m              new pipeline runs NOF_H01_1D end-to-end without exception
```

### 8.3 Demo fixture (NOF_H01)

Available in `Demo/`:
- `Demo/DLC/NOF_H01_{1,2,3,4}D...csv` — DLC tracking
- `Demo/Preset/NOF_H01_{1,2,3,4}D_Preset.mat` — spatial preset
- `Demo/Video/NOF_H01_{1,2,3,4}D.mp4` — video
- `Demo/Behavior/NOF_H01_{1,2,3,4}D/.../NOF_H01_{1,2,3,4}D_WorkSpace.mat` — legacy outputs (~Jan 2026)

These four sessions are the test ground truth. The smoke test uses `NOF_H01_1D` specifically.

### 8.4 Golden snapshot scope

Each `tests/golden/snapshots/NOF_H01_{N}D_Acts.mat` contains a single struct with:

- `Acts` array with fields per act: `ActName`, `ActPercent`, `ActNumber`, `ActMeanTime`, `ActMedianTime`, `Distance`, `ActDuration`, `ActVelocity`.
- `BodyPartsAggregates` struct with `Tailbase.AverageDistance`, `Tailbase.AverageSpeed`, `Center.AverageDistance`, `Center.AverageSpeed`.
- `meta`: legacy-version git SHA, snapshot creation date, `n_frames`, `FrameRate`.

Per-frame time series are not stored. Approximate size: 1–3 KB per session, ~10 KB suite.

**Sprint-mode reduced scope:** initial golden built only for `NOF_H01_1D`. Snapshots for `NOF_H01_2D/3D/4D` are added later when the new pipeline is stable.

### 8.5 Tolerance policy

- Percentages and counts: `abs(new - old) / max(abs(old), 1) ≤ 0.05` (5%).
- Time durations: `abs(new - old) ≤ 1 / FrameRate` (1 frame).
- Distances and speeds: `abs(new - old) / max(abs(old), 1) ≤ 0.05`.

When a slice intentionally changes behavior (Bug-1, Bug-2, Bug-3, Bug-4 fixes), the relevant snapshots are regenerated and the commit message documents what changed and why. Snapshots are a living contract, not cement.

### 8.6 Synthetic fixtures

`+sphynx/+testing/*.m` produce synthetic DLC CSVs paired with synthetic Preset structs and an `expected` struct. Examples:

- `makeStationaryDLC(durationS, frameRate)` → animal stationary; `freezing` should detect ≥ duration.
- `makeRotatingMouseDLC(totalRotationDeg, durationS)` → mouse spins; head direction should be smooth and monotonic.
- `makeJumpyDLC(spikeFrame, spikeMagnitudePxl)` → walking with one outlier; velocity must be ≤ `maxVelocityCmS` everywhere after pipeline.
- `makeArenaAtFrameEdgeDLC(...)` → arena geometry that touches frame border; corner/wall/center must classify correctly.
- `makeZoneCrossDLC(zoneSequence)` → trajectory crosses wall→middle→center in known order.

### 8.7 Performance budgets

- `unit/` total: **< 30 s** (no video I/O).
- `synthetic/` total: **< 60 s** (synthetic DLC, no video I/O).
- `smoke/` total: **< 120 s** (one Demo session, no video output).
- `golden/` total: **< 300 s** (four Demo sessions, no video output).
- `runAllTests('tag','fast')` runs unit + synthetic + smoke. **< 4 min total.**
- `runAllTests('tag','full')` adds golden. **< 9 min total.**

### 8.8 Headless mode

`config.viz.headless = true` makes `+viz/*.m` no-ops or use `'Visible','off'`; `config.viz.makeVideo = false` skips video generation. Tests run with both flags so they never open windows or write MP4s.

---

## 9. Vertical slices

| # | Slice | Covers | Estimate |
|---|---|---|---|
| 0 | Test infra & branch setup | `sphynx-GUI` branch, `+sphynx/` skeleton, `tests/` skeleton, `runAllTests.m`, `buildSnapshots.m` (one-shot legacy → snapshots), `smoke/` placeholder, `+util/log`, `+util/progress` (infrastructure used by all later slices), README addendum on running tests | 1–2 d |
| 1 | Zones (Bug-1 + zone partitioning feature) | `+util/inMaskSafe`, `+util/circleFit`, `+util/polygonFit`, `+zones/classifySquare`, `+zones/classifyCircle`, `+zones/partitionStrips`. Unit tests + `zoneVisitTest` synthetic | 3–5 d |
| 2 | Angles (Bug-2) | `+angles/wrap`, `+angles/unwrapForSmooth`, `+angles/headDirection`. Unit tests + `headDirectionContinuityTest` (720° rotation) | 1–2 d |
| 3 | Velocity & smoothing (Bug-3 + Bug-4) | `+preprocess/smoothTrace` (mirror-pad edges), `+preprocess/computeVelocity` (≤50 cm/s clip before smooth). Unit tests + `velocityClippingTest`, `edgeSmoothingTest` | 2–3 d |
| 4 | Body-part traces | `+preprocess/cleanBodyPart`, `+preprocess/interpolateGaps`, `+util/replaceNaNinStruct`, `+bodyparts/identifyParts`, `+bodyparts/computeCenter`, `+bodyparts/relativeCoords` | 3–4 d |
| 5 | Acts (per-act detectors) | `+acts/refineAct`, `+acts/speedActs`, `+acts/freezing` (3 modes), `+acts/rear` (2 modes), `+acts/zoneAct`, `+acts/actStats`, `+acts/actParams` | 4–6 d |
| 6 | Pipeline integration + golden baseline | `+pipeline/defaultConfig`, `+pipeline/analyzeSession`, `+pipeline/+legacy/toLegacyOutput`, `+io/readDLC`, `+io/readPreset`, `+io/saveSession`. Smoke on NOF_H01_1D + golden on all 4 sessions; baselines updated where bug fixes intentionally change output | 3–4 d |
| 7 | Aggregation (SuperTable) | `+pipeline/runBatch` — refactor `Commander_behavior.m` aggregation using tidy table API (`stack`/`unstack`) | 2 d |
| 8 | CreatePreset decomposition | `+preset/pickGoodFrame`, `+preset/readArenaGeometry`, `+preset/readObjects`, `+preset/buildZonesSquare`, `+preset/buildZonesCircle`, `+preset/adjustExistingPreset`, `+preset/maskFromBorder`, `+preset/pixelsPerCm`, `+util/ellipseFit`, `+util/getLineEquation`, `+util/linesIntersection` | 4–5 d |
| 9 | CreatePreset GUI | `+sphynx/+app/CreatePresetApp.mlapp` — single-page UI over slice-8 functions | 5–7 d |
| 10 | Preprocess fix + audit | `processVideos.m:16–18` hardcode removal; `datestr(now)` modernization; unit tests for `getVideoMetadata`, `getTimestampMetadata`, `fixFPSmetadata`; README addendum | 2–3 d |

**Total estimate (sprint mode):** **1.5–2.5 calendar weeks** with the speedups below. Without speedups (single slice in flight, full sequential), the estimate was 4–9 weeks.

### 9.1 Sprint mode — speedups

The user opted for sprint mode (3–4 hours/day available). The following changes the schedule and how slices are produced:

1. **Batched slice delivery.** Independent slices are merged into single delivery passes:
   - **Pass A — Bug fixes:** slices 1 + 2 + 3 (zones, angles, velocity). Mutually independent. Code, tests, and findings delivered together.
   - **Pass B — Core pipeline:** slices 4 + 5 + 6 (body parts, acts, integration + golden baseline).
   - **Pass C — Aggregation & preset:** slices 7 + 8 (SuperTable, CreatePreset decomposition).
   - **Pass D — GUI:** slice 9 (App Designer).
   - **Pass E — Cleanup:** slice 10 (Preprocess).
   - Slice 0 (test infra) is the prerequisite of everything; delivered alone first.

2. **End-of-pass "homework" packets.** Each delivery ends with an explicit list of MATLAB commands for the user to run — `runAllTests`, smoke checks, golden diff inspection. The next pass starts from the homework results.

3. **Parallel-when-possible.** Within Pass A, slices 1/2/3 do not block each other. Within Pass B, slice 6 depends on 4 and 5; 4 and 5 are independent.

4. **Reduced golden scope in first pass.** Golden snapshot initially built only for `NOF_H01_1D` (smoke session). Snapshots for `NOF_H01_2D/3D/4D` are added in a later pass once the new pipeline is stable. Justification: golden's main value is regression detection during decomposition; one session catches > 90% of regressions, and adding sessions late is cheap.

5. **Tag points adjusted to passes:** `stage-c-pass-A-bugs-fixed`, `stage-c-pass-B-pipeline-ready`, `stage-c-pass-C-preset-ready`, `stage-c-pass-D-gui-ready`, `stage-c-complete`.

After each pass with green tests: candidate for merge into `master` (decision per user).

---

## 10. CreatePreset GUI (slice 9)

**File:** `+sphynx/+app/CreatePresetApp.mlapp`. Launch via `sphynx.app.CreatePresetApp()`.

**Architecture:**
- The app is a UI shell only. All logic is delegated to `+sphynx/+preset/*.m` (delivered in slice 8).
- App holds a single state struct `app.PresetState` populated incrementally.
- App produces a preset `.mat` file in the same shape as legacy `CreatePreset.m`: `Options`, `Zones`, `ArenaAndObjects`. This guarantees the preset works with both the legacy `BehaviorAnalyzer.m` and the new `analyzeSession`.

**Single-page layout (no tabs):**

```
┌─────────────────────────────────────────────────────────────┐
│ sphynx — Create Preset                                      │
├─────────────────────────────────────────────────────────────┤
│ [Load video...]  [Choose output dir...]  [Load preset...]   │
│ Video:  NOF_H01_1D.mp4                                      │
│ Output: e:\Demo\Preset\                                     │
├─────────────────────────────────────────────────────────────┤
│ Pixels per cm: [Calibrate from frame]   = 17.4              │
│ Experiment type: [Novelty OF        ▾]                      │
├─────────────────────────────────────────────────────────────┤
│ Arena geometry: [Polygon ▾]   [Pick arena points]           │
│ Arena defined: ✓ (4 corners)                                │
├─────────────────────────────────────────────────────────────┤
│ Objects: [+ Add]  [Remove selected]                         │
│   • Object1 (Circle)                                        │
│   • Object2 (Polygon)                                       │
├─────────────────────────────────────────────────────────────┤
│ Zones strategy: [corners-walls-center ▾]                    │
│   Wall width (cm):   [3.0]                                  │
│   Corner width (cm): [auto = wall × √2]                     │
│   Center is rest                                            │
│   [Compute zones]   [Preview]                               │
├─────────────────────────────────────────────────────────────┤
│ Preview pane (image with overlays for arena/objects/zones)  │
├─────────────────────────────────────────────────────────────┤
│ [Save preset]   [Run analyzeSession with this preset]       │
└─────────────────────────────────────────────────────────────┘
```

For `Zones strategy`, dropdown options correspond to slice 1 features:
- `corners-walls-center` (legacy default for square)
- `strips-N` (with N input — new feature 1.3 for square)
- `circle-rings` (with ring widths — new feature 1.3 for round)
- `none` (no spatial subdivision)

The legacy `CreatePreset.m` is **not** removed. It stays in the repo as a fallback.

**Test policy:** GUI is exercised through a manual checklist (~50 items); the underlying `+preset/*.m` functions are unit-tested in slice 8.

---

## 11. Preprocess (slice 10)

`Preprocess/` is a self-contained subproject for video metadata, FPS alignment, and re-encoding. It is not absorbed into `+sphynx/`. Stage-C touches:

- **Fix-P1:** `Preprocess/processVideos.m:16–18` — remove the three hardcoded lines that overwrite input arguments.
- **Fix-P2:** `Preprocess/processVideos.m:36` — replace `datestr(now)` with `datetime("now")`.
- **Add tests:** `tests/unit/+preprocess/getVideoMetadataTest.m`, `getTimestampMetadataTest.m`, `fixFPSmetadataTest.m`.
- **Doc:** README addendum describing the Preprocess pipeline.

No decomposition; the file is already reasonably structured.

---

## 12. Git strategy

- Branch: `sphynx-GUI` from current `master`.
- Each slice = 1 or more commits with descriptive messages.
- After a slice with green tests: candidate for merge into `master` (decision per user).
- Tags after key milestones: `stage-c-slice-3-bugs-fixed`, `stage-c-slice-6-pipeline-ready`, `stage-c-slice-9-gui-ready`.

---

## 13. Risks

| | Risk | Mitigation |
|---|---|---|
| R1 | User has not written tests before | All tests written by Claude with thorough comments. Test learning is deferred per user decision; user reads at their own pace |
| R2 | No CI; tests run locally only | `runAllTests('tag','fast')` before each commit. CI deferred to Goal A |
| R3 | MATLAB pinned to R2020a | Strict R2020a-compatible code. `inputParser` over `arguments` block where preference is debatable. Will flag any need for newer features |
| R4 | `.mlapp` is binary; poor diffs | All logic lives in `+sphynx/+preset/*.m` (text). `.mlapp` contains only UI wiring, minimal diffs |
| R5 | Behavior drift after bug fixes | Every snapshot regeneration is documented in commit messages with side-by-side comparison on at least one Demo session |
| R6 | Old `BehaviorAnalyzer.m` could pick up new functions via `genpath` | New function names deliberately differ from legacy (`circleFit` vs `circfit`, etc.). No collision |
| R7 | User cannot run GUI tests | Manual checklist for `CreatePresetApp` provided; underlying `+preset/*.m` is unit-tested |

---

## 14. Decisions log

| Decision | Choice |
|---|---|
| Approach | Incremental vertical slices (not waterfall, not architecture-first) |
| Scope | Core only (`BehaviorAnalyzer.m`, `CreatePreset.m`, `functions/`) + `Preprocess/` lite + 1 reference Commander |
| API | Free to break; legacy continues working via `addpath(genpath(...))` |
| Old code | Untouched on `sphynx-GUI` branch |
| `functions/*.m` policy | Bring needed functions into `+sphynx/`, audit, fix, unit-test; legacy copies stay |
| Test framework | `matlab.unittest`, functional syntax |
| Golden snapshot scope | Numeric `Acts` fields + body-parts aggregates; no time series |
| Golden tolerance | 5% for percentages/distances, 1 frame for durations |
| Smoke session | NOF_H01_1D |
| Video outputs | Optional via `config.viz.makeVideo` |
| `*_WorkSpace.mat` | Single save at end |
| `Features.csv` | Kept as legacy CSV |
| `ActDuration` location | Computed in `+sphynx/+acts/actStats.m` (not in batch script) |
| GUI layout | Single page, no tabs |
| Preprocess | Stays as separate subproject |
| App location | `+sphynx/+app/CreatePresetApp.mlapp`, launched as `sphynx.app.CreatePresetApp()` |
| Branch name | `sphynx-GUI` |
| Test learning | Deferred; Claude writes all tests with comments |
| Delivery mode | Sprint — batched passes A–E (see 9.1), 1.5–2.5 weeks calendar |
| Initial golden scope | Only `NOF_H01_1D`; other 3 sessions added in a later pass |

---

## 15. Out of scope (explicit)

The following are intentionally not part of Stage C:

- Unifying the 18 forks in `Projects/` (Goal B).
- Unifying the 18 commanders in `Cross-analysis/` (Goal B).
- Refactoring 3DM-specific code (`Three_DM_z_coordinate.m`, `analyze_movement_3D.m`, `create_3d_trajectory_gif.m`, etc.).
- CI / GitHub Actions setup (Goal A).
- Publication-grade documentation (Goal A).
- Unifying preset format across experiments (Goal B).
- GUI for batch analysis (Goal B/A).
- Decomposing `Preprocess/processVideos.m` beyond bug fixes (already reasonably structured).
- Backwards-compatibility shims; legacy code continues to use legacy functions, new code uses new functions, both coexist.

---
