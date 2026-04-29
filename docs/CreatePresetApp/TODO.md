# CreatePresetApp — backlog

Recorded 2026-04-29. The current GUI (`+sphynx/+app/CreatePresetApp.m`,
v10) is considered **good enough to use for production preset
building**. The items below are planned improvements for a future
polish pass — do not start them without explicit go-ahead.

## Cosmetic

### 1. Block widths / dropdown widths uniformity, INFO width consistency
- All `INFO` buttons should be visually identical width. Current: 50 px
  in some panels, 60 px in others. Pick one (probably 60).
- Dropdowns inside calibration / objects / arena have slightly
  different metrics; review and unify.
- Some panel widths "wobble" depending on content; tighten.

### 2. Log textarea auto-scroll-to-bottom
- Currently `scroll(textarea, 'bottom')` is wrapped in try/catch
  because R2020a does not expose the scroll API for `uitextarea`.
  The user always wants the latest line visible.
- Possible workarounds: programmatically clear and re-set Value
  (forces redraw at the end), or use a different widget (e.g.
  multi-line `uilabel` inside a scrollable uipanel — manual
  scroll). Investigate and pick the cleanest.

## Functional / performance

### 3. Filled zone overlay in preview without slowdown
- Today preview uses outline-only via `bwboundaries+plot` to stay
  responsive with many zones on large frames. User wants filled
  fill that's still fast.
- Approach: composite all zones into a single overlay RGBA image
  ahead of time, then a single `image()` call. Per-pixel alpha
  blending in MATLAB. Pre-compute on Add to set / Preview, cache
  until State changes.
- Or: use `imagesc` + transparency on a labeled mask (label
  matrix where each int = zone id, mapped to colors via colormap).
  One drawcall, fast.

### 4. Drag-and-drop interactive object drawing
- Replace ginput-based corner clicks with `drawpolygon`,
  `drawcircle`, `drawellipse`, `drawassisted` (Image Processing
  Toolbox ROI tools). Resulting ROI has draggable handles, the
  user can adjust before confirming.
- Also helpful for arena.
- Replaces "Is it correct? Yes/No" loop with a more natural
  "draw, adjust, double-click to confirm" pattern.
- See `drawpolygon` docs for the interaction model.

### 5. More corner types and outside-arena extensions
- Walls-and-corners currently splits the arena interior by
  proximity to corner POINTS (Manhattan-ish). Alternatives to
  expose:
  - Bisector-based corners: split the corner region by the
    bisector of adjacent walls (more geometrically natural).
  - Different ways to extend a zone outward — currently we just
    inflate by `wallW`. User wants more options:
    - Per-side extension widths (asymmetric).
    - Perpendicular projection from each wall segment.
    - Square cap vs round cap at corners.

### 6. Rigid-body rotation of "All" target — BUG
- When target=All and user clicks Rot CCW/CW, the current code
  rotates each mask around ITS OWN centroid. The right behavior
  is to rotate ALL masks around a common pivot (e.g., arena
  centroid) so relative positions are preserved.
- Fix in `applyTransformToTarget`: when tIdx == -1, compute a
  shared pivot (arena centroid), then translate each child to
  pivot-relative, rotate, translate back. NOT per-child.
- Same applies if we ever support multi-object selection.

### 7. Strip partitioning when arena is at an angle
- `partitionStrips` always uses axis-aligned (horizontal /
  vertical) slabs. If the user's arena is a rotated rectangle
  (e.g., a Polygon arena drawn at 30°), strips still cut along
  image-x / image-y, not along the arena's principal axis.
- Fix: detect arena orientation (e.g., via `regionprops` or PCA
  on the polygon vertices), compute strips in arena-aligned
  coordinates, then rotate the strip masks back to image
  coordinates.
- Or expose an Angle parameter in the Zones panel so the user
  can override the strip orientation manually.

### 8. Zone-name conventions unified with downstream scripts
- Current zone names are a mix of legacy (`ArenaCornersAllRealOut`,
  `Object1RealOut`) and new (`walls_and_corners`, `arena_realout`,
  `corners_realout`).
- `sphynx.pipeline.analyzeSession` references SOME legacy names
  in `legacyZoneActSpec` (analyzeSession.m bottom). Need to
  reconcile so zones produced by CreatePresetApp are consumable
  by analyzeSession without per-name remapping.
- Possible: introduce a single canonical map
  `+sphynx/+zones/zoneNames.m` listing every zone produced by
  the various strategies + how each is mapped to an act name in
  the pipeline.

## Priority order (suggested)

1. (#6) Rigid-body rotation — actual bug, easy to fix
2. (#8) Zone naming — reduces friction with the pipeline
3. (#2) Log auto-scroll — user-visible quality of life
4. (#3) Filled overlay performance — UX
5. (#1) Cosmetic widths — UX
6. (#7) Angled-arena strips — feature
7. (#5) More corner types / extensions — feature
8. (#4) Drag-and-drop ROI tools — bigger redesign of the picker
