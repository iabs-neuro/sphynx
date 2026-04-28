# Sphynx Stage C — что написано и как это потрогать

State: end of Pass A (4 known bugs fixed, zone partitioning feature 1.3 implemented).
Branch: `sphynx-GUI`. Test suite: **63 passed, 0 failed, 1 skipped** (the smoke is a placeholder for Pass B).

This doc is a tour of the new `+sphynx/` package — everything you can call, what it does, and example commands to try.

---

## Quick start

In MATLAB Command Window with the repo as current folder:

```matlab
startup                                  % adds paths, once per session
runAllTests('tag','fast')                % runs the full test suite
```

Or from PowerShell directly (no MATLAB GUI):

```bash
matlab -batch "startup; runAllTests('tag','fast')"
```

---

## Architecture overview

All new code lives in the MATLAB package `+sphynx/`. Old code at the repo root (BehaviorAnalyzer.m, CreatePreset.m, Projects/, Cross-analysis/, functions/, tools/) is **not modified** — it keeps working as before.

```
+sphynx/
+-- +util/         general helpers (no domain knowledge)
+-- +zones/        spatial-zone classification (Bug-1, feature 1.3)
+-- +angles/       circular-angle math (Bug-2)
+-- +preprocess/   trace cleaning and smoothing (Bug-3, Bug-4)
+-- +testing/      synthetic fixtures used by tests
+-- +preprocess/+kalman/ (placeholder, will be migrated in Pass B/C)
+-- +bodyparts/    (Pass B)
+-- +acts/         (Pass B)
+-- +pipeline/     (Pass B)
+-- +viz/          (Pass B+)
+-- +preset/       (Pass C)
+-- +io/           (Pass B)
+-- +app/          (Pass D — CreatePresetApp.mlapp)
```

Bracketed packages are empty so far; their contents arrive in later passes.

---

## sphynx.util — general helpers

### sphynx.util.repoRoot()

Returns the absolute path to the repo root. Used by tests and snapshots so they don't depend on `cd`.

```matlab
sphynx.util.repoRoot()
% ans = 'C:\Users\User\PycharmProjects\sphynx'
```

### sphynx.util.log(level, fmt, ...)

Verbose-aware logger. Levels: `debug` < `info` < `warn` < `error`. Default threshold is `info`. Override with env var `SPHYNX_LOG_LEVEL`.

```matlab
sphynx.util.log('info', 'Loaded %d frames', 1234);
% [INFO] Loaded 1234 frames

sphynx.util.log('debug', 'silenced by default');
% (no output)

setenv('SPHYNX_LOG_LEVEL', 'debug');
sphynx.util.log('debug', 'now visible');
% [DEBUG] now visible
setenv('SPHYNX_LOG_LEVEL', '');
```

### sphynx.util.progress(action, ...)

Wraps MATLAB's `waitbar`, but no-ops in headless/test mode (`SPHYNX_HEADLESS=1`).

```matlab
h = sphynx.util.progress('open', 100, 'Working');
for k = 1:100
    pause(0.01);
    sphynx.util.progress('update', h, k, 'Working');
end
sphynx.util.progress('close', h);
```

### sphynx.util.circleFit(x, y)

Least-squares circle fit through given (x, y) points. Replaces `functions/circfit.m` with explicit errors on bad input.

```matlab
th = linspace(0, 2*pi, 50)';
x = 5 + 3*cos(th); y = -7 + 3*sin(th);
[xc, yc, r] = sphynx.util.circleFit(x, y)
% xc = 5.0000, yc = -7.0000, r = 3.0000
```

Errors: `tooFewPoints`, `degenerate` (collinear).

### sphynx.util.polygonFit(xCorners, yCorners)

Builds a closed dense polygon outline + per-side traces from corner points. Replaces `functions/PolygonFit.m`.

```matlab
[x, y, sidesX, sidesY] = sphynx.util.polygonFit([0;10;10;0], [0;0;10;10]);
% sidesX{1} is the bottom side (1000 points by default)
% size(x) == size(y) == [4000, 1]
plot(x, y); axis equal;
```

### sphynx.util.inMaskSafe(mask, x, y)

Query a 2D logical mask at `(x, y)` safely. Vectorized; returns `false` for out-of-bounds coordinates instead of crashing. This is the building block for the Bug-1 fix.

```matlab
mask = false(10, 10); mask(3:7, 3:7) = true;
sphynx.util.inMaskSafe(mask, 5, 5)        % true
sphynx.util.inMaskSafe(mask, 100, 5)      % false (was a crash before)
sphynx.util.inMaskSafe(mask, [5; 1; 100], [5; 1; 5])
% [true; false; false]
```

---

## sphynx.zones — spatial classification

### sphynx.zones.partitionStrips(arenaMask, N, direction)

Divides a binary arena mask into `N` equal horizontal or vertical strips. Implements feature 1.3 for square arenas.

```matlab
arenaMask = false(100, 200);
arenaMask(20:80, 20:180) = true;
zones = sphynx.zones.partitionStrips(arenaMask, 4, 'horizontal');
% zones(1).name = 'strip1', zones(2).name = 'strip2', ...
imshow(zones(2).maskfilled);            % visualize the second strip
```

### sphynx.zones.classifyCircle(arenaMask, ...)

Generalized ring-based partitioning for round arenas. Outputs concentric zones: `wall`, `middle1`, `middle2`, ..., `center`.

```matlab
H = 400; W = 400; pxlPerCm = 2;
[X, Y] = meshgrid(1:W, 1:H);
arenaMask = (X-200).^2 + (Y-200).^2 <= (80*pxlPerCm)^2;   % 80 cm radius

zones = sphynx.zones.classifyCircle(arenaMask, ...
    'PixelsPerCm', pxlPerCm, ...
    'WallWidthCm', 10, ...
    'MiddleWidthCm', 20);
{zones.name}
% {'wall'  'middle1'  'middle2'  'middle3'  'center'}
```

For a 30 cm arena it produces just `wall` + `center`. For a 15 cm arena (smaller than wall+minCenter), only `wall`. **Bug-1 fix**: the algorithm pads the frame so arenas touching frame edges classify correctly (no empty wall/corner zones).

### sphynx.zones.classifySquare(arenaMask, ...)

Square / polygon arena classification. Three strategies:

```matlab
% Default: corners-walls-center (legacy)
zones = sphynx.zones.classifySquare(arenaMask, ...
    'Strategy', 'corners-walls-center', ...
    'PixelsPerCm', 5, ...
    'WallWidthCm', 3, ...
    'CornerPoints', [50 50; 250 50; 250 150; 50 150]);
% zones(1)='corners', zones(2)='walls', zones(3)='center'

% New: N strips (feature 1.3)
zones = sphynx.zones.classifySquare(arenaMask, ...
    'Strategy', 'strips', ...
    'NumStrips', 3, ...
    'StripDirection', 'vertical');

% No partitioning
zones = sphynx.zones.classifySquare(arenaMask, 'Strategy', 'none');
```

**Bug-1 fix**: padding-based distance transform handles arenas extending to frame edges.

---

## sphynx.angles — circular math

### sphynx.angles.wrap(angles)

Wraps angles to `(-π, π]`. Vectorized. Replaces ad-hoc `mod`-based wrapping. No Mapping Toolbox dependency.

```matlab
sphynx.angles.wrap([3*pi; -3*pi; pi/4])
% [pi; pi; pi/4]
```

### sphynx.angles.unwrapForSmooth(angles, windowLen)

Unwraps a circular signal, smooths it with Savitzky-Golay (length `windowLen`), then re-wraps. **This is the Bug-2 fix** — naive `smooth` of a wrapped signal produces large artifacts at the ±π discontinuity.

```matlab
n = 200;
t = (1:n)';
raw = pi - 0.1 * (t - n/2) / (n/2);     % crosses pi smoothly
raw = sphynx.angles.wrap(raw);          % wrapped in (-pi, pi]

bad  = sgolayfilt(raw, 3, 11);          % naive smooth -> ugly jump
good = sphynx.angles.unwrapForSmooth(raw, 11);

figure; plot(t, raw, 'k-', t, bad, 'r-', t, good, 'g-');
legend('raw','naive smooth (broken)','unwrapForSmooth (Bug-2 fix)');
```

### sphynx.angles.headDirection(tipX, tipY, centerX, centerY, smoothWindow)

End-to-end head-direction angle, safely smoothed.

```matlab
% Mouse spinning 720 deg over 4 s
n = 120; t = (0:n-1)'/30;
ang = 4*pi*t/4;
tipX = cos(ang); tipY = sin(ang);
centerX = zeros(n,1); centerY = zeros(n,1);

hd = sphynx.angles.headDirection(tipX, tipY, centerX, centerY, 11);
figure; plot(t, hd); ylim([-pi pi]);
title('Head direction (-pi, pi] — smooth across the wrap');
```

---

## sphynx.preprocess — trace cleaning & smoothing

### sphynx.preprocess.smoothTrace(trace, windowLen)

Edge-aware Savitzky-Golay smoothing. **Bug-3 fix**: anti-symmetrically mirror-pads the trace before smoothing so linear trends (and constants) survive the trace edges. Uses `sgolayfilt` (no Curve Fitting Toolbox dep).

```matlab
% Constant signal stays constant at edges
x = ones(50, 1) * 5.7;
y = sphynx.preprocess.smoothTrace(x, 11);
all(abs(y - 5.7) < 1e-9)                % true

% Sine + noise
rng(42);
x = sin(linspace(0,2*pi,200))' + 0.1*randn(200,1);
y = sphynx.preprocess.smoothTrace(x, 21);
figure; plot(x,'k.'); hold on; plot(y,'r-','LineWidth',1.5); legend('raw','smoothed');
```

### sphynx.preprocess.computeVelocity(x, y, frameRate, pxlPerCm, ...)

Computes velocity from positions, with biological clipping at 50 cm/s by default. **Bug-4 fix**: per-frame outliers are NaN-replaced and interpolated *before* smoothing, so a single DLC tracking glitch doesn't poison the smoothed trace.

```matlab
% Mouse walking at 10 cm/s with a single DLC outlier at frame 100
n = 200; pxlPerCm = 5;
x = (1:n)' * pxlPerCm * 10/30;          % 10 cm/s baseline
y = ones(n,1) * 100;
x(100) = x(100) + 200 * pxlPerCm;       % 200 cm jump

v = sphynx.preprocess.computeVelocity(x, y, 30, pxlPerCm, ...
    'MaxVelocityCmS', 50, 'SmoothWindow', 11);

max(v)                                   % <= 50 (Bug-4: was 6000+ in legacy)
mean(v(20:end-20))                       % ~10 cm/s baseline preserved
```

---

## sphynx.testing — synthetic DLC fixtures (for tests)

These return self-contained structs you can feed to the new functions to verify behavior without a real video.

| Function | What it produces |
|---|---|
| `makeArenaAtFrameEdgeDLC()` | 200x300 arena that touches the frame edge — for Bug-1 |
| `makeZoneCrossDLC()` | 120-frame trajectory crossing corner -> wall -> center -> wall -> corner |
| `makeRotatingMouseDLC(deg, durS)` | mouse rotating uniformly through `deg` degrees in `durS` seconds — for Bug-2 |
| `makeWalkingDLC(speedCmS, durS)` | mouse walking in a straight line at `speedCmS` |
| `makeJumpyDLC(spikeFrame, spikePxl)` | walking trace + one DLC outlier — for Bug-4 |

Example:

```matlab
f = sphynx.testing.makeRotatingMouseDLC(720, 4);
hd = sphynx.angles.headDirection(f.headTipX, f.headTipY, ...
                                  f.headCenterX, f.headCenterY, 11);
figure; plot(hd);
```

---

## Things you can run hands-on right now

### A. Visualize the Bug-1 zone fix

Compare on a pathological arena that touches the frame edge:

```matlab
f = sphynx.testing.makeArenaAtFrameEdgeDLC();
zones = sphynx.zones.classifySquare(f.arenaMask, ...
    'Strategy','corners-walls-center', ...
    'PixelsPerCm', f.pxlPerCm, ...
    'WallWidthCm', 3, ...
    'CornerPoints', f.cornerPoints);

figure;
subplot(1,3,1); imshow(zones(1).maskfilled); title('corners (was empty in legacy)');
subplot(1,3,2); imshow(zones(2).maskfilled); title('walls');
subplot(1,3,3); imshow(zones(3).maskfilled); title('center');
```

### B. Visualize the Bug-2 angle fix

```matlab
f = sphynx.testing.makeRotatingMouseDLC(720, 4);
hdNew = sphynx.angles.headDirection(f.headTipX, f.headTipY, ...
                                      f.headCenterX, f.headCenterY, 11);

% Compare with naive: just atan2 + sgolayfilt of the wrapped signal
raw = atan2(f.headTipY, f.headTipX);
hdNaive = sgolayfilt(raw, 3, 11);

figure;
plot((1:numel(hdNew))/f.frameRate, hdNew, 'g-', 'LineWidth', 1.5); hold on;
plot((1:numel(hdNaive))/f.frameRate, hdNaive, 'r--');
legend('unwrapForSmooth (Bug-2 fix)','naive sgolayfilt (broken at +-pi)');
ylim([-pi pi]); xlabel('s'); ylabel('rad');
title('Head direction during 720 deg sweep');
```

### C. Visualize the Bug-4 velocity clipping

```matlab
f = sphynx.testing.makeJumpyDLC(100, 1000);   % 200 cm jump in 1 frame
v = sphynx.preprocess.computeVelocity(f.x, f.y, f.frameRate, f.pxlPerCm, ...
    'MaxVelocityCmS', 50, 'SmoothWindow', 11);

% Naive: same diffs without clipping, just smoothed
dx = [0; diff(f.x)]; dy = [0; diff(f.y)];
vNaive = sgolayfilt(sqrt(dx.^2+dy.^2)*f.frameRate/f.pxlPerCm, 3, 11);

figure;
plot(vNaive, 'r-'); hold on;
plot(v, 'g-', 'LineWidth', 1.5);
legend('naive smoothed velocity','computeVelocity (Bug-4 fix)');
xlabel('frame'); ylabel('cm/s');
title('Bug-4: a single DLC outlier no longer poisons the trace');
```

### D. Round-arena ring partitioning at different sizes

```matlab
for R = [15 25 30 50 80]
    pxlPerCm = 2;
    H = 4*R*pxlPerCm + 50; W = H;
    [X, Y] = meshgrid(1:W, 1:H);
    cx = round(W/2); cy = round(H/2);
    arenaMask = (X-cx).^2 + (Y-cy).^2 <= (R*pxlPerCm)^2;
    zones = sphynx.zones.classifyCircle(arenaMask, ...
        'PixelsPerCm', pxlPerCm, 'WallWidthCm', 10, 'MiddleWidthCm', 20);
    fprintf('R=%d cm -> zones: %s\n', R, strjoin({zones.name}, ', '));
end

% R=15 cm -> zones: wall
% R=25 cm -> zones: wall, center
% R=30 cm -> zones: wall, center
% R=50 cm -> zones: wall, middle1, center
% R=80 cm -> zones: wall, middle1, middle2, middle3, center
```

### E. Run the full test suite

```matlab
runAllTests('tag','fast')                % unit + synthetic + smoke (~3 sec)
runAllTests('tag','golden')              % regression against NOF_H01_1D snapshot (Pass B uses this)
```

---

## What is NOT yet done

The new code is currently **building blocks**. The full pipeline (`sphynx.pipeline.analyzeSession`) doesn't exist yet — that's Pass B (slices 4-6). Until then, you can only call the individual functions above. The legacy `BehaviorAnalyzer.m` is unchanged and still works as before.

Roadmap:

| Pass | Coverage |
|---|---|
| **B** | bodyparts, acts, full pipeline (`analyzeSession`), golden regression |
| **C** | aggregation (SuperTable refactor), CreatePreset decomposition |
| **D** | App Designer GUI for CreatePreset |
| **E** | Preprocess subproject cleanup |

After Pass B, `sphynx.pipeline.analyzeSession(config)` becomes the new entry point and the smoke test will actually run end-to-end on `Demo/NOF_H01_1D`.

---

## Tags so far

| Tag | What's in it |
|---|---|
| `stage-c-pass-0-complete` | branch + test infrastructure + golden snapshot |
| `stage-c-pass-A1-zones-fixed` | Bug-1 + zone partitioning feature 1.3 |
| `stage-c-pass-A2-angles-fixed` | Bug-2 |
| `stage-c-pass-A3-velocity-fixed` | Bug-3 + Bug-4 |
| `stage-c-pass-A-bugs-fixed` | end of Pass A (alias of A3) |

To see a specific milestone:
```bash
git log stage-c-pass-A2-angles-fixed --oneline
git diff stage-c-pass-0-complete..stage-c-pass-A-bugs-fixed --stat
```
