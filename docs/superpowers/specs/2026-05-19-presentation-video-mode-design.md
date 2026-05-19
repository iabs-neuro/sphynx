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
on them (no duplicated draw blocks). Only these three change; the
Speed/Speed_act/Zone text panel and text backgrounds are untouched.

| Element | Default | Presentation |
|---|---|---|
| Trajectory | Color [0.10 0.50 0.90], LineWidth 1.2 | Color [0 0.30 0] (dark green), LineWidth 3.5 |
| Zones | filled boundary (fill, FaceAlpha 0.20, EdgeColor [1 0.5 0], LW 1.2) | border only: plot boundary, Color [1 0.5 0], LineWidth 2.5, no fill |
| Acts list | header/items FontSize 15-16, line step dy=26 (items dy-4) | FontSize 24, line step dy=44 |

Values are a first pass; tunable by eye after viewing the clip.

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
- No change to Speed/Speed_act/Zone panel, frame background, per-act videos.
- No new toolbox dependency.
