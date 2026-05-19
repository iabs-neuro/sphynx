# Design: "for presentation" mode for Analyze Session main video

Date: 2026-05-19
Status: Approved (user "ок делай", 2026-05-19)

## Goal

Render the Analyze Session behavior video for presentation use, with a
toggle that switches three visual elements to a cleaner/bolder style.

## Part A — code change

### A1. UI checkbox
- New property `MainVideoPresentationCheckbox` on
  `+sphynx/+app/AnalyzeSessionTabController.m`.
- Added to the "Main video" panel grid (grow `mvGrid` 4x4 -> 5x4,
  RowHeight 5x26), label "For presentation", `Value false`, row 5,
  columns [1 4]. Tooltip explains it restyles trajectory/zones/acts-list.

### A2. Plumbing
- `collectMainVideoFeatures()` adds `presentation` =
  `MainVideoPresentationCheckbox.Value`.
- `collectSettings` / `applySettings` persist `mainVideo.presentation`.
- `renderActsVideo` default feature struct `fdef` gains
  `presentation = false` (merged like the other flags).

### A3. renderActsVideo restyle (only when `feat.presentation == true`)
Local style vars chosen once before the frame loop; draw code branches
on them (no duplicated draw blocks). Text backgrounds (black boxes)
are untouched; everything else scales per the table below.

| Element | Default | Presentation (presScale=1.0) |
|---|---|---|
| Trajectory | Color [0.10 0.50 0.90], LW 1.2 | Color [0 0.30 0] (dark green), LW 3.5 |
| Zones | fill, FaceAlpha 0.20, EdgeColor [1 0.5 0], LW 1.2 | fill, FaceAlpha 0.10, LW 2.5 |
| Speed text | FontSize 18 | FontSize 38 |
| Speed_act / Zone / "Acts:" | FontSize 16 | FontSize 34 |
| Act item names | FontSize 15 | FontSize 48 |
| Panel line step (Speed/Speed_act/Zone) | dy 26 | 54 |
| Acts list step | 26 | 64 |

Iteration 2 (2026-05-19, user feedback): zones keep fill but at
FaceAlpha 0.10; ALL panel text enlarged (not just acts list); spacing
enlarged. Added optional numeric `feat.presScale` (default 1.0) that
uniformly scales every presentation font + step, so sample clips can
sweep sizes without code edits. Default (non-presentation) appearance
is byte-identical to before. Values still tunable by eye.

Iteration 3 (2026-05-19): font choice = font60 (presScale 1.25). Added
three more optional knobs (all default 1.0 / built-in, presentation
only): `presSpacingMul` (label spacing x), `presTrajMul` (trajectory
LW x), `presZoneAlpha` (explicit zone-fill FaceAlpha). Read via local
`optNum` helper. Sample sweep: spacing/traj x {1.5, 2.0} crossed with
zone alpha {0.075, 0.05, 0.03}.

## Part B — produce the MSS clip

Headless `matlab -batch`: load preset `MSS_H33_2D_1T_Preset.mat`, DLC
csv, `BehaviorData_PreprocessSettings.mat`, acts library
`MSS_acts_library.mat`; run `analyzeSession`; call `renderActsVideo` on
`MSS_H33_2D_1T.mp4` with Range = frame 1 .. +60 s, Features =
trajectory+velocity+actsList+zones+presentation. Output:
`<sessionDir>/MSS_H33_2D_1T_main.mp4`.

## Verification
- `matlab -batch` parse of the controller class (MethodList count).
- Smoke: `createPresetAppSmokeTest` + existing tab smoke tests stay green.
- Visual acceptance of the clip is on the user.

## Out of scope
- No change to text background boxes, video frame itself, per-act videos.
- No new toolbox dependency.
