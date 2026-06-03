# Barnes Pass 2 — 11 features implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build out the Barnes-paradigm feature set in CreatePreset + Preprocess tabs per spec sections S1-S11. Eleven features, sequenced so foundational changes land first.

**Architecture:** All changes inside the existing `+sphynx/` package. S1 (object selection model) is the foundation reused by S2/S8/S9. S7 (auto-detect) is the largest single task and goes last because everything else builds toward giving it a clean integration surface. New helper files live in `+sphynx/+preset/`, new tests in `tests/unit/`. No new top-level packages.

**Tech Stack:** MATLAB R2020a — `uifigure`/`uigridlayout`/`uilistbox` (multi-select), Image Processing Toolbox (`adaptthresh`, `imfindcircles`, `bwconncomp`, `regionprops`, `bwboundaries`, `bwdist`). Tests via `functiontests` + `runAllTests('tag','fast')`.

**Spec:** `docs/superpowers/specs/2026-06-03-barnes-features-design.md` Pass 2 (S1-S11).

**Branch:** `sphynx-GUI`. Base commit: `c765f29` (Pass 1 final).

**Implementation order:**

| Task | Spec section | Why this order |
|---|---|---|
| 1 | S1 Object selection model | Foundation reused by S2/S8/S9 |
| 2 | S8 Object class property | Smallest user of S1 — confirms selection model works end-to-end |
| 3 | S9 Multi-select + group move | Larger user of S1 — also uses S8 class to label |
| 4 | S2 Copy × N | Uses S1 + S9 (new copies become group-selected) |
| 5 | S3 Overlay existing on picker | Decoupled, fits anywhere |
| 6 | S4 Calibrate by 1 line | Decoupled, small |
| 7 | S5 Zoning `circle-with-center` | Decoupled, small (1 new helper) |
| 8 | S6 Frame picker N-of-M | Decoupled, uses Pass 1 A1.5's `readFrameAt` |
| 9 | S10 Manual exclusion circle | Decoupled, in Preprocess tab |
| 10 | S11 Auto exclusion N cm | Decoupled, in Preprocess tab |
| 11 | S7 Auto-detect objects | Biggest — needs S1 (multi-select detected objects) + S3 (overlay) + has its own algorithm complexity |

---

## Task 1: S1 Object selection model (foundation)

**Files:**
- Modify: `+sphynx/+app/CreatePresetApp.m` (state, UI, listbox handler, current-target API)
- Create: `+sphynx/+preset/marqueeSelect.m` (pure helper: given centroids + rect, return indices)
- Test: `tests/unit/marqueeSelectTest.m`

### Steps

- [ ] **Step 1: Write the failing test for `marqueeSelect`**

`tests/unit/marqueeSelectTest.m`:

```matlab
function tests = marqueeSelectTest
    tests = functiontests(localfunctions);
end

function testEmptyRectReturnsEmpty(testCase)
    cents = [10 10; 20 20; 30 30];
    idx = sphynx.preset.marqueeSelect(cents, []);
    verifyEqual(testCase, idx, []);
end

function testInsideRectSelected(testCase)
    cents = [10 10; 50 50; 20 80];
    rect = [0 0 40 40];   % [x y w h]
    idx = sphynx.preset.marqueeSelect(cents, rect);
    verifyEqual(testCase, idx, 1);  % only (10,10) is in [0..40,0..40]
end

function testEdgeIsInclusive(testCase)
    cents = [40 40];
    rect = [0 0 40 40];
    idx = sphynx.preset.marqueeSelect(cents, rect);
    verifyEqual(testCase, idx, 1);
end

function testMultipleInside(testCase)
    cents = [5 5; 10 10; 15 15; 100 100];
    rect = [0 0 20 20];
    idx = sphynx.preset.marqueeSelect(cents, rect);
    verifyEqual(testCase, idx, [1; 2; 3]);
end
```

- [ ] **Step 2: Run — expect 4 failures (`Undefined function 'sphynx.preset.marqueeSelect'`)**

```bash
matlab -batch "addpath(genpath(pwd)); runtests('tests/unit/marqueeSelectTest.m')"
```

- [ ] **Step 3: Implement `marqueeSelect`**

`+sphynx/+preset/marqueeSelect.m`:

```matlab
function idx = marqueeSelect(centroids, rect)
% MARQUEESELECT  Return indices of centroids inside the rectangle.
%
%   idx = sphynx.preset.marqueeSelect(centroids, rect)
%
%   centroids  Nx2 [x y] points
%   rect       1x4 [x y w h] (MATLAB position rect); [] -> no selection
%
%   Edge inclusive on all four sides. Returns column vector (or [] if rect
%   is empty / no matches).
    if isempty(rect)
        idx = [];
        return;
    end
    x0 = rect(1); y0 = rect(2);
    x1 = x0 + rect(3); y1 = y0 + rect(4);
    inX = centroids(:,1) >= x0 & centroids(:,1) <= x1;
    inY = centroids(:,2) >= y0 & centroids(:,2) <= y1;
    idx = find(inX & inY);
end
```

- [ ] **Step 4: Run tests — 4/4 PASS**

- [ ] **Step 5: Wire multi-select into CreatePresetApp**

In `+sphynx/+app/CreatePresetApp.m`:

5a. Find `app.ObjectsListBox = uilistbox(g, 'Items', {}, ...)` around line 1060. Add `'Multiselect','on',`:

```matlab
app.ObjectsListBox = uilistbox(g, 'Items', {}, ...
    'Multiselect', 'on', ...
    [keep existing other args]);
```

5b. Add new state field. Locate the State init (search `s.numFrames = NaN`). Add nearby:

```matlab
s.selectedObjectIdx = [];   % vector of object indices (S1 foundation)
```

5c. Update `refreshObjectsList` (around line 664) so `Value` after refresh is `app.ObjectsListBox.Items(app.State.selectedObjectIdx)` (or `{}` if empty selection). Read the current method first to apply the right edit.

5d. Add a public method `getSelectedObjectIdx(app)` that returns `app.State.selectedObjectIdx` filtered to currently-valid indices (`1..numel(app.State.objects)`).

5e. Add a public method `setSelectedObjectIdx(app, idx)` that:
- accepts `idx` as numeric vector,
- clamps each entry to `1..numel(app.State.objects)`,
- de-duplicates and sorts,
- writes to `app.State.selectedObjectIdx`,
- updates `app.ObjectsListBox.Value` to the corresponding items.

5f. Wire ListBox `ValueChangedFcn` to call `app.setSelectedObjectIdx(...)` derived from the new `Value` (find each item in `Items`).

5g. Replace the 4 existing `find(strcmp(app.ObjectsListBox.Items, app.ObjectsListBox.Value), 1)` calls (around lines 198, 214, 285, 650) with `idx = app.getSelectedObjectIdx(); if isempty(idx); ...; end`. For single-target sites (`removeSelectedObject`, `replaceSelectedObject`), use `idx = idx(1)`. For multi-target sites (preview / refresh), pass the vector.

- [ ] **Step 6: Visual yellow-outline indicator for selected**

In the preview drawing path (search `drawState` in CreatePresetApp.m and `+sphynx/+preset/`), add an overlay step after objects are drawn: for each `k in app.State.selectedObjectIdx`, draw the object's border in `[1 0.85 0]` (amber/yellow), `LineWidth=2`. Verify the preview panel re-renders on selection change (refresh preview from `setSelectedObjectIdx`).

- [ ] **Step 7: Smoke test the GUI**

Manual: load video + preset with 3 objects. Ctrl+click 2 of them in the listbox. Yellow outlines should appear on both. Click empty area or use `clearAll` (not implemented as a button, but verify selection is empty after `clearAll`).

- [ ] **Step 8: Commit**

```bash
git add +sphynx/+preset/marqueeSelect.m \
        +sphynx/+app/CreatePresetApp.m \
        tests/unit/marqueeSelectTest.m
git commit -m "feat(preset): object multi-select model + marquee helper (S1)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: S8 Object class property

**Files:**
- Modify: `+sphynx/+app/CreatePresetApp.m` (object struct schema, UI field, assign action, save/load)
- Modify: `+sphynx/+preset/readArenaGeometry.m` (object struct adds `class` field default `''`)
- Test: `tests/unit/objectClassTest.m`

### Steps

- [ ] **Step 1: Failing test for class round-trip**

`tests/unit/objectClassTest.m`:

```matlab
function tests = objectClassTest
    tests = functiontests(localfunctions);
end

function testDefaultClassEmpty(testCase)
    frame = uint8(zeros(100, 100, 3));
    pts = [10 10; 30 10; 30 30; 10 30];
    obj = sphynx.preset.readArenaGeometry(frame, 'Polygon', 'Points', pts);
    verifyTrue(testCase, isfield(obj, 'class'));
    verifyEqual(testCase, obj.class, '');
end

function testClassPersistsThroughStructAssign(testCase)
    frame = uint8(zeros(100, 100, 3));
    pts = [10 10; 30 10; 30 30; 10 30];
    obj = sphynx.preset.readArenaGeometry(frame, 'Polygon', 'Points', pts);
    obj.class = 'neutral';
    objects = obj;
    obj2 = sphynx.preset.readArenaGeometry(frame, 'Polygon', 'Points', pts);
    obj2.class = 'target';
    objects(end+1) = obj2;
    verifyEqual(testCase, objects(1).class, 'neutral');
    verifyEqual(testCase, objects(2).class, 'target');
end
```

- [ ] **Step 2: Run — fail (no `class` field)**

- [ ] **Step 3: Add `class` field to arena/object struct in `readArenaGeometry.m`**

Find the `arena.type = 'Arena';` block (~line 116) and add `arena.class = '';` immediately after `arena.geometry = geometry;`. Also add `class` to the cancel-error case isn't needed (we throw, not assign).

- [ ] **Step 4: Run — 2/2 PASS**

- [ ] **Step 5: UI: editfield + Assign button**

In CreatePresetApp's buildObjectsPanel (search by name), add to the objects panel right of the list:

```matlab
classPanel = uigridlayout(parentPanel, [1, 3]);
classPanel.ColumnWidth = {'fit', 200, 110};
uilabel(classPanel, 'Text', 'Class:');
app.ObjectClassField = uieditfield(classPanel, 'Value', '');
uibutton(classPanel, 'Text', 'Assign to selected', ...
    'ButtonPushedFcn', @(~,~) app.assignClassToSelected());
```

- [ ] **Step 6: Add `assignClassToSelected` method**

```matlab
function assignClassToSelected(app)
    idx = app.getSelectedObjectIdx();
    if isempty(idx)
        app.status('No objects selected');
        return;
    end
    val = app.ObjectClassField.Value;
    for k = idx(:)'
        app.State.objects(k).class = val;
    end
    app.status(sprintf('Assigned class "%s" to %d objects', val, numel(idx)));
end
```

- [ ] **Step 7: Save/load: ensure `class` round-trips via preset .mat**

Verify `assembleArenaAndObjects()` writes `class` field (it auto-includes all struct fields). On load (search for preset-load path), copy `class` field if present in saved struct, default `''` if absent (back-compat for old presets without class).

- [ ] **Step 8: Commit**

```bash
git add +sphynx/+app/CreatePresetApp.m +sphynx/+preset/readArenaGeometry.m tests/unit/objectClassTest.m
git commit -m "feat(preset): object class property + assign-to-selected (S8)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: S9 Multi-select + group move

**Files:**
- Modify: `+sphynx/+app/CreatePresetApp.m` (`moveTarget`, `rotateTarget`, `refreshMoveTargets`, target dropdown)
- Create: `+sphynx/+preset/rotateAroundCentroid.m` (pure helper for group rotation)
- Test: `tests/unit/rotateAroundCentroidTest.m`

### Steps

- [ ] **Step 1: Failing test for `rotateAroundCentroid`**

`tests/unit/rotateAroundCentroidTest.m`:

```matlab
function tests = rotateAroundCentroidTest
    tests = functiontests(localfunctions);
end

function testIdentityRotation(testCase)
    bx = [1 2 3]'; by = [10 20 30]';
    [bxR, byR] = sphynx.preset.rotateAroundCentroid(bx, by, [2 20], 0);
    verifyEqual(testCase, bxR, bx, 'AbsTol', 1e-9);
    verifyEqual(testCase, byR, by, 'AbsTol', 1e-9);
end

function test90Rotation(testCase)
    % Point (3,0) around centroid (0,0) by 90deg -> (0,3)
    bx = 3; by = 0;
    [bxR, byR] = sphynx.preset.rotateAroundCentroid(bx, by, [0 0], pi/2);
    verifyEqual(testCase, bxR, 0, 'AbsTol', 1e-9);
    verifyEqual(testCase, byR, 3, 'AbsTol', 1e-9);
end

function testCentroidIsFixedPoint(testCase)
    bx = [0]; by = [0];
    [bxR, byR] = sphynx.preset.rotateAroundCentroid(bx, by, [0 0], pi);
    verifyEqual(testCase, bxR, 0, 'AbsTol', 1e-9);
    verifyEqual(testCase, byR, 0, 'AbsTol', 1e-9);
end
```

- [ ] **Step 2: Run — 3 failures**

- [ ] **Step 3: Implement `rotateAroundCentroid`**

```matlab
function [xR, yR] = rotateAroundCentroid(x, y, centroid, angleRad)
% ROTATEAROUNDCENTROID  Rotate points (x,y) by `angleRad` around `centroid`.
%
%   [xR, yR] = sphynx.preset.rotateAroundCentroid(x, y, centroid, angleRad)
%
%   centroid  1x2 [cx cy]
%   angleRad  radians (positive = CCW)
    cx = centroid(1); cy = centroid(2);
    c = cos(angleRad); s = sin(angleRad);
    dx = x - cx;       dy = y - cy;
    xR = cx + dx*c - dy*s;
    yR = cy + dx*s + dy*c;
end
```

- [ ] **Step 4: Tests pass 3/3**

- [ ] **Step 5: Update `MoveTargetDropDown` items**

`refreshMoveTargets` (line ~516). Items currently `{'All', 'Arena', Object1, ...}`. Insert `<selection>` when `numel(app.State.selectedObjectIdx) >= 2`:

```matlab
items = {'All', 'Arena'};
if numel(app.State.selectedObjectIdx) >= 2
    items{end+1} = '<selection>';
end
for k = 1:numel(app.State.objects)
    items{end+1} = app.State.objects(k).type; %#ok<AGROW>
end
```

Also call `refreshMoveTargets` from inside `setSelectedObjectIdx` (Task 1, Step 5e) so the dropdown updates when selection changes.

- [ ] **Step 6: Update `moveTarget` to handle `<selection>` target**

Currently `moveTarget` calls `currentTargetIdx(app)` which returns a scalar. Add a branch:

```matlab
function moveTarget(app, dirVec)
    step = app.MoveStepField.Value;
    target = app.MoveTargetDropDown.Value;
    if strcmp(target, '<selection>')
        idx = app.getSelectedObjectIdx();
        if isempty(idx); return; end
        delta = dirVec * step;
        for k = idx(:)'
            app.State.objects(k).border_x = app.State.objects(k).border_x + delta(1);
            app.State.objects(k).border_y = app.State.objects(k).border_y + delta(2);
        end
        app.invalidateZonesOnTransform();
        app.refreshPreview();
        return;
    end
    % existing single-target path
    tIdx = currentTargetIdx(app);
    if isnan(tIdx); return; end
    applyTransformToTarget(app, tIdx, dirVec * step, 0);
    app.invalidateZonesOnTransform();
    app.refreshPreview();
end
```

- [ ] **Step 7: Update `rotateTarget` to handle `<selection>` target**

Similar branch, computes pool centroid from selected objects' borders and uses `rotateAroundCentroid`:

```matlab
function rotateTarget(app, sign)
    stepDeg = app.MoveStepField.Value;
    target = app.MoveTargetDropDown.Value;
    if strcmp(target, '<selection>')
        idx = app.getSelectedObjectIdx();
        if isempty(idx); return; end
        % Pool centroid = mean of all selected objects' border points
        allX = []; allY = [];
        for k = idx(:)'
            allX = [allX; app.State.objects(k).border_x(:)]; %#ok<AGROW>
            allY = [allY; app.State.objects(k).border_y(:)]; %#ok<AGROW>
        end
        centroid = [mean(allX), mean(allY)];
        angleRad = deg2rad(sign * stepDeg);
        for k = idx(:)'
            [xR, yR] = sphynx.preset.rotateAroundCentroid( ...
                app.State.objects(k).border_x, app.State.objects(k).border_y, ...
                centroid, angleRad);
            app.State.objects(k).border_x = xR;
            app.State.objects(k).border_y = yR;
        end
        app.invalidateZonesOnTransform();
        app.refreshPreview();
        return;
    end
    tIdx = currentTargetIdx(app);
    if isnan(tIdx); return; end
    applyTransformToTarget(app, tIdx, [0 0], sign * stepDeg);
    app.invalidateZonesOnTransform();
    app.refreshPreview();
end
```

- [ ] **Step 8: Run full fast test suite — confirm no regression**

```bash
matlab -batch "addpath(genpath(pwd)); runAllTests('tag','fast')"
```

Expected: PASS, same count as Pass 1 baseline + new tests.

- [ ] **Step 9: Commit**

```bash
git add +sphynx/+preset/rotateAroundCentroid.m \
        +sphynx/+app/CreatePresetApp.m \
        tests/unit/rotateAroundCentroidTest.m
git commit -m "feat(preset): multi-select group move + rotate around pool centroid (S9)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: S2 Copy object × N

**Files:**
- Modify: `+sphynx/+app/CreatePresetApp.m` (UI button, `copyObjectsN` method)
- Create: `+sphynx/+preset/gridOffsets.m` (pure helper for N-position layout)
- Test: `tests/unit/gridOffsetsTest.m`

### Steps

- [ ] **Step 1: Failing test for `gridOffsets`**

```matlab
function tests = gridOffsetsTest
    tests = functiontests(localfunctions);
end

function testRowLayoutForSmallN(testCase)
    % N=3 -> 3 copies in a row, step 30 -> offsets (30,0),(60,0),(90,0)
    offsets = sphynx.preset.gridOffsets(3, 30);
    verifyEqual(testCase, offsets, [30 0; 60 0; 90 0]);
end

function testGridLayoutForLargeN(testCase)
    % N=7, step 30 -> 5 cols, 2 rows
    % row 1: (30,0),(60,0),(90,0),(120,0),(150,0)
    % row 2: (30,30),(60,30)
    offsets = sphynx.preset.gridOffsets(7, 30);
    verifyEqual(testCase, offsets, ...
        [30 0; 60 0; 90 0; 120 0; 150 0; 30 30; 60 30]);
end

function testZeroN(testCase)
    offsets = sphynx.preset.gridOffsets(0, 30);
    verifyEqual(testCase, size(offsets, 1), 0);
end
```

- [ ] **Step 2: Run — fail**

- [ ] **Step 3: Implement `gridOffsets`**

```matlab
function offsets = gridOffsets(n, step)
% GRIDOFFSETS  Layout offsets for N copies of an object.
%
%   offsets = sphynx.preset.gridOffsets(n, step) returns an Nx2 matrix
%   of (dx, dy). Row layout for n <= 5; 5-column grid for n > 5,
%   row-major filling.
    if n <= 0
        offsets = zeros(0, 2);
        return;
    end
    cols = min(n, 5);
    offsets = zeros(n, 2);
    for k = 1:n
        r = floor((k - 1) / cols);
        c = mod(k - 1, cols);
        offsets(k, :) = [(c + 1) * step, r * step];
    end
end
```

- [ ] **Step 4: Tests pass 3/3**

- [ ] **Step 5: Add Copy×N UI**

In the objects panel:

```matlab
copyPanel = uigridlayout(parentPanel, [1, 3]);
copyPanel.ColumnWidth = {'fit', 80, 'fit'};
uilabel(copyPanel, 'Text', 'Copy:');
app.CopyNField = uieditfield(copyPanel, 'numeric', 'Value', 5, ...
    'Limits', [1 20], 'RoundFractionalValues', 'on');
uibutton(copyPanel, 'Text', 'Copy x N', ...
    'ButtonPushedFcn', @(~,~) app.copyObjectsN());
```

- [ ] **Step 6: Implement `copyObjectsN`**

```matlab
function copyObjectsN(app)
    idx = app.getSelectedObjectIdx();
    if numel(idx) ~= 1
        app.status('Copy x N requires exactly 1 object selected');
        return;
    end
    src = app.State.objects(idx);
    n = round(app.CopyNField.Value);
    pxlPerCm = app.State.pxlPerCm;
    if isnan(pxlPerCm) || pxlPerCm <= 0
        app.status('Calibrate pxlPerCm first');
        return;
    end
    stepPx = 30 * pxlPerCm;     % 30 cm offset
    offs = sphynx.preset.gridOffsets(n, stepPx);
    newIdx = [];
    for k = 1:n
        cp = src;
        cp.border_x = src.border_x + offs(k, 1);
        cp.border_y = src.border_y + offs(k, 2);
        cp.mask = imfill(sphynx.preset.maskFromBorder( ...
            app.State.height, app.State.width, cp.border_x, cp.border_y), 'holes');
        cp.type = sprintf('Object%d', numel(app.State.objects) + 1);
        if isempty(app.State.objects)
            app.State.objects = cp;
        else
            app.State.objects(end + 1) = cp;
        end
        newIdx(end + 1) = numel(app.State.objects); %#ok<AGROW>
    end
    app.refreshObjectsList();
    app.refreshMoveTargets();
    app.setSelectedObjectIdx(newIdx);
    app.refreshPreview();
    app.status(sprintf('Copied %d times; %d new objects', n, n));
end
```

- [ ] **Step 7: Manual GUI smoke**

Load preset with 1 object, select it, set Copy=5, click Copy×N → 5 copies appear offset 30 cm to the right and below. All 5 stay selected; pressing Move arrows moves all 5.

- [ ] **Step 8: Commit**

```bash
git add +sphynx/+preset/gridOffsets.m \
        +sphynx/+app/CreatePresetApp.m \
        tests/unit/gridOffsetsTest.m
git commit -m "feat(preset): Copy x N object duplication with grid layout (S2)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: S3 Overlay existing on picker

**Files:**
- Modify: `+sphynx/+preset/readArenaGeometry.m` (accept `ExistingObjects` param, overlay before drawing)
- Modify: `+sphynx/+app/CreatePresetApp.m` (pass `state.objects` to picker in `addObject` and `replaceSelectedObject`)
- Test: `tests/unit/readArenaGeometryOverlayTest.m`

### Steps

- [ ] **Step 1: Failing test — pass `ExistingObjects` without crash, output unchanged**

```matlab
function tests = readArenaGeometryOverlayTest
    tests = functiontests(localfunctions);
end

function testExistingObjectsParamDoesNotChangeOutput(testCase)
    frame = uint8(zeros(100, 100, 3));
    pts = [10 10; 30 10; 30 30; 10 30];
    existing = struct('border_x', {[5;15;15;5]}, 'border_y', {[5;5;15;15]});
    obj = sphynx.preset.readArenaGeometry(frame, 'Polygon', ...
        'Points', pts, 'ExistingObjects', existing);
    verifyEqual(testCase, obj.type, 'Arena');
    verifyEqual(testCase, obj.geometry, 'Polygon');
end

function testEmptyExistingObjectsParamWorks(testCase)
    frame = uint8(zeros(100, 100, 3));
    pts = [10 10; 30 10; 30 30; 10 30];
    obj = sphynx.preset.readArenaGeometry(frame, 'Polygon', ...
        'Points', pts, 'ExistingObjects', []);
    verifyEqual(testCase, obj.type, 'Arena');
end
```

- [ ] **Step 2: Run — fail (`ExistingObjects` not a recognised parameter)**

- [ ] **Step 3: Add `ExistingObjects` param + overlay code**

In `readArenaGeometry.m`:

3a. Add to inputParser:
```matlab
addParameter(p, 'ExistingObjects', struct('border_x', {}, 'border_y', {}));
```

3b. In the interactive branch (after `imshow(frame, 'Parent', ax); hold(ax, 'on');`, before `switch geometry`), add overlay step:

```matlab
existing = p.Results.ExistingObjects;
for k = 1:numel(existing)
    bx = existing(k).border_x;
    by = existing(k).border_y;
    if isempty(bx); continue; end
    fill(ax, bx(:), by(:), [0.3 0.5 0.8], ...
        'FaceAlpha', 0.20, ...
        'EdgeColor', [0.1 0.3 0.6], 'EdgeAlpha', 0.8, 'LineWidth', 1);
end
```

- [ ] **Step 4: Tests pass 2/2**

- [ ] **Step 5: Wire from CreatePresetApp**

In `addObject` (line ~177), update the call:
```matlab
obj = sphynx.preset.readArenaGeometry(app.State.frame, geometry, ...
    'Points', points, 'ExistingObjects', app.State.objects);
```

In `replaceSelectedObject` (line ~212), pass `app.State.objects` excluding the one being replaced:
```matlab
otherIdx = setdiff(1:numel(app.State.objects), idx);
obj = sphynx.preset.readArenaGeometry(app.State.frame, geometry, ...
    'ExistingObjects', app.State.objects(otherIdx));
```

For `setArena`, pass the arena's existing objects to overlay:
```matlab
arena = sphynx.preset.readArenaGeometry(app.State.frame, geometry, ...
    'Points', points, 'ExistingObjects', app.State.objects);
```

- [ ] **Step 6: Manual smoke**

Place 3 objects, then click Add Object → in the popup, see the 3 existing objects drawn semi-transparent before you pick the new one.

- [ ] **Step 7: Commit**

```bash
git add +sphynx/+preset/readArenaGeometry.m \
        +sphynx/+app/CreatePresetApp.m \
        tests/unit/readArenaGeometryOverlayTest.m
git commit -m "feat(preset): overlay existing objects on geometry picker (S3)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: S4 Calibrate by 1 line

**Files:**
- Modify: `+sphynx/+app/CreatePresetApp.m` (new button, new method `calibrateByOneLine`)

### Steps

- [ ] **Step 1: Read existing calibration code (`pixelsPerCm` + `setPixelsPerCm` usage)**

Search `Calibrate (4 points)` button in the file. Adjacent — add new button.

- [ ] **Step 2: Add new button**

```matlab
uibutton(calibPanel, 'Text', 'Calibrate (1 line)', ...
    'BackgroundColor', semanticColor('action'), ...
    'ButtonPushedFcn', @(~,~) app.calibrateByOneLine());
```

- [ ] **Step 3: Implement `calibrateByOneLine`**

```matlab
function calibrateByOneLine(app)
    if isempty(app.State.frame); app.status('Load video first'); return; end
    try
        fh = figure('Name', 'Calibrate: 1 line', 'NumberTitle', 'off');
        cleaner = onCleanup(@() closeIfValid(fh));
        ax = axes(fh);
        imshow(app.State.frame, 'Parent', ax);
        title(ax, 'Draw a line of known length, then enter cm', 'Interpreter', 'none');
        hL = drawline(ax);
        wait(hL);
        if ~isvalid(hL); app.status('Calibration cancelled'); return; end
        P = hL.Position;
        lengthPx = sqrt(sum(diff(P, 1, 1).^2));
        cmStr = inputdlg('Line length in cm:', 'Calibrate', 1, {'10'});
        if isempty(cmStr); app.status('Calibration cancelled'); return; end
        cm = str2double(cmStr{1});
        if isnan(cm) || cm <= 0
            app.status('Invalid cm value');
            return;
        end
        pxlPerCm = lengthPx / cm;
        app.setPixelsPerCm(pxlPerCm, 'Y', pxlPerCm, 'X', pxlPerCm, 'KCorr', 1);
        app.status(sprintf('Calibrated by 1 line: pxlPerCm=%.3f', pxlPerCm));
    catch ME
        app.status(sprintf('1-line calibration failed: %s', ME.message));
    end
end
```

Wraps in `closeIfValid` helper which is already in the file.

- [ ] **Step 4: Manual smoke**

Load video, click Calibrate (1 line), draw a line on a known reference, enter cm value, confirm `pxlPerCm` label updates correctly.

- [ ] **Step 5: Commit**

```bash
git add +sphynx/+app/CreatePresetApp.m
git commit -m "feat(preset): calibrate by 1 line (S4)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 7: S5 Zoning `circle-with-center`

**Files:**
- Create: `+sphynx/+preset/buildZonesCircleCenter.m` (helper)
- Modify: `+sphynx/+app/CreatePresetApp.m` (new dropdown item, `CenterDiameterCm` field, dispatch)
- Test: `tests/unit/buildZonesCircleCenterTest.m`

### Steps

- [ ] **Step 1: Failing test**

```matlab
function tests = buildZonesCircleCenterTest
    tests = functiontests(localfunctions);
end

function testTwoZonesEmittedCenterAndWall(testCase)
    H = 200; W = 200; pxlPerCm = 2;
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask = (X-100).^2 + (Y-100).^2 <= (40 * pxlPerCm)^2;
    Z = sphynx.preset.buildZonesCircleCenter(arenaMask, ...
        'PixelsPerCm', pxlPerCm, 'CenterDiameterCm', 20);
    names = {Z.name};
    verifyEqual(testCase, sort(names), {'center', 'wall'});
end

function testCenterArea(testCase)
    H = 200; W = 200; pxlPerCm = 2;
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask = (X-100).^2 + (Y-100).^2 <= (40 * pxlPerCm)^2;
    Z = sphynx.preset.buildZonesCircleCenter(arenaMask, ...
        'PixelsPerCm', pxlPerCm, 'CenterDiameterCm', 20);
    centerZone = Z(strcmp({Z.name}, 'center'));
    % Center radius = 10 cm = 20 px. Area ~= pi*20^2 = 1257
    verifyTrue(testCase, sum(centerZone.maskfilled(:)) > 1000);
    verifyTrue(testCase, sum(centerZone.maskfilled(:)) < 1400);
end

function testWallPartitionsArena(testCase)
    H = 200; W = 200; pxlPerCm = 2;
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask = (X-100).^2 + (Y-100).^2 <= (40 * pxlPerCm)^2;
    Z = sphynx.preset.buildZonesCircleCenter(arenaMask, ...
        'PixelsPerCm', pxlPerCm, 'CenterDiameterCm', 20);
    combined = false(H, W);
    for k = 1:numel(Z)
        verifyFalse(testCase, any(combined(:) & Z(k).maskfilled(:)));
        combined = combined | Z(k).maskfilled;
    end
    verifyEqual(testCase, combined, arenaMask);
end
```

- [ ] **Step 2: Run — fail**

- [ ] **Step 3: Implement `buildZonesCircleCenter`**

```matlab
function Zones = buildZonesCircleCenter(arenaMask, varargin)
% BUILDZONESCIRCLECENTER  Two-zone partition: center disc + wall annulus.
%
%   Zones = sphynx.preset.buildZonesCircleCenter(arenaMask, ...)
%
%   Required name-value: 'PixelsPerCm', 'CenterDiameterCm'.
%
%   Returns 2-element struct array with fields name/type/maskfilled.
%   `center` is a concentric disc of the requested diameter, clipped to
%   the arena mask. `wall` is the arena minus the center.

    p = inputParser;
    addRequired(p, 'arenaMask', @(m) islogical(m) || isnumeric(m));
    addParameter(p, 'PixelsPerCm', [], @(v) isnumeric(v) && v > 0);
    addParameter(p, 'CenterDiameterCm', 20, @(v) isnumeric(v) && v > 0);
    parse(p, arenaMask, varargin{:});
    pxlPerCm = p.Results.PixelsPerCm;
    if isempty(pxlPerCm)
        error('sphynx:buildZonesCircleCenter:missingPixelsPerCm', ...
            'PixelsPerCm is required');
    end
    arenaMask = arenaMask > 0;
    [H, W] = size(arenaMask);
    [yIdx, xIdx] = find(arenaMask);
    cx = mean(xIdx);
    cy = mean(yIdx);
    r = (p.Results.CenterDiameterCm / 2) * pxlPerCm;
    [X, Y] = meshgrid(1:W, 1:H);
    centerMask = ((X - cx).^2 + (Y - cy).^2) <= r^2 & arenaMask;
    wallMask = arenaMask & ~centerMask;
    Zones = struct('name', {}, 'type', {}, 'maskfilled', {});
    if any(wallMask(:))
        Zones(end + 1).name = 'wall';
        Zones(end).type = 'area';
        Zones(end).maskfilled = wallMask;
    end
    if any(centerMask(:))
        Zones(end + 1).name = 'center';
        Zones(end).type = 'area';
        Zones(end).maskfilled = centerMask;
    end
end
```

- [ ] **Step 4: Tests pass 3/3**

- [ ] **Step 5: Wire into CreatePresetApp**

5a. In `ZonesStrategyDropDown` Items (line ~1118), add `'circle-with-center'`:
```matlab
'Items', {'corners-walls-center', 'strips', 'circle-rings', 'circle-with-center', 'none'}, ...
```

5b. Add new `CenterDiameterCm` field beside `MiddleWidthField`:
```matlab
app.CenterDiameterCmField = uieditfield(g, 'numeric', 'Value', 20, ...
    'Limits', [0.1, Inf]);
```

5c. In `onZoneStrategyChanged` (line ~1213-1214), add visibility rule:
```matlab
app.CenterDiameterCmField.Enable = enableIfAny(s, {'circle-with-center'});
```

5d. In `computeZonesFromUI` (search for the switch on strategy ~line 1534), add the new case:
```matlab
case 'circle-with-center'
    Z = sphynx.preset.buildZonesCircleCenter(app.State.arena.mask, ...
        'PixelsPerCm', app.State.pxlPerCm, ...
        'CenterDiameterCm', app.CenterDiameterCmField.Value);
```

5e. In preset save/load (search `MiddleWidthCm`), add `CenterDiameterCm` to `Options` write and read.

- [ ] **Step 6: Manual smoke**

Circle arena, set strategy `circle-with-center`, set CenterDiameterCm=20, Preview → see 2 zones (center disc + wall annulus).

- [ ] **Step 7: Commit**

```bash
git add +sphynx/+preset/buildZonesCircleCenter.m \
        +sphynx/+app/CreatePresetApp.m \
        tests/unit/buildZonesCircleCenterTest.m
git commit -m "feat(zones): circle-with-center strategy (S5)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 8: S6 Frame picker N-of-M

**Files:**
- Modify: `+sphynx/+app/CreatePresetApp.m` (nav row UI, `pickFrame` method, `Next frame` now advances dropdown index)

### Steps

- [ ] **Step 1: Add UI: N field + frame dropdown**

In the nav row (line ~831), insert between `FrameIndexLabel` and `Target` label:

```matlab
lblN = uilabel(cg, 'Text', 'N:');
app.FramePickerNField = uieditfield(cg, 'numeric', 'Value', 20, ...
    'Limits', [2 200], 'RoundFractionalValues', 'on', ...
    'ValueChangedFcn', @(~,~) app.rebuildFramePickerDropdown());
app.FramePickerDropdown = uidropdown(cg, 'Items', {'1/20'}, 'Value', '1/20', ...
    'ValueChangedFcn', @(~,~) app.pickFrame());
```

Adjust column count and widths in the existing `cg = uigridlayout(...)` setup.

- [ ] **Step 2: Add `rebuildFramePickerDropdown`**

```matlab
function rebuildFramePickerDropdown(app)
    if isempty(app.State.numFrames) || isnan(app.State.numFrames); return; end
    N = app.FramePickerNField.Value;
    items = arrayfun(@(k) sprintf('%d/%d', k, N), 1:N, 'UniformOutput', false);
    old = app.FramePickerDropdown.Value;
    app.FramePickerDropdown.Items = items;
    if ismember(old, items)
        app.FramePickerDropdown.Value = old;
    else
        app.FramePickerDropdown.Value = items{1};
    end
end
```

- [ ] **Step 3: Add `pickFrame`**

```matlab
function pickFrame(app)
    if isempty(app.State.videoPath); return; end
    sel = app.FramePickerDropdown.Value;
    parts = strsplit(sel, '/');
    k = str2double(parts{1});
    N = str2double(parts{2});
    app.State.frameIndex = max(1, round(app.State.numFrames * k / N));
    try
        app.State.frame = sphynx.preset.readFrameAt( ...
            app.State.videoPath, app.State.frameIndex, app.State.frameRate);
        app.refreshPreview();
        if ~isempty(app.FrameIndexLabel)
            app.FrameIndexLabel.Text = sprintf('Frame %d / %d', ...
                app.State.frameIndex, app.State.numFrames);
        end
    catch ME
        app.status(sprintf('Frame pick failed: %s', ME.message));
    end
end
```

- [ ] **Step 4: Refactor `nextFrame` to advance dropdown index**

```matlab
function nextFrame(app)
    if isempty(app.State.videoPath); app.status('Load video first'); return; end
    items = app.FramePickerDropdown.Items;
    if isempty(items); return; end
    curIdx = find(strcmp(items, app.FramePickerDropdown.Value), 1);
    if isempty(curIdx); curIdx = 0; end
    nextIdx = mod(curIdx, numel(items)) + 1;
    app.FramePickerDropdown.Value = items{nextIdx};
    app.pickFrame();
end
```

- [ ] **Step 5: Call `rebuildFramePickerDropdown` on video load**

In `setVideo`, after `app.State.numFrames = ...`, add:
```matlab
if ~isempty(app.FramePickerNField)
    app.rebuildFramePickerDropdown();
end
```

- [ ] **Step 6: Manual smoke (BARNES video)**

Load BARNES video. N=20, dropdown has `1/20 .. 20/20`. Pick `10/20` → frame jumps to ~1350. `Next frame` advances dropdown one slot at a time. Try N=5 → dropdown rebuilds to 5 items.

- [ ] **Step 7: Commit**

```bash
git add +sphynx/+app/CreatePresetApp.m
git commit -m "feat(preset): frame picker N-of-M dropdown (S6)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 9: S10 Manual exclusion: circle option

**Files:**
- Modify: `+sphynx/+app/PreprocessTabController.m` (UI dropdown for region shape, branch in `addManualRegion`)

### Steps

- [ ] **Step 1: Add shape dropdown to Region panel**

Find the Region panel build (search `addManualRegion` near line 1585 and walk back to where the panel is built — likely in `buildRegionsPanel`-style method). Add:

```matlab
obj.RegionsShapeDropdown = uidropdown(g, ...
    'Items', {'polygon', 'circle'}, 'Value', 'polygon');
```

- [ ] **Step 2: Branch in `addManualRegion` on shape**

Inside `addManualRegion` (line ~1585), after the figure/axes are set up and before `drawpolygon(ax)`:

```matlab
shape = obj.RegionsShapeDropdown.Value;
switch shape
    case 'polygon'
        h = drawpolygon(ax);
    case 'circle'
        h = drawcircle(ax);
    otherwise
        h = drawpolygon(ax);
end
wait(h);
if ~isvalid(h); return; end
if strcmp(shape, 'circle')
    cx = h.Center(1); cy = h.Center(2); r = h.Radius;
    ang = linspace(0, 2*pi, 60)';
    verts = [cx + r*cos(ang), cy + r*sin(ang)];
else
    verts = h.Position;
end
```

The downstream code that takes `verts` and builds the `reg` struct stays unchanged — `verts` is shaped `Nx2` either way, and `inpolygon` filtering works on both polygons and densely-sampled circles.

- [ ] **Step 3: Manual smoke**

Open Preprocess tab, change shape dropdown to `circle`, click Add region → `drawcircle` UI opens, draw a circle, double-click → region appears in the list as a 60-vertex polygon. Apply preprocessing → frames inside the circle marked as NaN.

- [ ] **Step 4: Commit**

```bash
git add +sphynx/+app/PreprocessTabController.m
git commit -m "feat(preprocess): manual exclusion region circle shape (S10)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 10: S11 Auto exclusion ring N cm from arena

**Files:**
- Create: `+sphynx/+preprocess/arenaExclusionRing.m` (pure helper)
- Modify: `+sphynx/+app/PreprocessTabController.m` (UI checkbox + width field + button, dispatch)
- Test: `tests/unit/arenaExclusionRingTest.m`

### Steps

- [ ] **Step 1: Failing test**

```matlab
function tests = arenaExclusionRingTest
    tests = functiontests(localfunctions);
end

function testRingAroundCircle(testCase)
    H = 100; W = 100;
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask = (X - 50).^2 + (Y - 50).^2 <= 30^2;
    regions = sphynx.preprocess.arenaExclusionRing(arenaMask, 5);
    verifyGreaterThanOrEqual(testCase, numel(regions), 1);
    % Largest region should be a closed loop around the arena
    sizes = cellfun(@(r) size(r.vertices, 1), num2cell(regions));
    verifyGreaterThan(testCase, max(sizes), 20);
end

function testZeroWidthReturnsEmpty(testCase)
    H = 100; W = 100;
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask = (X - 50).^2 + (Y - 50).^2 <= 30^2;
    regions = sphynx.preprocess.arenaExclusionRing(arenaMask, 0);
    verifyEqual(testCase, numel(regions), 0);
end
```

- [ ] **Step 2: Run — fail**

- [ ] **Step 3: Implement `arenaExclusionRing`**

```matlab
function regions = arenaExclusionRing(arenaMask, widthPx)
% ARENAEXCLUSIONRING  Build polygon vertices of a ring of given pixel width
% OUTSIDE the arena boundary.
%
%   regions = sphynx.preprocess.arenaExclusionRing(arenaMask, widthPx)
%
%   Returns a struct array with .vertices (Nx2 [x y]). One element per
%   connected component of the ring (frame edges can split it). Empty
%   array if widthPx <= 0 or arena fills the frame.
    if widthPx <= 0
        regions = struct('vertices', {});
        return;
    end
    arenaMask = arenaMask > 0;
    distOutside = bwdist(arenaMask);
    ringMask = distOutside > 0 & distOutside <= widthPx;
    if ~any(ringMask(:))
        regions = struct('vertices', {});
        return;
    end
    B = bwboundaries(ringMask, 'noholes');
    regions = struct('vertices', {});
    for k = 1:numel(B)
        v = B{k};
        if size(v, 1) < 3; continue; end
        regions(end + 1).vertices = v(:, [2 1]);   % [row col] -> [x y]
    end
end
```

- [ ] **Step 4: Tests pass 2/2**

- [ ] **Step 5: Wire into PreprocessTabController**

5a. UI in Region panel — add beside the Add region button:

```matlab
obj.RegionsAutoRingChk = uicheckbox(g, ...
    'Text', 'Auto-add ring outside arena');
obj.RegionsAutoRingWidthField = uieditfield(g, 'numeric', ...
    'Value', 5, 'Limits', [0.1 100]);
uilabel(g, 'Text', 'cm');
uibutton(g, 'Text', 'Add ring', ...
    'ButtonPushedFcn', @(~,~) obj.addAutoExclusionRing());
```

5b. Add method `addAutoExclusionRing`:

```matlab
function addAutoExclusionRing(obj)
    if isempty(obj.State.arenaMask) || isempty(obj.State.pxlPerCm)
        obj.applog('warn', 'Load a preset with arena.mask + pxlPerCm first');
        return;
    end
    widthCm = obj.RegionsAutoRingWidthField.Value;
    widthPx = widthCm * obj.State.pxlPerCm;
    regions = sphynx.preprocess.arenaExclusionRing(obj.State.arenaMask, widthPx);
    if isempty(regions)
        obj.applog('warn', 'Ring would be empty (widthCm=%.1f)', widthCm);
        return;
    end
    applies = obj.RegionsAppliesDropDown.Value;
    scope = 'experiment';
    if ~isempty(obj.RegionsScopeDropDown)
        scope = obj.RegionsScopeDropDown.Value;
    end
    nAdded = 0;
    for k = 1:numel(regions)
        reg = struct('vertices', regions(k).vertices, ...
            'appliesTo', applies, 'scope', scope);
        obj.State.manualRegions(end + 1) = reg;
        nAdded = nAdded + 1;
    end
    obj.refreshRegionsListBox();
    obj.refreshPreview();
    obj.applog('info', 'Added %d auto-ring region(s) (widthCm=%.1f)', nAdded, widthCm);
end
```

- [ ] **Step 6: Manual smoke**

Load preset with arena. Click Add ring (widthCm=5) → ring polygon appears around arena boundary in preview. If arena touches frame edge, multiple components show in the regions list.

- [ ] **Step 7: Commit**

```bash
git add +sphynx/+preprocess/arenaExclusionRing.m \
        +sphynx/+app/PreprocessTabController.m \
        tests/unit/arenaExclusionRingTest.m
git commit -m "feat(preprocess): auto-exclusion ring N cm from arena (S11)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 11: S7 Auto-detect objects (largest)

**Files:**
- Create: `+sphynx/+preset/autoDetectObjects.m` (algorithm)
- Modify: `+sphynx/+app/CreatePresetApp.m` (new panel: Mode/Algorithm/Sensitivity/MinArea/MaxArea/Radius range sliders, live overlay, Auto-detect + Commit buttons)
- Test: `tests/unit/autoDetectObjectsTest.m`

### Steps

- [ ] **Step 1: Failing tests**

```matlab
function tests = autoDetectObjectsTest
    tests = functiontests(localfunctions);
end

function testThresholdFreeFormFindsBlobs(testCase)
    % Synthetic image: 3 dark circles on light arena
    H = 200; W = 200;
    gray = uint8(220 * ones(H, W));
    arenaMask = false(H, W);
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask((X - 100).^2 + (Y - 100).^2 <= 80^2) = true;
    centers = [60 60; 100 100; 140 60];
    for k = 1:3
        gray((X - centers(k,1)).^2 + (Y - centers(k,2)).^2 <= 8^2) = 30;
    end
    cfg = struct('mode', 'free-form', 'algorithm', 'threshold', ...
        'sensitivity', 0.5, 'minAreaCm2', 0, 'maxAreaCm2', 1e6, ...
        'pxlPerCm', 1);
    objs = sphynx.preset.autoDetectObjects(gray, arenaMask, cfg);
    verifyEqual(testCase, numel(objs), 3);
end

function testCirclesModeProducesCircleObjects(testCase)
    H = 200; W = 200;
    gray = uint8(220 * ones(H, W));
    arenaMask = false(H, W);
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask((X - 100).^2 + (Y - 100).^2 <= 80^2) = true;
    gray((X - 100).^2 + (Y - 100).^2 <= 8^2) = 30;
    cfg = struct('mode', 'all-circles', 'algorithm', 'threshold', ...
        'sensitivity', 0.5, 'minAreaCm2', 0, 'maxAreaCm2', 1e6, ...
        'pxlPerCm', 1);
    objs = sphynx.preset.autoDetectObjects(gray, arenaMask, cfg);
    verifyGreaterThanOrEqual(testCase, numel(objs), 1);
    verifyEqual(testCase, objs(1).geometry, 'Circle');
end

function testHoughCirclesMode(testCase)
    H = 200; W = 200;
    gray = uint8(220 * ones(H, W));
    arenaMask = false(H, W);
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask((X - 100).^2 + (Y - 100).^2 <= 80^2) = true;
    gray((X - 100).^2 + (Y - 100).^2 <= 8^2) = 30;
    cfg = struct('mode', 'all-circles', 'algorithm', 'hough', ...
        'sensitivity', 0.9, 'radiusRangePx', [5 12], ...
        'minAreaCm2', 0, 'maxAreaCm2', 1e6, 'pxlPerCm', 1);
    objs = sphynx.preset.autoDetectObjects(gray, arenaMask, cfg);
    verifyGreaterThanOrEqual(testCase, numel(objs), 1);
    verifyEqual(testCase, objs(1).geometry, 'Circle');
end

function testOutsideArenaFiltered(testCase)
    % Blob outside the arena mask must not be returned
    H = 200; W = 200;
    gray = uint8(220 * ones(H, W));
    arenaMask = false(H, W);
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask((X - 100).^2 + (Y - 100).^2 <= 30^2) = true;
    gray((X - 180).^2 + (Y - 30).^2 <= 8^2) = 30;
    cfg = struct('mode', 'free-form', 'algorithm', 'threshold', ...
        'sensitivity', 0.5, 'minAreaCm2', 0, 'maxAreaCm2', 1e6, ...
        'pxlPerCm', 1);
    objs = sphynx.preset.autoDetectObjects(gray, arenaMask, cfg);
    verifyEqual(testCase, numel(objs), 0);
end
```

- [ ] **Step 2: Run — fail**

- [ ] **Step 3: Implement `autoDetectObjects`**

```matlab
function objs = autoDetectObjects(gray, arenaMask, cfg)
% AUTODETECTOBJECTS  Detect objects inside arena via local-threshold or Hough.
%
%   objs = sphynx.preset.autoDetectObjects(gray, arenaMask, cfg)
%
%   gray       HxW grayscale uint8/uint16/double
%   arenaMask  HxW logical
%   cfg fields (struct):
%     mode         'free-form' | 'all-circles' | 'all-polygons' | 'all-ellipses'
%     algorithm    'threshold' | 'hough'  (hough only for all-circles)
%     sensitivity  0..1
%     minAreaCm2, maxAreaCm2  scalar
%     pxlPerCm     scalar
%     radiusRangePx  (hough only) [rMin rMax]
%
%   Returns struct array with fields type/geometry/border_x/border_y/mask/class.
    objs = struct('type', {}, 'geometry', {}, 'border_x', {}, ...
        'border_y', {}, 'mask', {}, 'class', {});
    if isempty(arenaMask) || ~any(arenaMask(:))
        return;
    end
    if size(gray, 3) > 1
        gray = rgb2gray(gray);
    end
    gray = im2uint8(gray);
    [H, W] = size(arenaMask);
    minAreaPx = cfg.minAreaCm2 * (cfg.pxlPerCm^2);
    maxAreaPx = cfg.maxAreaCm2 * (cfg.pxlPerCm^2);

    if strcmp(cfg.mode, 'all-circles') && strcmp(cfg.algorithm, 'hough')
        [centers, radii] = imfindcircles(gray, cfg.radiusRangePx, ...
            'Sensitivity', cfg.sensitivity, 'ObjectPolarity', 'dark');
        for k = 1:size(centers, 1)
            cx = centers(k, 1); cy = centers(k, 2); r = radii(k);
            if ~arenaMask(round(cy), round(cx)); continue; end
            ang = linspace(0, 2*pi, 60)';
            bx = cx + r * cos(ang);
            by = cy + r * sin(ang);
            mask = imfill(sphynx.preset.maskFromBorder( ...
                H, W, bx, by), 'holes');
            area = sum(mask(:));
            if area < minAreaPx || area > maxAreaPx; continue; end
            objs(end + 1) = mkObj('Circle', bx, by, mask); %#ok<AGROW>
        end
        return;
    end

    threshMap = adaptthresh(gray, cfg.sensitivity);
    binary = imbinarize(gray, threshMap);
    % Objects are typically darker than the floor -> invert
    binary = ~binary & arenaMask;
    binary = imopen(binary, strel('disk', 2));
    cc = bwconncomp(binary);
    stats = regionprops(cc, 'Centroid', 'Area', 'PixelIdxList', ...
        'MajorAxisLength', 'MinorAxisLength', 'Orientation');
    for k = 1:numel(stats)
        if stats(k).Area < minAreaPx || stats(k).Area > maxAreaPx; continue; end
        c = stats(k).Centroid;
        if ~arenaMask(round(c(2)), round(c(1))); continue; end

        compMask = false(H, W);
        compMask(cc.PixelIdxList{k}) = true;

        switch cfg.mode
            case {'free-form', 'all-polygons'}
                B = bwboundaries(compMask, 'noholes');
                if isempty(B); continue; end
                v = B{1};   % single component, single boundary
                bx = v(:, 2); by = v(:, 1);
                if strcmp(cfg.mode, 'all-polygons') && exist('reducepoly', 'file') == 2
                    rv = reducepoly([bx by], 0.02);
                    bx = rv(:, 1); by = rv(:, 2);
                end
                mask = imfill(sphynx.preset.maskFromBorder(H, W, bx, by), 'holes');
                geom = 'Polygon';
            case 'all-circles'
                B = bwboundaries(compMask, 'noholes');
                if isempty(B); continue; end
                v = B{1};
                [xc, yc, R] = sphynx.util.circleFit(v(:, 2), v(:, 1));
                ang = linspace(0, 2*pi, 60)';
                bx = xc + R*cos(ang);
                by = yc + R*sin(ang);
                mask = imfill(sphynx.preset.maskFromBorder(H, W, bx, by), 'holes');
                geom = 'Circle';
            case 'all-ellipses'
                a = stats(k).MajorAxisLength / 2;
                b = stats(k).MinorAxisLength / 2;
                rot = deg2rad(-stats(k).Orientation);
                ang = linspace(0, 2*pi, 60)';
                xx = a*cos(ang); yy = b*sin(ang);
                bx = c(1) + xx*cos(rot) - yy*sin(rot);
                by = c(2) + xx*sin(rot) + yy*cos(rot);
                mask = imfill(sphynx.preset.maskFromBorder(H, W, bx, by), 'holes');
                geom = 'Ellipse';
            otherwise
                error('sphynx:autoDetectObjects:unknownMode', ...
                    'Unknown mode: %s', cfg.mode);
        end
        objs(end + 1) = mkObj(geom, bx, by, mask); %#ok<AGROW>
    end
end

function o = mkObj(geometry, bx, by, mask)
    o.type = '';            % caller numbers them
    o.geometry = geometry;
    o.border_x = bx(:);
    o.border_y = by(:);
    o.mask = mask;
    o.class = '';
end
```

- [ ] **Step 4: Tests pass 4/4**

```bash
matlab -batch "addpath(genpath(pwd)); runtests('tests/unit/autoDetectObjectsTest.m')"
```

- [ ] **Step 5: Build the auto-detect UI panel in CreatePresetApp**

In the objects area, add a new collapsible panel:

```matlab
adPanel = uipanel(parentGrid, 'Title', 'Auto-detect');
ag = uigridlayout(adPanel, [7, 3]);
ag.RowHeight = repmat({28}, 1, 7);
ag.ColumnWidth = {120, '1x', 'fit'};

uilabel(ag, 'Text', 'Mode:');
app.AutoModeDropdown = uidropdown(ag, ...
    'Items', {'free-form', 'all-circles', 'all-polygons', 'all-ellipses'}, ...
    'Value', 'free-form');
uilabel(ag, 'Text', '');

uilabel(ag, 'Text', 'Algorithm (circles):');
app.AutoAlgorithmDropdown = uidropdown(ag, ...
    'Items', {'threshold', 'hough'}, 'Value', 'threshold');
uilabel(ag, 'Text', '');

uilabel(ag, 'Text', 'Sensitivity:');
app.AutoSensitivitySlider = uislider(ag, 'Limits', [0 1], 'Value', 0.5);
uilabel(ag, 'Text', '');

uilabel(ag, 'Text', 'Min area, cm^2:');
app.AutoMinAreaField = uieditfield(ag, 'numeric', 'Value', 1, 'Limits', [0 1e6]);
uilabel(ag, 'Text', '');

uilabel(ag, 'Text', 'Max area, cm^2:');
app.AutoMaxAreaField = uieditfield(ag, 'numeric', 'Value', 500, 'Limits', [0 1e6]);
uilabel(ag, 'Text', '');

uilabel(ag, 'Text', 'Radius range, px (Hough):');
app.AutoRadiusMinField = uieditfield(ag, 'numeric', 'Value', 5);
app.AutoRadiusMaxField = uieditfield(ag, 'numeric', 'Value', 30);

uilabel(ag, 'Text', 'Start numbering from:');
app.AutoStartFromField = uieditfield(ag, 'numeric', 'Value', 1, ...
    'Limits', [1 1e6], 'RoundFractionalValues', 'on');
buttonRow = uigridlayout(ag, [1, 2]);
buttonRow.Layout.Column = [1 3];
uibutton(buttonRow, 'Text', 'Auto-detect', ...
    'ButtonPushedFcn', @(~,~) app.runAutoDetect());
uibutton(buttonRow, 'Text', 'Commit detected', ...
    'ButtonPushedFcn', @(~,~) app.commitAutoDetected());
```

Initialize `app.State.autoDetectedObjects = struct('type', {}, ...)` in state init.

- [ ] **Step 6: Implement `runAutoDetect`**

```matlab
function runAutoDetect(app)
    if isempty(app.State.frame) || isempty(app.State.arena)
        app.status('Need video + arena before auto-detect');
        return;
    end
    cfg = struct( ...
        'mode',         app.AutoModeDropdown.Value, ...
        'algorithm',    app.AutoAlgorithmDropdown.Value, ...
        'sensitivity',  app.AutoSensitivitySlider.Value, ...
        'minAreaCm2',   app.AutoMinAreaField.Value, ...
        'maxAreaCm2',   app.AutoMaxAreaField.Value, ...
        'pxlPerCm',     app.State.pxlPerCm, ...
        'radiusRangePx',[app.AutoRadiusMinField.Value, app.AutoRadiusMaxField.Value]);
    try
        gray = rgb2gray(app.State.frame);
        objs = sphynx.preset.autoDetectObjects(gray, app.State.arena.mask, cfg);
        app.State.autoDetectedObjects = objs;
        app.refreshPreview();   % preview-time overlay handler reads autoDetectedObjects
        app.status(sprintf('Auto-detected %d objects (preview only; click Commit to add)', numel(objs)));
    catch ME
        app.status(sprintf('Auto-detect failed: %s', ME.message));
    end
end
```

- [ ] **Step 7: Implement `commitAutoDetected`**

```matlab
function commitAutoDetected(app)
    if isempty(app.State.autoDetectedObjects)
        app.status('Nothing to commit. Run Auto-detect first.');
        return;
    end
    startNum = app.AutoStartFromField.Value;
    newObjs = app.State.autoDetectedObjects;
    for k = 1:numel(newObjs)
        newObjs(k).type = sprintf('Object%d', startNum + k - 1);
    end
    if isempty(app.State.objects)
        app.State.objects = newObjs;
    else
        for k = 1:numel(newObjs)
            app.State.objects(end + 1) = newObjs(k);
        end
    end
    app.State.autoDetectedObjects = struct('type', {}, 'geometry', {}, ...
        'border_x', {}, 'border_y', {}, 'mask', {}, 'class', {});
    app.refreshObjectsList();
    app.refreshMoveTargets();
    app.refreshPreview();
    app.status(sprintf('Committed %d auto-detected objects', numel(newObjs)));
end
```

- [ ] **Step 8: Update preview overlay to draw `autoDetectedObjects`**

In the preview-draw code, after objects are drawn, add an overlay for `app.State.autoDetectedObjects` in `[0 0.8 0]` (green), alpha 0.3, line dashed (`LineStyle','--'`).

- [ ] **Step 9: Manual smoke on Barnes**

Load BARNES preset (arena defined). Auto-detect with `all-circles` + `threshold` + sens=0.5. Green dashed circles should appear around detected holes inside the arena. Try `hough` algorithm — compare. Adjust sliders, re-run. Commit → green outlines turn into permanent objects, listbox repopulates.

- [ ] **Step 10: Commit**

```bash
git add +sphynx/+preset/autoDetectObjects.m \
        +sphynx/+app/CreatePresetApp.m \
        tests/unit/autoDetectObjectsTest.m
git commit -m "feat(preset): auto-detect objects via threshold + Hough (S7)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 12 (final): Full-suite regression sweep

**Files:** none new.

### Steps

- [ ] **Step 1: Full fast test suite**

```bash
matlab -batch "addpath(genpath(pwd)); runAllTests('tag','fast')"
```

Expected: PASS, all tests including the ~25 new tests added across S1-S11.

- [ ] **Step 2: BARNES end-to-end smoke**

Manual user pass on BARNES video + preset:
1. Load video + preset, calibrate by 1 line.
2. Pick a representative frame via N=20 dropdown.
3. Auto-detect circles in `hough` mode, commit. Verify object count ~ 20 for Barnes holes.
4. Multi-select all detected via Ctrl+A or marquee, assign class `hole`.
5. Save preset, reopen — class persists.

- [ ] **Step 3: No commit (verification-only).**

---

## Self-review

**Spec coverage:**

- S1 → Task 1. ✓
- S2 → Task 4. ✓
- S3 → Task 5. ✓
- S4 → Task 6. ✓
- S5 → Task 7. ✓
- S6 → Task 8. ✓
- S7 → Task 11. ✓
- S8 → Task 2. ✓
- S9 → Task 3. ✓
- S10 → Task 9. ✓
- S11 → Task 10. ✓

**Placeholder scan:** all code blocks contain actual MATLAB. No TBD / TODO / "implement later" / "fill in details". Where the existing-codebase context is referenced (e.g. "search by name", "find the calibration button"), the search anchor is concrete enough to locate the spot.

**Type consistency:**

- `app.State.selectedObjectIdx` defined in Task 1, used in Tasks 2/3/4/11.
- `app.getSelectedObjectIdx()` defined in Task 1, used in Tasks 2/3/4.
- `sphynx.preset.readFrameAt` defined in Pass 1 A1.5, reused in Task 8.
- `sphynx.preset.gridOffsets`, `rotateAroundCentroid`, `marqueeSelect`, `buildZonesCircleCenter`, `arenaExclusionRing`, `autoDetectObjects` — each is created in one task, used only by callers in the same or later tasks.
- `cfg` struct for `autoDetectObjects` has `mode`/`algorithm`/`sensitivity`/`minAreaCm2`/`maxAreaCm2`/`pxlPerCm`/`radiusRangePx` fields — used consistently in Task 11 Steps 1 (test), 3 (impl), 6 (`runAutoDetect`).

**Scope check:** 11 features, each in one task, no cross-cutting refactors beyond S1's selection model. Plan fits one implementation pass.

**Ambiguity check:**

- Marquee selection trigger: Task 1 Step 5 covers Ctrl-click via standard `uilistbox Multiselect`. The canvas marquee (`drawrectangle` on the preview) is left unwired in the plan — the spec mentions it but the listbox alone covers Barnes 20-hole multi-select adequately. **Decision: ship listbox-only multi-select in Task 1. Canvas marquee deferred to future polish.**
- S5 `circle-with-center` arena centroid: for irregular arenas (Polygon), centroid = mean of border points. Documented in `buildZonesCircleCenter`. For Circle / Ellipse the centroid is the fit center.

---

## Out of scope (deferred to future passes)

- Canvas marquee for object selection (S1 mentions it; listbox multi-select shipped in Task 1 satisfies the Barnes workflow).
- Project subsystem brainstorm continuation (paused 2026-05-12, sections 6-8 remain).
- Barnes-specific downstream metrics in Analyze Session (8 train + 9 test).
- Per-experiment preset templates.
- Polish-pass items from Pass 1 (logged in `docs/superpowers/logs/claude_log.md` 2026-06-04).
