# Sphynx GUI — deferred TODO

Ranked P1..P4. P1 = next round of polish, P2 = nice-to-have post-MVP,
P3 = larger effort or pre-condition for new experiment types,
P4 = macro-decisions / re-architecture.

## CreatePreset (frozen — see `feedback_createpreset_frozen` memory)

- [ ] **P3** Verify "download preset" feature still works end-to-end.
- [ ] **P3** Zones display correctly when loading a new video on top of an existing preset.
- [ ] **P3** Warnings on duplicated zone definitions (or other nonsense states).
- [ ] **P3** Object-copy with auto-numbering: copying `object2` produces `object3` if free, else next; opens interactive draw menu so the copy can be repositioned. Driven by Barnes maze where many identical objects sit at different locations.

## Preprocess Track (stable — used by user's existing settings)

- [ ] **P3** Layout rework: panels 1+2 stacked left, 3 top-right, plot strip full-width below.
- [ ] **P2** Restore the lost "log Y" toggle for the likelihood histogram.
- [ ] **P3** Optional likelihood-vs-time plots (X and Y), checkbox-gated.

## Define Acts

- [ ] **P2** **Complex-acts redesign.** Current Complex tab is cramped and rigid. Wanted:
  - Wider Name field (current is narrow because grid column 2 is `1x` while column 1 is 120px label).
  - More compact overall layout (fewer separate rows; combine label+widget where possible).
  - Expression-style composition. Goal: build acts as equations, e.g.
    - `Act1 OR Act2 EXCLUDE Act3`
    - `Act1 + Δt1 + Act2 + Δt2 + Act3` — sequence-style with explicit gap durations between every pair.
  - Currently the schema only supports a single op (intersect/union/exclude/sequence) over a flat list of components, with one global `seqDelaySec`. Need a richer model — probably an ordered list of tokens (act names interleaved with operators / gap durations), parsed into a tree. Schema change in `+sphynx/+acts/emptyAct.m` + `buildComplexAct.m` + `applyAct.m::applyComplex`.

- [ ] **P2** Act post-filters: median window + min-duration. Add fields to `+sphynx/+acts/emptyAct.m`, `buildSimpleAct.m`, `buildComplexAct.m`. New helper `+sphynx/+acts/filterActArray.m`. Apply after `evalActsLibrary` in `+sphynx/+pipeline/analyzeSession.m:262`. UI: two numeric fields in Simple/Complex constructor.
- [ ] **P2** Make-video preview: confirm `implay` zoom + window resize land correctly on user's machine; fall back gracefully if R2020a's `Visual.ScaleFactor` API differs.
- [ ] **P3** Frame-scrubber inside the make-video player — `implay` already has a timeline scrubber; only revisit if user wants finer control.

## Analyze Session

- [ ] **P2** Multi-bodypart trajectory: dropdown to choose which parts overlay on `GoodVideoFrame`.
- [ ] **P2** Etogram rows grouped by category headers (built-in / custom / zone) with cluster spacing.
- [ ] **P3** Customizable speed-vs-time plot: act-bands as background patches (rest/walk/locomotion).
- [ ] **P3** Egocentric trajectory + heading-angle trace for direction-aware acts.

## Big features / new modules

- [ ] **P3** Numbered tabs: prefix tab titles with their step number (1. CreatePreset / 2. Preprocess / 3. Define Acts / ...).
- [ ] **P2** Add Barnes maze to the experiment-type list (`ExpTypeDropDown`).
- [ ] **P3** Per-experiment defaults: each experiment id (Novelty_OF, Odor track, Barnes...) carries its expected number of objects, arena geometry, default acts library, default zone strategy, default zone widths. Saving a preset with mismatched object count → warning.
- [ ] **P3** Project tab at the start: "Create / Load / Save project." Creates the standard folder skeleton, fills paths app-wide, writes a project metadata file (description, library choice, expected act count).
- [ ] **P3** Metadata accumulation: each tab appends to a project metadata struct; the final super-table writes warnings for outliers / weird values.
- [ ] **P3** Extract list of mice from a batch dir, allow excluding mice, attach per-mouse metadata for the super-table.
- [ ] **P3** SLEAP / Bonsai compatibility (in addition to DLC). Bonsai pulls trajectories — needs a body-part rename step on the Preprocess tab. Investigate other current popular pose-estimation tools (e.g. AnimalPose, Lightning Pose).
- [ ] **P3** Per-session standard outputs: features table, kinematogram, egocentric kinematogram, etogram (multiple variations) — produced automatically.

## Barnes maze metrics (specific to that paradigm)

**Training-day metrics:**
- [ ] **P3** Time to leave start platform.
- [ ] **P3** Primary latency: time until the target hole is found.
- [ ] **P3** Total latency: time until the mouse enters the hole.
- [ ] **P3** Primary errors: count of incorrectly checked holes.
- [ ] **P3** Total errors: count of dips into wrong holes.
- [ ] **P3** Path length.
- [ ] **P3** Angular distance of the first checked hole from the target hole (degrees).
- [ ] **P3** Search strategy classification: spatial / serial / random (see Pitts 2018, https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5891830/figure/BioProtoc-8-05-2744-g004/).
- [ ] **P3** Ordinal index of the target hole among the checked holes.
- [ ] **P3** Mean angular distance of all checked holes from target / count of checked holes.

**Test-day metrics:**
- [ ] **P3** Time to leave start platform.
- [ ] **P3** Total time spent on start platform (including returns).
- [ ] **P3** Latency.
- [ ] **P3** Path length.
- [ ] **P3** Angular distance of first checked hole from target.
- [ ] **P3** Number of target-hole checks.
- [ ] **P3** Number of non-target-hole checks.
- [ ] **P3** Mean angular distance of all checked holes from target.
- [ ] **P3** Time spent near the target hole.
- [ ] **P3** Averaged tracks across mice in a group.

## Universal act-derived features (apply to any experiment)

- [ ] **P2** Time-to-completion of a specific act: when did this act first finish?
- [ ] **P2** Time-to-first-completion of the first act in a sequence.
- [ ] **P2** Per-act statistics into the super-table (already partially there via `actStats` — audit which fields are missing).

## Macro decisions (need user discussion)

- [ ] **P4** Install latest MATLAB, port the codebase, leverage modern toolboxes.
- [ ] **P4** Rewrite in Python.
