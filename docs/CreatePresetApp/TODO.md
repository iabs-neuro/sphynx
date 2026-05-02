# CreatePresetApp — backlog

Recorded 2026-04-29. The current GUI (`+sphynx/+app/CreatePresetApp.m`,
v10) is considered **good enough to use for production preset
building**. The items below are planned improvements for a future
polish pass — do not start them without explicit go-ahead.

## Cosmetic

### 1. Block widths / dropdown widths uniformity, INFO width consistency
**STATUS: PARTIALLY DONE (Slice AA / Round-3, 2026-05-02).** INFO buttons
unified at 60 px wide across all panels. Dropdowns / numeric fields
still slightly variable; address in a future polish pass if needed.

### 2. Log textarea auto-scroll-to-bottom
**STATUS: DONE (Slice A / Round-2, 2026-04-30).** Workaround used:
new lines are inserted at the TOP of the textarea Value, so the
latest message is always the first visible row. R2020a uitextarea
has no scroll API; this trick avoids the missing API entirely.
Applied to both PreprocessTabController and CreatePresetApp logs.

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
**STATUS: DONE (Slice H + Slice BB, 2026-04-30 / 2026-05-02).**
readArenaGeometry uses drawpolygon/drawcircle/drawellipse with
draggable handles. Slice BB added a `'shape' | 'points'` dropdown
per Arena and per Objects panel so the user can fall back to the
legacy ginput flow when preferred. The "Is it correct?" confirm
loop is preserved for objects.

### 5. More corner types and outside-arena extensions
**STATUS: DEFERRED (round-3 user request, 2026-05-02).** User asked
for a corner-type dropdown 'round | square' — square = perpendiculars
from the corner sides to the arena edge. Slice CC implemented strips
parallel to arena sides (TODO #7) but corner-types remained out of
scope because it requires reworking cornersWallsCenter() in
classifySquare end-to-end. Open.


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
**STATUS: DONE (Slice AA, 2026-05-02).** applyTransformToTarget now
takes an optional sharedPivot. When tIdx == -1, computeSharedPivot()
returns the arena centroid (or frame center fallback) and that single
pivot is passed to every child. Children rotate around the same
point and relative positions are preserved.

### 7. Strip partitioning when arena is at an angle
**STATUS: DONE (Slice CC, 2026-05-02).** partitionStrips accepts
an 'ArenaVertices' name-value. For 4-vertex polygons (square /
rectangle) the principal direction is the average of opposite
sides; otherwise PCA on the vertex cloud picks the dominant axis.
classifySquare and the GUI forward arena vertices through; for
Circle / Ellipse arenas vertices are unused so axis-aligned
strips remain.

### 9. Multi-file mode in Preprocess Tracking tab
- Load N (DLC csv + preset) pairs at once and treat them as one
  combined session for likelihood-threshold tuning.
- Concatenate per-part traces with NaN separators (visible as gaps
  on X(t)/Y(t) plots).
- Histograms merged across all sessions per body part.
- Video panel disabled in multi-mode (or one-session-at-a-time via
  a "current session" dropdown).
- Save in multi-mode writes only `_PreprocessSettings.mat`
  (the per-session traces are batched out separately later).
- Manual regions: not applicable in multi-mode.
- Useful for picking a single threshold that works across the
  whole experiment instead of fiddling per-session.
- Requested 2026-05-01 by Plusnin. Deferred from initial Slice 7-8
  scope.

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
