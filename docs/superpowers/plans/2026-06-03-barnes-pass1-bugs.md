# Barnes Pass 1 — Bug fixes implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix three bugs discovered while preparing the Barnes paradigm — VideoReader.NumFrames unreliable on VFR h264 MP4, classifyCircle drops middle/center rings near boundary parameters, readDLC fails on RU locale decimal separator.

**Architecture:** Three independent point-fixes, each in its own commit. No new architecture. Pure-function helper extracted for A1 to keep the fix testable without a VideoReader mock.

**Tech Stack:** MATLAB R2020a (`VideoReader`, `readmatrix`, `bwdist`), existing `+sphynx/+preset/`, `+sphynx/+zones/`, `+sphynx/+io/` packages. Tests via `functiontests` in `tests/unit/`.

**Spec:** `docs/superpowers/specs/2026-06-03-barnes-features-design.md` Pass 1 (sections A1, A2, A3).

---

## Task A1: numFrames fallback for VFR h264

**Problem:** `VideoReader.NumFrames` in R2020a returns `2` for `Demo/BARNES/2_Video/VIDEO_20260411_130747271.mp4` (h264 VFR, 59/3 fps). User sees "two frames to choose from" in Next Frame nav because `step = max(round(2/20),1) = 1` and `mod(idx+0, 2) + 1` cycles between 1 and 2.

**Files:**
- Create: `+sphynx/+preset/correctedFrameCount.m`
- Modify: `+sphynx/+preset/pickGoodFrame.m`
- Test: `tests/unit/correctedFrameCountTest.m`

### Steps

- [ ] **Step 1: Write the failing test for the pure helper**

Create `tests/unit/correctedFrameCountTest.m`:

```matlab
function tests = correctedFrameCountTest
    tests = functiontests(localfunctions);
end

function testGoodCountPassThrough(testCase)
    % NumFrames matches duration*fps - return it as-is
    n = sphynx.preset.correctedFrameCount(2702, 137.4, 19.67);
    verifyEqual(testCase, n, 2702);
end

function testUnreliableLowReturnsFallback(testCase)
    % R2020a VideoReader bug: NumFrames=2 for VFR h264, real ~2702
    n = sphynx.preset.correctedFrameCount(2, 137.4, 19.67);
    expected = round(137.4 * 19.67);   % 2703
    verifyEqual(testCase, n, expected);
end

function testNanReturnsFallback(testCase)
    n = sphynx.preset.correctedFrameCount(NaN, 100, 30);
    verifyEqual(testCase, n, 3000);
end

function testZeroOrNegativeReturnsFallback(testCase)
    verifyEqual(testCase, sphynx.preset.correctedFrameCount(0, 60, 30), 1800);
    verifyEqual(testCase, sphynx.preset.correctedFrameCount(-5, 60, 30), 1800);
end

function testFallbackOnlyWhenSignificantlyOff(testCase)
    % If NumFrames is within 5% of duration*fps, trust it (avoids
    % rejecting accurate counts that differ by a few frames from rounding).
    n = sphynx.preset.correctedFrameCount(2700, 137.4, 19.67);
    verifyEqual(testCase, n, 2700);   % within ~0.1%, kept
end

function testBadFallbackInputReturnsOriginal(testCase)
    % If we can't compute fallback (no duration or no fps), return
    % whatever count we got (caller's responsibility).
    verifyEqual(testCase, sphynx.preset.correctedFrameCount(2, 0, 30), 2);
    verifyEqual(testCase, sphynx.preset.correctedFrameCount(2, 100, 0), 2);
    verifyEqual(testCase, sphynx.preset.correctedFrameCount(2, NaN, 30), 2);
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
matlab -batch "addpath(genpath(pwd)); runtests('tests/unit/correctedFrameCountTest.m')"
```

Expected: 6 tests FAIL with `Undefined function 'sphynx.preset.correctedFrameCount'`.

- [ ] **Step 3: Implement the helper**

Create `+sphynx/+preset/correctedFrameCount.m`:

```matlab
function n = correctedFrameCount(numFrames, durationS, frameRate)
%CORRECTEDFRAMECOUNT  Robust frame count for VideoReader, working around
% R2020a's NumFrames bug on VFR h264 MP4.
%
%   n = sphynx.preset.correctedFrameCount(numFrames, durationS, frameRate)
%
%   If `numFrames` is NaN, <= 0, or differs from `durationS*frameRate`
%   by more than 5%, return the duration-based estimate (which is
%   accurate for any video where duration and frame rate are reliable).
%   Otherwise return `numFrames` unchanged.
%
%   If the fallback cannot be computed (durationS or frameRate <= 0,
%   or NaN), return the original `numFrames` unchanged — caller decides
%   how to handle.
    canFallback = isfinite(durationS) && durationS > 0 && ...
                  isfinite(frameRate) && frameRate > 0;
    if ~canFallback
        n = numFrames;
        return;
    end
    fallback = round(durationS * frameRate);
    if ~isfinite(numFrames) || numFrames <= 0
        n = fallback;
        return;
    end
    relErr = abs(numFrames - fallback) / max(fallback, 1);
    if relErr > 0.05
        n = fallback;
    else
        n = numFrames;
    end
end
```

- [ ] **Step 4: Run test to verify it passes**

```bash
matlab -batch "addpath(genpath(pwd)); runtests('tests/unit/correctedFrameCountTest.m')"
```

Expected: 6/6 PASS.

- [ ] **Step 5: Integrate into pickGoodFrame**

Modify `+sphynx/+preset/pickGoodFrame.m` — replace lines 23-27:

```matlab
    v = VideoReader(videoPath);
    out.frameRate = v.FrameRate;
    rawCount = v.NumFrames;
    out.numFrames = sphynx.preset.correctedFrameCount(rawCount, v.Duration, v.FrameRate);
    if out.numFrames ~= rawCount
        sphynx.util.log('warn', ...
            '[pickGoodFrame] VideoReader.NumFrames=%g unreliable; using Duration*FrameRate=%d', ...
            rawCount, out.numFrames);
    end
    out.height = v.Height;
    out.width = v.Width;
```

- [ ] **Step 6: Smoke-test against the user's reproduction video**

```bash
matlab -batch "addpath(genpath(pwd)); gframe = sphynx.preset.pickGoodFrame('Demo/BARNES/2_Video/VIDEO_20260411_130747271.mp4', 'FrameIndex', 1); fprintf('numFrames=%d (expected ~2700)\n', gframe.numFrames);"
```

Expected output line: `numFrames=2703 (expected ~2700)` (or close), with a `[WARN] [pickGoodFrame] VideoReader.NumFrames=2 unreliable; using Duration*FrameRate=2703` warning above it.

- [ ] **Step 7: Commit**

```bash
git add +sphynx/+preset/correctedFrameCount.m +sphynx/+preset/pickGoodFrame.m tests/unit/correctedFrameCountTest.m
git commit -m "fix(preset): robust frame count for VFR h264 (A1)"
```

---

## Task A2: classifyCircle relaxed boundaries

**Problem:** With `WallWidthCm=12, MiddleWidthCm=24, MinCenterCm=10` on a 92 cm circle arena, `wallW + midW + minC = 46 cm = arena radius`. The early-return `if maxDist < wallW + minC; return;` may discard the center, and the strict `<=` in the loop is flaky from floating-point rasterization. For ellipses with a thin minor axis, the inscribed-circle approach also strips middle rings.

**Files:**
- Modify: `+sphynx/+zones/classifyCircle.m`
- Modify: `tests/unit/classifyCircleTest.m`

### Steps

- [ ] **Step 1: Update the existing test that asserts old behavior**

Existing `testNoCenterIfTooSmall` (lines 35-47) asserts the old "no center if too small" behavior. After the fix, `center` is always added when there's any room past the wall. Replace the test body:

```matlab
function testCenterAlwaysAddedEvenIfNarrow(testCase)
    % R=15 cm, wall=10 cm: only 5 cm of center remains (< minC=10).
    % Old behavior: dropped center. New behavior: center is kept,
    % just narrower than MinCenterCm.
    H = 200; W = 200; pxlPerCm = 2;
    arenaMask = makeCircleMask(H, W, 100, 100, 15 * pxlPerCm);
    zones = sphynx.zones.classifyCircle(arenaMask, ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 10, ...
        'MiddleWidthCm', 20, ...
        'MinCenterCm', 10);
    names = {zones.name};
    verifyTrue(testCase, ismember('wall', names));
    verifyTrue(testCase, ismember('center', names));
    verifyFalse(testCase, ismember('middle1', names));
end
```

- [ ] **Step 2: Add a new test for the user-reported boundary case**

Append to `tests/unit/classifyCircleTest.m`:

```matlab
function testBoundary92cmArenaKeepsMiddleAndCenter(testCase)
    % User repro: WallW=12, MidW=24, arena diameter 92 cm.
    % wallW+midW+minC = 12+24+10 = 46 cm = arena radius exactly.
    % Old behavior: middle1 sometimes dropped due to float boundary.
    % New behavior: {wall, middle1, center} always returned.
    H = 600; W = 600; pxlPerCm = 5;
    arenaMask = makeCircleMask(H, W, 300, 300, 46 * pxlPerCm);
    zones = sphynx.zones.classifyCircle(arenaMask, ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 12, ...
        'MiddleWidthCm', 24, ...
        'MinCenterCm', 10);
    names = {zones.name};
    verifyTrue(testCase, ismember('wall', names));
    verifyTrue(testCase, ismember('middle1', names));
    verifyTrue(testCase, ismember('center', names));
end

function testEllipseThinMinorAxisStillProducesCenter(testCase)
    % Ellipse 90x60 cm with wall=12, mid=24, minC=10.
    % Minor radius = 30 cm, so maxDist ~= 30 cm.
    % wallW+midW+minC = 46 > 30 -> old behavior returned only wall.
    % New behavior: {wall, center} (center fills 30-12=18 cm wide).
    H = 600; W = 600; pxlPerCm = 5;
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask = ((X - 300) / (45 * pxlPerCm)).^2 + ...
                ((Y - 300) / (30 * pxlPerCm)).^2 <= 1;
    zones = sphynx.zones.classifyCircle(arenaMask, ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 12, ...
        'MiddleWidthCm', 24, ...
        'MinCenterCm', 10);
    names = {zones.name};
    verifyTrue(testCase, ismember('wall', names));
    verifyTrue(testCase, ismember('center', names));
end
```

- [ ] **Step 3: Run the test suite to see the new tests fail**

```bash
matlab -batch "addpath(genpath(pwd)); runtests('tests/unit/classifyCircleTest.m')"
```

Expected: `testCenterAlwaysAddedEvenIfNarrow`, `testBoundary92cmArenaKeepsMiddleAndCenter`, `testEllipseThinMinorAxisStillProducesCenter` FAIL; others (incl. `testLargeArenaWithMiddleRings`, `testZonesArePartitionOfArena`) PASS.

- [ ] **Step 4: Apply the classifyCircle fix**

Modify `+sphynx/+zones/classifyCircle.m`. Replace the body block from line 49 to line 84 (zones-building section) with:

```matlab
    zones = struct('name',{},'type',{},'maskfilled',{});

    % Wall always exists (outermost ring). No early return — we always
    % try to produce wall + (optional middles) + center.
    wallRing = paddedMask & distFromOutside > 0 & distFromOutside <= wallW;
    if any(wallRing(:))
        zones(end+1) = mkZone('wall', wallRing, pad); %#ok<AGROW>
    end

    % Greedy middles: add a ring whenever there is at least midW worth
    % of space past the current cumulative width. Relaxed boundary
    % (epsilon = 0.5 px) tolerates rasterization slop on exact
    % wall+mid+minC == radius arenas.
    eps = 0.5;
    cumW = wallW;
    middleIdx = 1;
    while cumW + midW <= maxDist + eps
        nextCumW = cumW + midW;
        ring = paddedMask & distFromOutside > cumW & distFromOutside <= nextCumW;
        if any(ring(:))
            zones(end+1) = mkZone(sprintf('middle%d', middleIdx), ring, pad); %#ok<AGROW>
        end
        cumW = nextCumW;
        middleIdx = middleIdx + 1;
        if middleIdx > 50
            error('sphynx:classifyCircle:tooManyRings', ...
                'Computed > 50 middle rings; check input parameters');
        end
    end

    % Center: everything past the last middle (or past wall if no middles).
    % Added unconditionally if any pixels remain — even if narrower than
    % MinCenterCm. MinCenterCm now controls greedy-middle stopping (above)
    % rather than dropping the center entirely.
    centerMask = paddedMask & distFromOutside > cumW;
    if any(centerMask(:))
        zones(end+1) = mkZone('center', centerMask, pad); %#ok<AGROW>
    end
end
```

Also update the docstring (lines 18-21) to reflect the new semantics:

```matlab
%   Behavior (updated 2026-06-03):
%     - Wall is always returned (no early return).
%     - Middles are added greedily while there is room for another full
%       ring of width MiddleWidthCm; epsilon-relaxed comparison tolerates
%       float rasterization slop at exact wall+mid+minC == radius.
%     - Center is always added if any pixels remain past the last middle
%       (even when narrower than MinCenterCm — Barnes-style narrow arenas).
%
%   Bug-1 fix (preserved): distance transform runs on a padded frame so
%   arenas touching the original frame edge classify correctly.
```

- [ ] **Step 5: Run the suite to verify all pass**

```bash
matlab -batch "addpath(genpath(pwd)); runtests('tests/unit/classifyCircleTest.m')"
```

Expected: all tests in the file PASS (5 existing + 3 new = 8 total, but `testCenterAlwaysAddedEvenIfNarrow` replaces `testNoCenterIfTooSmall` → net 7).

- [ ] **Step 6: Commit**

```bash
git add +sphynx/+zones/classifyCircle.m tests/unit/classifyCircleTest.m
git commit -m "fix(zones): classifyCircle relaxed boundaries; always emit center (A2)"
```

---

## Task A3: readDLC decimal separator on RU locale

**Problem:** `readDLC.m:58` calls `readmatrix(csvPath, 'NumHeaderLines', 3)` without specifying `DecimalSeparator`. On Russian Windows locale, `readmatrix` may interpret `.` as a thousands separator and fail to parse, yielding NaN columns. Downstream `hampelFilter` / `applyPerPartSettings` then error with "Value must be a real-valued vector of type double" or similar.

**Files:**
- Modify: `+sphynx/+io/readDLC.m`
- Test: `tests/unit/readDLCLocaleTest.m`

### Steps

- [ ] **Step 1: Write the failing locale-robustness test**

Create `tests/unit/readDLCLocaleTest.m`:

```matlab
function tests = readDLCLocaleTest
    tests = functiontests(localfunctions);
end

function testReadsDotDecimalsCleanly(testCase)
    % Round-trip a small synthetic DLC CSV with '.' decimals; assert
    % no NaN in the data and that the parsed numbers match the source.
    csv = makeTempDlcCsv();
    cleaner = onCleanup(@() delete(csv)); %#ok<NASGU>

    out = sphynx.io.readDLC(csv);

    verifyEqual(testCase, out.nFrames, 5);
    verifyEqual(testCase, numel(out.bodyPartsNames), 2);
    verifyFalse(testCase, any(isnan(out.X(:))), ...
        'X has NaN — likely DecimalSeparator misparse on this locale');
    verifyFalse(testCase, any(isnan(out.Y(:))), ...
        'Y has NaN — likely DecimalSeparator misparse on this locale');
    % Spot-check exact values
    verifyEqual(testCase, out.X(1, 1), 100.5,  'AbsTol', 1e-6);
    verifyEqual(testCase, out.Y(1, 1), 200.25, 'AbsTol', 1e-6);
    verifyEqual(testCase, out.likelihood(1, 1), 0.987, 'AbsTol', 1e-6);
end

function csv = makeTempDlcCsv()
    csv = [tempname, '.csv'];
    fid = fopen(csv, 'w');
    fprintf(fid, 'scorer,DLC,DLC,DLC,DLC,DLC,DLC\n');
    fprintf(fid, 'bodyparts,nose,nose,nose,tail,tail,tail\n');
    fprintf(fid, 'coords,x,y,likelihood,x,y,likelihood\n');
    rows = [
        0, 100.5,  200.25, 0.987, 110.1, 210.7, 0.93;
        1, 101.2,  201.05, 0.991, 110.9, 211.2, 0.94;
        2, 102.05, 202.3,  0.988, 111.0, 212.8, 0.95;
        3, 102.9,  203.45, 0.985, 112.5, 213.0, 0.92;
        4, 103.7,  204.15, 0.989, 113.1, 214.6, 0.91;
    ];
    for r = 1:size(rows, 1)
        fprintf(fid, '%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n', rows(r, :));
    end
    fclose(fid);
end
```

- [ ] **Step 2: Run the test to verify it passes on EN locale (sanity baseline)**

```bash
matlab -batch "addpath(genpath(pwd)); runtests('tests/unit/readDLCLocaleTest.m')"
```

Expected on EN locale: PASS. (The test will also PASS without the fix because EN locale already defaults to '.'. The point of the test is to lock the contract — if a future readmatrix change or a different locale would break it, the test catches it. To force-prove failure, run with `setenv('LANG', 'ru_RU.UTF-8')` before; not strictly needed for plan validation.)

- [ ] **Step 3: Apply the readDLC fix**

Modify `+sphynx/+io/readDLC.m:58`. Replace:

```matlab
    data = readmatrix(csvPath, 'NumHeaderLines', 3);
```

with:

```matlab
    % Force '.' as decimal separator. DLC CSVs always use '.', but
    % readmatrix on RU-locale Windows can misparse '.' as a thousands
    % separator, yielding NaN columns that crash downstream filters.
    data = readmatrix(csvPath, 'NumHeaderLines', 3, 'DecimalSeparator', '.');
```

- [ ] **Step 4: Re-run the test to confirm it still passes**

```bash
matlab -batch "addpath(genpath(pwd)); runtests('tests/unit/readDLCLocaleTest.m')"
```

Expected: PASS (unchanged on EN locale; the fix is a contract lock for RU).

- [ ] **Step 5: Run the broader DLC-related test suite to catch regression**

```bash
matlab -batch "addpath(genpath(pwd)); runtests({'tests/unit/cleanBodyPartTest.m', 'tests/unit/applyPerPartSettingsTest.m', 'tests/unit/hampelFilterTest.m'})"
```

Expected: all PASS (no behavioral change on existing good CSVs).

- [ ] **Step 6: Commit**

```bash
git add +sphynx/+io/readDLC.m tests/unit/readDLCLocaleTest.m
git commit -m "fix(io): readDLC forces '.' decimal separator (A3)"
```

---

## Task A4 (final): Full-suite smoke + Barnes integration check

**Files:** none new.

### Steps

- [ ] **Step 1: Run the full fast test suite**

```bash
matlab -batch "addpath(genpath(pwd)); runAllTests('tag','fast')"
```

Expected: all tests PASS (no regression from A1-A3).

- [ ] **Step 2: Smoke against the BARNES video + (optional) BARNES DLC csv**

Reproduction shown in A1 Step 6 already covers the video. If user has a BARNES DLC CSV in `Demo/BARNES/`, run:

```bash
matlab -batch "addpath(genpath(pwd)); dlc = dir('Demo/BARNES/**/*DLC*.csv'); if isempty(dlc); fprintf('no DLC csv in Demo/BARNES — skipping\n'); else out = sphynx.io.readDLC(fullfile(dlc(1).folder, dlc(1).name)); fprintf('loaded %d frames, %d parts, NaN count X=%d\n', out.nFrames, numel(out.bodyPartsNames), sum(isnan(out.X(:)))); end"
```

Expected: `NaN count X=0` (modulo legitimate low-likelihood gaps in the source).

- [ ] **Step 3: No commit (verification-only step).**

---

## Self-review

Going through the spec sections A1, A2, A3 against the plan:

- **A1 numFrames:** spec asked for `if NaN or <= 1, fallback`. Plan implements as `correctedFrameCount` with a 5% relative-error band (handles BOTH the "NumFrames=2 case" AND a "NumFrames=2700 close to fallback 2703" pass-through case). More robust than the spec literal. Test coverage: 6 cases. Integration in `pickGoodFrame` logs the fallback. **Covered.**

- **A2 classifyCircle:** spec asked for removed early return, eps-relaxed loop, center any width. All three landed in Step 4. Updated docstring. Old behavior test `testNoCenterIfTooSmall` swapped for `testCenterAlwaysAddedEvenIfNarrow` (intentional contract change, called out in Step 1). Two new tests for the user-reported scenarios. **Covered.**

- **A3 readDLC:** spec asked for `'DecimalSeparator', '.'`. One-line change in Step 3, locked by a contract test. Regression sweep in Step 5 to ensure downstream is unaffected. **Covered.**

- **Final smoke:** spec mentioned "опциональный финальный smoke на BARNES video". Plan Task A4 covers it. **Covered.**

No placeholders. No TODO. No "implement later". Method signature `correctedFrameCount(numFrames, durationS, frameRate)` is used consistently in Steps 1, 3, 5. Test file names match existing convention (`*Test.m` in `tests/unit/`).

---

## Out of scope (Pass 2)

The 11 feature sections (S1-S11) from the spec are deferred to a separate plan
written after Pass 1 lands. Implementation order proposal already in spec.
