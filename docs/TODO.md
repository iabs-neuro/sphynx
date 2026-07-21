# Sphynx — Deferred TODO

Single source of truth for everything not done yet. Per-tab + cross-cutting + macro.

## Scoring

Each task has **priority** (how badly we want it) and **complexity** (how big a sit-down).

**Priority:**
- **P1** — next polish round, blocker for current workflow.
- **P2** — nice post-MVP, do soon after P1s drain.
- **P3** — larger effort, new feature, or pre-req for a new experiment type.
- **P4** — macro decision (re-architecture, language switch).

**Complexity:**
- **C1** — < 1 h. Wire one field, fix a label, flip a default.
- **C2** — < 1 day. Single function rewrite, one new helper + tests.
- **C3** — 1-3 days. Multi-module feature, schema change, new pipeline pass.
- **C4** — > 3 days. New module / tab / architecture-level rework.

## Tab status

| # | Tab                  | State        | Controller LoC |
|---|----------------------|--------------|----------------|
| 1 | Create Preset        | frozen       | inline in CreatePresetApp |
| 2 | Preprocess Tracking  | stable       | 1918 |
| 3 | Define Acts          | active dev   | 1543 |
| 4 | Analyze Session      | active dev   | 1091 |
| 5 | Batch Analysis       | stable       | 930  |
| 6 | Make Output Table    | active dev   | 633  |
| 7 | Plot Data `*`        | **WIP**      | 289  |
| 8 | Preprocess Video `*` | **WIP**      | 162  |
| 9 | Synthetic Data `*`   | **WIP**      | 244  |

Tabs marked `*` show an asterisk in the GUI title — feature-incomplete, not on the MVP path.

---

# Per-tab TODO

## 1. Create Preset (frozen — see `feedback_createpreset_frozen` memory)

Do not touch without explicit user ask.

- [ ] **P3 / C2** Verify "download preset" feature still works end-to-end.
- [ ] **P3 / C2** Zones display correctly when loading a new video on top of an existing preset.
- [ ] **P3 / C1** Warnings on duplicated zone definitions / nonsense states.
- [ ] **P3 / C2** Object-copy with auto-numbering: copying `object2` produces `object3` if free, else next. Opens interactive draw menu so the copy can be repositioned. Driven by Barnes maze (many identical objects at different locations).

## 2. Preprocess Tracking

- [ ] **P3 / C2** Layout rework: panels 1+2 stacked left, 3 top-right, plot strip full-width below.
- [ ] **P2 / C1** Restore the lost "log Y" toggle for the likelihood histogram.
- [ ] **P3 / C2** Optional likelihood-vs-time plots (X and Y), checkbox-gated.

## 3. Define Acts

- [ ] **P2 / C3** **Per-class-of-objects act constructor.** Today the Define Acts UI lets you pick zones individually (target, object1..N, platform). For paradigms with N>5 object holes this is tedious and error-prone. Want: a "class" abstraction in the act constructor so the user picks the whole class once (e.g. "all hole_realout" or "all hole_real") and the act expands per-zone automatically at evaluation time. Touches `+sphynx/+acts/emptyAct.m` (new `zoneClass` field), `+sphynx/+acts/applyAct.m::applySimple` (resolve class to current preset's zone roster), `+sphynx/+app/DefineActsTabController.m` (UI: class picker + per-class overrides). Aligns with how Barnes defaults already use 19 OR-ed zones per `nose_at_any_hole` -- generalise that pattern. (added 2026-06-28)

- [ ] **P2 / C3** **Complex-acts redesign.** Current Complex tab is cramped and rigid. Wanted:
  - Wider Name field (col 2 is `1x` while col 1 is 120px label).
  - More compact layout (combine label+widget rows where possible).
  - Expression-style composition. Examples:
    - `Act1 OR Act2 EXCLUDE Act3`
    - `Act1 + dt1 + Act2 + dt2 + Act3` — sequence-style with explicit gaps.
  - Schema today supports only one op (intersect/union/exclude/sequence) over a flat component list + one global `seqDelaySec`. Need an ordered token list parsed into a tree. Touches `+sphynx/+acts/emptyAct.m`, `buildComplexAct.m`, `applyAct.m::applyComplex`.

- [ ] **P2 / C2** Act post-filters: median window + min-duration. Add fields to `+sphynx/+acts/emptyAct.m`, `buildSimpleAct.m`, `buildComplexAct.m`. New helper `+sphynx/+acts/filterActArray.m`. Apply after `evalActsLibrary` in `+sphynx/+pipeline/analyzeSession.m:262`. UI: two numeric fields in Simple/Complex constructor.
- [ ] **P2 / C1** Make-video preview: confirm `implay` zoom + window resize work on user's machine; graceful fallback if R2020a's `Visual.ScaleFactor` API differs.
- [ ] **P3 / C1** Frame-scrubber inside make-video player — `implay` already has a timeline; revisit only if finer control wanted.

## 4. Analyze Session

- [ ] **P1 / C1** «Min run, s» field on the config panel. Currently hardcoded to `cfg.acts.minRunSeconds = 0.25` in `defaultConfig.m`. Wire as `obj.MinRunField.Value` in `runAnalyze()`.
- [ ] **P2 / C3** **Bucket exclusivity breaks the per-act refine.** Order today: per-act `refineActArray` (bridge then drop) → custom dedup → bucket priority pass. The priority pass runs *after* refine, so `walk` ends up with 1-2-frame fragments when `locomotion` claims its frames. Same for spatial (`walls_and_corners` losing chunks to `corners`/`walls`). Stats show inflated `ActNumber` + tiny `ActMeanTime`. Two routes:
  - (a) **C2** — re-run `refineActArray` after the exclusivity pass. Quick. May re-introduce overlap if a bridged hole crosses bucket-mate territory.
  - (b) **C3** — joint categorical refine for the whole bucket. Cleaner, more code.
- [ ] **P2 / C1** Move `FreezingMode` / `RearMode` pickers to Define Acts (or per-experiment defaults). Conceptually they describe the act library, not the analysis. Defaults stay `'HeadAndCenter'` / `'TailbasePaws'`.
- [ ] **P2 / C2** Multi-bodypart trajectory: dropdown to choose which parts overlay on `GoodVideoFrame`.
- [ ] **P2 / C2** Split bodyparts-trajectory plot into two files per bodypart: `trajectory_<bp>.{png,fig}` (2D over `GoodVideoFrame`) and `timeseries_<bp>.{png,fig}` (X(t) / Y(t) / likelihood(t)). Both saved in `<sessionDir>/bodyparts_trajectory/`.
- [ ] **P2 / C1** Settings load: drop the hard "Analysis settings .mat" filename filter so any `.mat` is acceptable. `applySettings` already does defensive `isfield` checks.
- [ ] **P2 / C2** Etogram rows grouped by category headers (built-in / custom / zone) with cluster spacing.
- [ ] **P3 / C2** Customisable speed-vs-time plot: act-bands as background patches (rest/walk/locomotion).
- [ ] **P3 / C3** Egocentric trajectory + heading-angle trace for direction-aware acts.

## R28 audit findings (2026-06-28) -- HIGH-RISK items to land first

- [ ] **P1 / C1** **BatchAnalysisTab preproc-settings picker is dead.** UI captures `obj.PreprocessSettingsField.Value` but `runBatch` (`+sphynx/+app/BatchAnalysisTabController.m:180-217`) never copies it into `cfg.paths.preprocessSettings`. Auto-discovery silently substitutes. Fix: 1 line analog of `AnalyzeSessionTabController.m:116-119`.
- [ ] **P1 / C2** **Barnes 19-hole default leaks through.** `+sphynx/+pipeline/barnesSessionMetrics.m:62` and `+sphynx/+acts/actsLibraryBarnesDefaults.m:50` both default `NumObjects=19`. Calls at `analyzeSession.m:461` and `DefineActsTabController.m:94-100` never pass the preset's actual hole count. With a 5-hole preset: angular metrics computed against a phantom 20-slot ring (18 deg step instead of 60), and "Load Barnes default" seeds 14 phantom acts (hole6..hole19 x 3 categories) that evaluate to all-zero. Thread `numel(<object* zones in preset>)` into both call sites.
- [ ] **P1 / C1** **applyAct.m unguarded `ctx.frameRate`** at `+sphynx/+acts/applyAct.m:63-64`. When fps is NaN, `round(durSec * NaN) = NaN -> lengths < NaN` is always false, silently nullifying the per-act min-duration filter (R23). Guard in `makeActContext.m:23` + fallback to a known cfg.acts.minRunSeconds with `log warn`.
- [ ] **P1 / C1** **Typo in DefineActs body-parts dropdown.** `+sphynx/+app/DefineActsTabController.m:200` `'righforelimb'` (missing `t`). Selecting it silently fails to resolve.
- [ ] **P2 / C1** **`bcIdx` silent-fallback-to-1 in 4 sites.** `saveSessionPlots.m:38`, `renderActsVideo.m:136`, `AnalyzeSessionTabController.m:945`, `MakeOutputTableTabController.m:332-334`. On SuperAnimal sessions where `bodycenter` is `mouse_center`, `idx=1` silently picks `nose` -> wrong trajectory trail / velocity readout / Average totals. Route all 4 through `sphynx.bodyparts.resolvePart` with a `warn` on miss.
- [ ] **P2 / C1** **`makeActContext.m:27` `pxlPerCm=1` silent fallback** (and 4 more sites: `saveSessionPlots.m:40`, `AnalyzeSessionTabController.m:273,987`, `BatchAnalysisTabController.m:773`). When `result.Options.pxl2sm` missing, distances are pixels labelled as cm. Pick one: hard-error on missing OR `warn` + propagate explicit NaN.
- [ ] **P2 / C2** **DefineActs Make-video bypasses Preproc Settings.** `+sphynx/+app/DefineActsTabController.m:971-977` and `:1180-1186` build cfg without `cfg.paths.preprocessSettings`. Preview diverges from Analyze Session results. Add picker or auto-inherit from the parent app.
- [ ] **P2 / C1** **`detectSessionStartFrame.m:40` WindowFrames=30 is fps-implicit.** Breaks on 25 / 60 fps videos. Convert to seconds (`WindowSec * frameRate`).
- [ ] **P2 / C1** **Kalman noise params dead when smoothingMethod != kalman.** `applyPerPartSettings.m:145-156` makes them mutually exclusive with the smoothdata branch. Silently ignored. Either honour them universally or `warn` when they're set but unused.
- [ ] **P3 / C1** **Synonym map gaps.** `+sphynx/+bodyparts/identifyParts.m:30-53` lacks `left_eye`, `right_eye`, `mid_back*`, `tail2..tail5`, `tail_end`. Not load-bearing today but useful for future acts.
- [ ] **P3 / C1** **Document `identifyParts.m` first-match rule.** When both `neck` and `head_midpoint` are present, the earlier in kept-list order wins for `HeadCenter`. Surprising; document or make explicit-preference.
- [ ] **P3 / C2** **4-way duplication of defaults.** `minDurationSec=0.25` (applyAct.m:54, emptyAct.m:33, buildSimpleAct.m:11, buildComplexAct.m:10) + Kalman defaults (kalmanFilter2D.m:35-36, applyPerPartSettings.m:185-186, PreprocessTabController.m:881-882) + `maxGapSec=0.25` (no cfg counterpart at all). Centralise in `defaultConfig` + `sphynx_defaults.jsonc`.

## R31 ultra-audit findings (2026-07-20) -- see `docs/audit-r2025-engine-bugs.md`

Multi-agent adversarial bug audit of the engine. 8 confirmed. Being fixed this
session via TDD; left here for traceability.

- [ ] **P1 / C2** **Golden regression test is missing.** `tests/golden/` has only
  `buildSnapshots.m` (generator) + snapshot `.mat`, NO comparison test, so
  `runAllTests('golden'|'full')` finds 0 tests and README overstates coverage.
  Write a real golden test: run `sphynx` pipeline on `NOF_H01_1D` (DLC+Preset),
  compare numeric Acts fields to `snapshots/NOF_H01_1D_Acts.mat` with tolerance.
  Gives a numeric-drift guard for the R2020a->R2025b move. Do this BEFORE large
  refactors so drift is caught.
- [x] **2026-07-20 (R31, TDD)** `+pipeline/analyzeSession.m` (HIGH) freezing() OOB when body center synthesized -- synthetic center now a first-class trace row. `analyzeSessionSyntheticCenterTest`.
- [x] **2026-07-20 (R31, TDD)** `+stats/runTest.m` RM-ANOVA F now read from the within-effect row (was intercept). `runTestRMAnovaFStatTest`.
- [x] **2026-07-20 (R31, TDD)** `+pipeline/analyzeSession.m` per-act velocity/distance now uses the synthetic center (same fix as the HIGH item).
- [x] **2026-07-20 (R31, TDD)** `+acts/applyAct.m` freezing/allInZone now degrade to resolvable parts instead of zeroing. `applyActMissingPartTest`.
- [x] **2026-07-20 (R31, TDD)** `+preset/readObjects.m` added `class` to preallocation to match readArenaGeometry. `readObjectsFieldSetTest`.
- [x] **2026-07-20 (R31, TDD)** `+preprocess/computeVelocity.m` handles 1 / 0 surviving samples without interp1 crash. `computeVelocitySingleSampleTest`.
- [x] **2026-07-20 (R31, TDD)** `+preprocess/makeSyntheticDLC.m` 'mixed' composes likelihood (min) instead of clobbering. `makeSyntheticDLCOutlierParamsTest`.
- [x] **2026-07-20 (R31, TDD)** `+preprocess/makeSyntheticDLC.m` GapCountPerPart=0 injects no gap. `makeSyntheticDLCOutlierParamsTest`.

## 5. Batch Analysis

- [ ] **P2 / C1** Surface a Min-run-s field on Batch (mirror of Analyze, once Analyze gets one).
- [ ] **P2 / C1** Resume-on-error: when one session fails, log and continue instead of aborting the rest of the batch.
- [ ] **P3 / C2** Progress bar with ETA based on average session time.

## 6. Make Output Table

- [ ] **P2 / C2** **Outlier warning system.** When a value falls far from the per-group / per-session distribution (e.g. mouse A07 distance 3x the mean), flag in log + tint the offending Wide-preview uitable cells. Heuristic: per `(group, session, metric)` cell-set compute median + MAD; flag if `|x - median| > k * MAD` (start k=3.5). Distance first, then velocity / percent. Log line: `[WARN] mouse=A07 distance_cm_4D=12345 outlier (median=4200, MAD=900)`. Use `addStyle(...,'BackgroundColor',[1 0.9 0.9])`. Tunable threshold field in options.
- [ ] **P3 / C1** Per-metric override of the rounding rule (currently fixed: cm->int, m->2dec, velocity->1dec).
- [ ] **P3 / C2** Export per-group summary stats (n, mean, sem) as a separate CSV section or sheet.
- [ ] **P3 / C2** Reorder columns in Wide: keep per-act blocks together (currently `act1_metric1_s1 act1_metric1_s2 ... act1_metric2_s1 ...`; alternative: group by metric → all sessions of one metric adjacent).

## 7. Plot Data `*` (WIP)

Currently has a table picker + plot button skeleton — needs full design.

- [ ] **P2 / C3** Define plot vocabulary: line/bar/scatter/box for grouped data; error-bar variants (SEM, SD, CI); paired vs unpaired; per-session vs collapsed-across-sessions.
- [ ] **P2 / C2** Auto-detect numeric columns vs grouping columns from loaded super-table.
- [ ] **P2 / C2** Group-by selector (group / line / sex / any ID_* column).
- [ ] **P2 / C2** Save plot as PNG + FIG with sane defaults (300 dpi, Arial 12 pt).
- [ ] **P3 / C3** Pairwise stats overlay: t-test / Mann-Whitney / Kruskal with multiple-comparison correction; significance bars on the plot.
- [ ] **P3 / C2** Custom Y-axis filter per plot — clip outliers above a percentile so the rest is readable.

## 8. Preprocess Video `*` (WIP)

Currently can scan a folder and re-encode FPS via existing tool functions.

- [ ] **P2 / C2** Trim video to start/end frames (preset-driven or manual).
- [ ] **P2 / C2** Crop to ROI saved in preset.
- [ ] **P3 / C2** Batch-rename mode using a user-supplied dict (similar to `tools/rename_4D_behavior.m` but per-session).
- [ ] **P3 / C3** Re-encode pipeline: target fps + codec + resolution + audio strip, all in one pass.

## 9. Synthetic Data `*` (WIP)

Currently generates a fake DLC trace with a single motion model + outlier mode.

- [ ] **P3 / C2** Multiple motion models on the same trace (e.g. rest -> walk -> locomotion segments with controllable durations).
- [ ] **P3 / C2** Scripted act events (insert a rear / freezing burst at frame N).
- [ ] **P3 / C2** Save synthetic preset + DLC csv as a regression test fixture for downstream pipeline.
- [ ] **P3 / C3** Multi-mouse synthetic for testing tracking-confusion scenarios.

---

# Cross-cutting

## Tab navigation / app-wide

- [ ] **P3 / C1** Numbered tab titles: prefix with step number (`1. Create Preset`, `2. Preprocess`, ...).
- [ ] **P3 / C2** App-wide state propagation: project root / current session / current preset shared across tabs (today inherited piecemeal via `ParentApp.State.projectRoot`).
- [ ] **P3 / C3** Project tab at the start: Create / Load / Save project. Creates the standard folder skeleton, fills paths app-wide, writes a project metadata file (description, library, expected act count).

## Metadata / experiment system

- [ ] **P2 / C2** Add Barnes maze to the experiment-type list (`ExpTypeDropDown`).
- [ ] **P3 / C3** Per-experiment defaults: each experiment id (Novelty_OF, Odor track, Barnes, ...) carries expected object count, arena geometry, default acts library, default zone strategy, default zone widths. Saving a preset with mismatched object count -> warning.
- [ ] **P3 / C2** Metadata accumulation: each tab appends to a project metadata struct; final super-table writes warnings for outliers / weird values.
- [ ] **P3 / C2** Extract list of mice from a batch dir, allow excluding mice, attach per-mouse metadata for the super-table.

## Tracker compatibility

- [ ] **P3 / C3** SLEAP / Bonsai compatibility (in addition to DLC). Bonsai pulls trajectories — needs a body-part rename step on Preprocess. Investigate AnimalPose, Lightning Pose too.
- [ ] **P3 / C2** Per-session standard outputs: features table, kinematogram, egocentric kinematogram, etogram (multiple variations) — produced automatically.

## Universal act-derived features

- [ ] **P2 / C2** Time-to-completion of a specific act: when did this act first finish?
- [ ] **P2 / C2** Time-to-first-completion of the first act in a sequence.
- [ ] **P2 / C1** Audit `actStats` for missing fields; expose any that aren't currently surfaced in the super-table.

---

# Barnes maze metrics (specific to that paradigm — needs Barnes geometry first)

**Training-day metrics:**
- [ ] **P3 / C2** Time to leave start platform.
- [ ] **P3 / C2** Primary latency — time until the target hole is found.
- [ ] **P3 / C2** Total latency — time until the mouse enters the hole.
- [ ] **P3 / C2** Primary errors — count of incorrectly checked holes.
- [ ] **P3 / C2** Total errors — count of dips into wrong holes.
- [ ] **P3 / C2** Path length.
- [ ] **P3 / C2** Angular distance of first checked hole from target (deg).
- [ ] **P3 / C3** Search-strategy classification: spatial / serial / random (Pitts 2018, https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5891830/figure/BioProtoc-8-05-2744-g004/).
- [ ] **P3 / C2** Ordinal index of the target hole among the checked holes.
- [ ] **P3 / C2** Mean angular distance of all checked holes from target / count of checked holes.

**Test-day metrics:**
- [ ] **P3 / C2** Time to leave start platform.
- [ ] **P3 / C2** Total time spent on start platform (including returns).
- [ ] **P3 / C2** Latency.
- [ ] **P3 / C2** Path length.
- [ ] **P3 / C2** Angular distance of first checked hole from target.
- [ ] **P3 / C2** Number of target-hole checks.
- [ ] **P3 / C2** Number of non-target-hole checks.
- [ ] **P3 / C2** Mean angular distance of all checked holes from target.
- [ ] **P3 / C2** Time spent near the target hole.
- [ ] **P3 / C3** Averaged tracks across mice in a group.

---

# Scattered `% TODO` markers in code

These are inline notes the user / Claude left during development. Resolve or delete.

- [ ] **P3 / C1** `+sphynx/+preprocess/cleanBodyPart.m:30` — expose all magic numbers (FrameWidth/FrameHeight) as named params.
- [ ] **P3 / C1** `+sphynx/+acts/speedActs.m:23` — expose `midPointCmS = mean(rest, loc)` as a named param.
- `+sphynx/+app/CreatePresetApp.m:1522` — note about TODO #7 (strips along Polygon sides). This is a historical comment, not a pending task. Convert to plain comment or delete next time CreatePreset is unfrozen.
- `+sphynx/+app/CreatePresetApp.m:1654` — note about TODO #6 (shared-pivot rotation). Same — historical, can be cleaned up.
- `+sphynx/+pipeline/analyzeSession.m:310` — refers to this file. Self-reference, no action.
- `+sphynx/+app/AnalyzeSessionTabController.m:104` — refers to this file. Self-reference, no action.

---

# Macro decisions (P4 — need user discussion)

- [ ] **P4 / C4** Install latest MATLAB, port the codebase, leverage modern toolboxes.
- [ ] **P4 / C4** Rewrite in Python.

---

# Recently done (kept here so we can see velocity)

- [x] **2026-05-11** WNOF 4D rename: `tools/rename_4D_behavior.m`. 30 folders, 0 errors.
- [x] **2026-05-11** All session files prefixed: `tools/add_session_prefix.m`. 2404 files renamed, 0 errors.
- [x] **2026-05-11** Make Output: SessionName from folder name, NamePattern allows `1D_1T` style. `ID_mouse` with exp prefix auto-detected.
- [x] **2026-05-11** Make Output: focus retention after pickers, Distance unit (cm/m) + scope (all/general-only), rounding (cm->int, m->2dec, velocity->1dec).
- [x] **2026-05-11** `buildSuperTable`: arbitrary `ID_*` metadata columns pass through; xlsx accepted; no auto `line`/`group` if user didn't provide.
- [x] **2026-05-11** `buildSuperTable`: short-form metadata accepted (`ID_mouse,ID_group` -> auto cross-join with parsed sessions).
- [x] **2026-05-10** Make Output Table tab: per-act metric matrix (rows=acts, cols=metrics, logical checkboxes); save/load .mat default set; `MetricsByAct` param in `buildSuperTable`.
- [x] **2026-05-10** Speed + spatial bucket exclusivity via post-refine priority pass in `analyzeSession`.
- [x] **2026-05-10** Session-wide bodycenter stats header on Analyze; `AverageDistance` fixed to cm.
- [x] **2026-05-10** Rear auto-threshold via robust statistics (`prctile(s,7)` and `median - 1.5*std`, clamped [1.5, 3.5] cm).
- [x] **2026-05-09** Render acts in Analyze shares `+sphynx/+pipeline/renderActStitched.m` with Define Acts.
- [x] **2026-05-08** Save session-wide plots (trajectory / heatmap / speed) as PNG + FIG in Analyze + Batch.
- [x] **2026-05-08** Batch Analysis rewrite: auto-pair DLC + video + preset by ID prefix, Analyze parity.
