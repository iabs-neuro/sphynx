# Sphynx Stage C — Implementation Plan: Pass 0 + Pass A

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Set up test infrastructure on a new branch, then ship fixes for the four known bugs (zone-at-edge, angle wrap, edge smoothing, velocity outliers) with comprehensive tests covering each fix.

**Architecture:** New code in MATLAB package `+sphynx/`, self-contained, no calls to legacy `functions/*.m`. Tests in `tests/+{unit,synthetic,golden,smoke}/`. Old code at root (`BehaviorAnalyzer.m`, `CreatePreset.m`, `Projects/`, `Cross-analysis/`, `functions/`, `tools/`, `Preprocess/`) stays untouched on this branch.

**Tech Stack:** MATLAB R2020a, `matlab.unittest` (functional syntax), MATLAB packages.

**Spec:** [`docs/superpowers/specs/2026-04-27-sphynx-stage-c-design.md`](../specs/2026-04-27-sphynx-stage-c-design.md)

**Branch:** `sphynx-GUI` (created in Task 0.1)

**Execution context:** Claude has no MATLAB execution access. Each test step lists the **exact MATLAB command** for the user to run; the user reports outcome.

---

## What this plan covers

- **Pass 0** — Branch + `+sphynx/` skeleton + test infrastructure + golden snapshot for `NOF_H01_1D` from existing `Demo/Behavior/` workspaces.
- **Pass A.1** — Slice 1: zones (Bug-1 fix + zone partitioning feature 1.3).
- **Pass A.2** — Slice 2: angles (Bug-2 fix).
- **Pass A.3** — Slice 3: velocity & smoothing (Bug-3 + Bug-4 fixes).

After Pass A is green, a separate plan will be written for **Pass B** (slices 4–6: body parts, acts, pipeline integration with golden baseline).

---

## File structure (cumulative after Pass A)

```
+sphynx/
├── +util/
│   ├── log.m                              Pass 0
│   ├── progress.m                         Pass 0
│   ├── repoRoot.m                         Pass 0
│   ├── inMaskSafe.m                       Pass A.1
│   ├── circleFit.m                        Pass A.1
│   └── polygonFit.m                       Pass A.1
├── +zones/
│   ├── classifySquare.m                   Pass A.1
│   ├── classifyCircle.m                   Pass A.1
│   └── partitionStrips.m                  Pass A.1
├── +angles/
│   ├── wrap.m                             Pass A.2
│   ├── unwrapForSmooth.m                  Pass A.2
│   └── headDirection.m                    Pass A.2
├── +preprocess/
│   ├── smoothTrace.m                      Pass A.3
│   └── computeVelocity.m                  Pass A.3
└── +testing/
    ├── makeArenaAtFrameEdgeDLC.m          Pass A.1
    ├── makeZoneCrossDLC.m                 Pass A.1
    ├── makeRotatingMouseDLC.m             Pass A.2
    ├── makeJumpyDLC.m                     Pass A.3
    └── makeWalkingDLC.m                   Pass A.3

tests/
├── runAllTests.m                          Pass 0
├── +unit/
│   ├── sanityTest.m                       Pass 0
│   ├── logTest.m                          Pass 0
│   ├── inMaskSafeTest.m                   Pass A.1
│   ├── circleFitTest.m                    Pass A.1
│   ├── polygonFitTest.m                   Pass A.1
│   ├── classifySquareTest.m               Pass A.1
│   ├── classifyCircleTest.m               Pass A.1
│   ├── partitionStripsTest.m              Pass A.1
│   ├── wrapTest.m                         Pass A.2
│   ├── unwrapForSmoothTest.m              Pass A.2
│   ├── smoothTraceTest.m                  Pass A.3
│   └── computeVelocityTest.m              Pass A.3
├── +synthetic/
│   ├── zoneVisitTest.m                    Pass A.1
│   ├── headDirectionContinuityTest.m      Pass A.2
│   ├── velocityClippingTest.m             Pass A.3
│   └── edgeSmoothingTest.m                Pass A.3
├── +golden/
│   ├── buildSnapshots.m                   Pass 0
│   └── snapshots/
│       └── NOF_H01_1D_Acts.mat            Pass 0 (built locally, committed)
└── +smoke/
    └── demoPipelineTest.m                 Pass 0 (placeholder; real pipeline test in Pass B)
```

---

## MATLAB conventions used in this plan

- All file paths are **forward slashes** in MATLAB code, except where Windows-specific (none expected).
- All test commands are run from MATLAB Command Window with the repository root as the current folder. `startup.m` runs once per MATLAB session and adds the repo to path; if user starts MATLAB freshly, run `startup` first.
- Tests use **functional unit-test syntax** (`function tests = nameTest; tests = functiontests(localfunctions); end`).
- Each test file is self-contained — no shared fixtures across files.
- Each commit uses a HEREDOC for multi-line messages with the `Co-Authored-By` trailer.

---

# Pass 0 — Test infrastructure

**Goal of Pass 0:** A green `runAllTests('tag','fast')` that runs a sanity test, a frozen golden snapshot of legacy `NOF_H01_1D`, the new branch checked out, and a homework packet for the user.

---

## Task 0.1 — Create branch

**Files:** none (git only)

- [ ] **Step 1: Confirm clean working tree (informational)**

Shell:
```bash
git status
```

Expected: pre-existing uncommitted items shown (`Cross-analysis/Commander_DEV.m`, `Projects/BehaviorAnalyzerDEV.m`, `.idea/`, `Demo/...`, `CreatePreset.m`). These are user's WIP — leave them as-is.

- [ ] **Step 2: Create branch from current master state**

Shell:
```bash
git checkout -b sphynx-GUI
```

Expected: `Switched to a new branch 'sphynx-GUI'`

- [ ] **Step 3: Verify**

Shell:
```bash
git branch --show-current
```

Expected: `sphynx-GUI`

---

## Task 0.2 — `+sphynx/+util/repoRoot.m` (helper for tests and snapshots)

**Files:**
- Create: `+sphynx/+util/repoRoot.m`

- [ ] **Step 1: Implement**

Create `+sphynx/+util/repoRoot.m`:

```matlab
function root = repoRoot()
% REPOROOT  Absolute path to the sphynx repository root.
%
%   root = sphynx.util.repoRoot() returns the absolute path of the
%   repository root, derived from the location of this file.
%
%   This is used by tests, snapshot builders, and the golden test
%   loader to locate fixture data without depending on the current
%   working directory.

    here = fileparts(mfilename('fullpath'));
    % here == <repo>/+sphynx/+util ; go up two levels
    root = fileparts(fileparts(here));
end
```

- [ ] **Step 2: Smoke-check from MATLAB Command Window**

Run:
```matlab
sphynx.util.repoRoot()
```

Expected: prints absolute path ending in `\sphynx` (the repo root, NOT the `+sphynx` folder).

- [ ] **Step 3: Commit**

Shell:
```bash
git add "+sphynx/+util/repoRoot.m"
git commit -m "$(cat <<'EOF'
infra: add sphynx.util.repoRoot helper

Returns the absolute path to the repository root. Used by tests
and snapshot builders so they work regardless of the current
working directory.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 0.3 — `+sphynx/+util/log.m` (verbose logger)

**Files:**
- Create: `+sphynx/+util/log.m`
- Test:   `tests/+unit/logTest.m`

- [ ] **Step 1: Write the test**

Create `tests/+unit/logTest.m`:

```matlab
function tests = logTest
    tests = functiontests(localfunctions);
end

function testInfoEmitsAtInfoLevel(testCase)
    out = evalc('sphynx.util.log(''info'', ''hello %s'', ''world'');');
    verifyTrue(testCase, contains(out, 'hello world'));
    verifyTrue(testCase, contains(out, 'INFO'));
end

function testDebugSilentByDefault(testCase)
    out = evalc('sphynx.util.log(''debug'', ''secret'');');
    verifyEqual(testCase, out, '');
end

function testDebugEmitsWhenEnabled(testCase)
    setenv('SPHYNX_LOG_LEVEL', 'debug');
    cleaner = onCleanup(@() setenv('SPHYNX_LOG_LEVEL', ''));
    out = evalc('sphynx.util.log(''debug'', ''secret'');');
    verifyTrue(testCase, contains(out, 'secret'));
    verifyTrue(testCase, contains(out, 'DEBUG'));
end

function testWarnAlwaysEmits(testCase)
    out = evalc('sphynx.util.log(''warn'', ''attention'');');
    verifyTrue(testCase, contains(out, 'attention'));
    verifyTrue(testCase, contains(out, 'WARN'));
end

function testUnknownLevelErrors(testCase)
    verifyError(testCase, @() sphynx.util.log('shout', 'x'), ...
        'sphynx:log:unknownLevel');
end
```

- [ ] **Step 2: Run test to verify it fails**

Run in MATLAB Command Window:
```matlab
runtests('tests/+unit/logTest.m')
```

Expected: 5 tests, all FAIL with "Unrecognized function or variable 'sphynx.util.log'".

- [ ] **Step 3: Implement**

Create `+sphynx/+util/log.m`:

```matlab
function log(level, fmt, varargin)
% LOG  Verbose-aware logger for sphynx.
%
%   sphynx.util.log(LEVEL, FMT, ARGS...) prints a formatted message
%   to stdout, prefixed with the upper-cased LEVEL, when LEVEL meets
%   the current threshold.
%
%   Levels (low to high): 'debug', 'info', 'warn', 'error'.
%   Default threshold is 'info' (debug is silent).
%   Override threshold via env var SPHYNX_LOG_LEVEL.
%
%   Examples:
%     sphynx.util.log('info', 'Loaded %d frames', n);
%     sphynx.util.log('warn', 'BodyPart %s missing', name);

    levels = {'debug', 'info', 'warn', 'error'};
    levelIdx = find(strcmp(level, levels), 1);
    if isempty(levelIdx)
        error('sphynx:log:unknownLevel', ...
            'Unknown log level "%s"; valid: debug|info|warn|error', level);
    end

    threshold = getenv('SPHYNX_LOG_LEVEL');
    if isempty(threshold)
        threshold = 'info';
    end
    thresholdIdx = find(strcmp(threshold, levels), 1);
    if isempty(thresholdIdx)
        thresholdIdx = 2; % info
    end

    if levelIdx < thresholdIdx
        return;
    end

    msg = sprintf(fmt, varargin{:});
    fprintf('[%s] %s\n', upper(level), msg);
end
```

- [ ] **Step 4: Run test to verify it passes**

```matlab
runtests('tests/+unit/logTest.m')
```

Expected: 5 PASSED, 0 FAILED.

- [ ] **Step 5: Commit**

```bash
git add "+sphynx/+util/log.m" tests/+unit/logTest.m
git commit -m "$(cat <<'EOF'
infra: add sphynx.util.log with level threshold

Verbose-aware logger with debug/info/warn/error levels. Default
threshold is info; debug silenced unless SPHYNX_LOG_LEVEL=debug.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 0.4 — `+sphynx/+util/progress.m` (waitbar wrapper)

**Files:**
- Create: `+sphynx/+util/progress.m`

(No unit test — wrapping `waitbar` is hard to test without GUI; covered indirectly by smoke test later.)

- [ ] **Step 1: Implement**

Create `+sphynx/+util/progress.m`:

```matlab
function h = progress(action, varargin)
% PROGRESS  Waitbar wrapper that no-ops in headless/test mode.
%
%   h = sphynx.util.progress('open', total, msg)
%   sphynx.util.progress('update', h, current, msg)
%   sphynx.util.progress('close', h)
%
%   When env var SPHYNX_HEADLESS=1, all calls are no-ops and 'open'
%   returns []. This is what tests and batch jobs set so they don't
%   spawn waitbar windows.

    headless = strcmp(getenv('SPHYNX_HEADLESS'), '1');

    switch action
        case 'open'
            total = varargin{1};
            msg = varargin{2};
            if headless || total <= 0
                h = [];
                return;
            end
            h = waitbar(0, sprintf('%s (0/%d)', msg, total));

        case 'update'
            h = varargin{1};
            current = varargin{2};
            msg = varargin{3};
            if isempty(h) || ~isvalid(h)
                return;
            end
            % Use the third arg of waitbar to update message
            % We need total to compute the fraction; recover from waitbar's stored value.
            ud = get(h, 'UserData');
            if isempty(ud)
                ud = struct('total', max(current, 1));
                set(h, 'UserData', ud);
            end
            waitbar(min(current / ud.total, 1), h, sprintf('%s (%d/%d)', msg, current, ud.total));

        case 'close'
            h = varargin{1};
            if ~isempty(h) && isvalid(h)
                close(h);
            end

        otherwise
            error('sphynx:progress:unknownAction', ...
                'Unknown action "%s"; valid: open|update|close', action);
    end
end
```

(Note: `progress` accepts `total` on `open`; pass it again on `update` calls if needed via UserData. The above is a simplified wrapper; we'll iterate if it proves insufficient in real use.)

- [ ] **Step 2: Smoke-check headless**

```matlab
setenv('SPHYNX_HEADLESS', '1');
h = sphynx.util.progress('open', 100, 'test');
sphynx.util.progress('update', h, 50, 'halfway');
sphynx.util.progress('close', h);
setenv('SPHYNX_HEADLESS', '');
```

Expected: no errors, no windows opened.

- [ ] **Step 3: Commit**

```bash
git add "+sphynx/+util/progress.m"
git commit -m "$(cat <<'EOF'
infra: add sphynx.util.progress waitbar wrapper

No-ops when SPHYNX_HEADLESS=1, so tests and batch jobs don't
spawn waitbar windows.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 0.5 — `tests/runAllTests.m` (entry point)

**Files:**
- Create: `tests/runAllTests.m`
- Create: `tests/+unit/sanityTest.m` (sanity test so runAllTests has something to find)

- [ ] **Step 1: Write the sanity test**

Create `tests/+unit/sanityTest.m`:

```matlab
function tests = sanityTest
    tests = functiontests(localfunctions);
end

function testFrameworkLoaded(testCase)
    verifyTrue(testCase, true, 'matlab.unittest is working');
end

function testRepoRootResolves(testCase)
    root = sphynx.util.repoRoot();
    verifyTrue(testCase, isfolder(root));
    verifyTrue(testCase, isfile(fullfile(root, 'README.md')));
end
```

- [ ] **Step 2: Implement runAllTests**

Create `tests/runAllTests.m`:

```matlab
function results = runAllTests(varargin)
% RUNALLTESTS  Run the sphynx test suite.
%
%   results = runAllTests()                runs everything (== 'all')
%   results = runAllTests('tag','fast')    runs unit + synthetic + smoke
%   results = runAllTests('tag','full')    runs unit + synthetic + smoke + golden
%   results = runAllTests('tag','golden')  runs golden only
%
%   Sets SPHYNX_HEADLESS=1 for the duration so tests don't open windows.
%
%   Run from MATLAB Command Window with the repo root as cwd:
%     >> startup
%     >> cd tests
%     >> runAllTests('tag','fast')

    p = inputParser;
    addParameter(p, 'tag', 'all', @ischar);
    parse(p, varargin{:});
    tag = p.Results.tag;

    here = fileparts(mfilename('fullpath')); % /<repo>/tests

    switch tag
        case 'fast'
            buckets = {'+unit', '+synthetic', '+smoke'};
        case 'full'
            buckets = {'+unit', '+synthetic', '+smoke', '+golden'};
        case 'golden'
            buckets = {'+golden'};
        case 'all'
            buckets = {'+unit', '+synthetic', '+smoke', '+golden'};
        otherwise
            error('runAllTests:unknownTag', ...
                'Unknown tag "%s"; valid: fast|full|golden|all', tag);
    end

    % Force headless so no windows pop up
    prevHeadless = getenv('SPHYNX_HEADLESS');
    setenv('SPHYNX_HEADLESS', '1');
    cleaner = onCleanup(@() setenv('SPHYNX_HEADLESS', prevHeadless));

    import matlab.unittest.TestSuite;
    suite = TestSuite.empty(0,1);
    for i = 1:numel(buckets)
        bucketDir = fullfile(here, buckets{i});
        if isfolder(bucketDir)
            sub = TestSuite.fromFolder(bucketDir, 'IncludingSubfolders', true);
            suite = [suite, sub]; %#ok<AGROW>
        end
    end

    if isempty(suite)
        warning('runAllTests:emptySuite', ...
            'No tests found for tag "%s" in %s', tag, here);
        results = matlab.unittest.TestResult.empty;
        return;
    end

    fprintf('Running %d tests (tag=%s)\n', numel(suite), tag);
    results = run(suite);

    % Print summary
    nFailed = sum([results.Failed]);
    nIncomplete = sum([results.Incomplete]);
    fprintf('\n=== Summary ===\nTotal:   %d\nPassed:  %d\nFailed:  %d\nSkipped: %d\n', ...
        numel(results), sum([results.Passed]), nFailed, nIncomplete);

    if nFailed > 0 || nIncomplete > 0
        warning('runAllTests:someFailed', '%d failed, %d incomplete', nFailed, nIncomplete);
    end
end
```

- [ ] **Step 3: Run from MATLAB**

```matlab
startup           % only if not already run this MATLAB session
cd(sphynx.util.repoRoot())
runtests('tests/+unit/sanityTest.m')
```

Expected: 2 tests PASSED.

- [ ] **Step 4: Run runAllTests entry**

```matlab
results = runAllTests('tag','fast');
```

Expected: 2 tests PASSED (only sanityTest exists right now); `results` is a TestResult array of size 2.

- [ ] **Step 5: Commit**

```bash
git add tests/runAllTests.m tests/+unit/sanityTest.m
git commit -m "$(cat <<'EOF'
test: add runAllTests entry and sanity test

runAllTests('tag','fast'|'full'|'golden'|'all') discovers tests
under tests/+unit, +synthetic, +smoke, +golden and runs them
with SPHYNX_HEADLESS=1 so no windows open.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 0.6 — `tests/+golden/buildSnapshots.m` and snapshot for NOF_H01_1D

**Files:**
- Create: `tests/+golden/buildSnapshots.m`
- Create: `tests/+golden/snapshots/NOF_H01_1D_Acts.mat` (built locally, committed as binary)

- [ ] **Step 1: Implement buildSnapshots**

Create `tests/+golden/buildSnapshots.m`:

```matlab
function buildSnapshots(varargin)
% BUILDSNAPSHOTS  One-shot: read existing legacy WorkSpace.mat files
%   from Demo/Behavior/ and write golden snapshots for regression tests.
%
%   buildSnapshots()                       builds snapshot for NOF_H01_1D
%   buildSnapshots('sessions', {...})      builds for given list
%
%   Output: tests/+golden/snapshots/<session>_Acts.mat
%
%   The snapshot stores ONLY numeric Acts fields and a few body-parts
%   aggregates — no per-frame time series. ~1-3 KB per session.
%
%   Run from MATLAB:
%     >> tests.golden.buildSnapshots
%   (or)
%     >> run('tests/+golden/buildSnapshots.m')

    p = inputParser;
    addParameter(p, 'sessions', {'NOF_H01_1D'}, @iscell);
    parse(p, varargin{:});

    repo = sphynx.util.repoRoot();
    snapDir = fullfile(repo, 'tests', '+golden', 'snapshots');
    if ~isfolder(snapDir)
        mkdir(snapDir);
    end

    for i = 1:numel(p.Results.sessions)
        session = p.Results.sessions{i};
        wsPath = locateLegacyWorkspace(repo, session);
        sphynx.util.log('info', 'Reading %s', wsPath);

        L = load(wsPath, 'Acts', 'BodyPartsTraces', 'Point', 'Options', 'n_frames');

        snap = struct();
        snap.Acts = stripActsForSnapshot(L.Acts);
        snap.BodyPartsAggregates = bodyPartsAggregates(L.BodyPartsTraces, L.Point);
        snap.meta.legacySource = strrep(wsPath, repo, '<repo>');
        snap.meta.snapshotDate = char(datetime('now'));
        snap.meta.n_frames = L.n_frames;
        snap.meta.FrameRate = L.Options.FrameRate;
        snap.meta.legacyGitSha = currentGitSha(repo);

        outPath = fullfile(snapDir, sprintf('%s_Acts.mat', session));
        save(outPath, '-struct', 'snap');
        sphynx.util.log('info', 'Wrote %s (%.1f KB)', outPath, dirSizeKB(outPath));
    end
end

function wsPath = locateLegacyWorkspace(repo, session)
    baseDir = fullfile(repo, 'Demo', 'Behavior', session);
    if ~isfolder(baseDir)
        error('buildSnapshots:noBehaviorDir', ...
            'No Demo/Behavior dir for session "%s" at %s', session, baseDir);
    end
    d = dir(baseDir);
    d = d([d.isdir] & ~ismember({d.name}, {'.', '..'}));
    if isempty(d)
        error('buildSnapshots:noLegacyRun', ...
            'No legacy run subfolder under %s', baseDir);
    end
    [~, idx] = max([d.datenum]); % most recent
    wsPath = fullfile(d(idx).folder, d(idx).name, sprintf('%s_WorkSpace.mat', session));
    if ~isfile(wsPath)
        error('buildSnapshots:noWorkspaceMat', ...
            'No %s_WorkSpace.mat at %s', session, wsPath);
    end
end

function out = stripActsForSnapshot(Acts)
    keepFields = {'ActName','ActPercent','ActNumber','ActMeanTime', ...
                  'ActMedianTime','Distance','ActDuration','ActVelocity'};
    out = struct();
    for k = 1:numel(keepFields)
        out.(keepFields{k}) = cell(1, numel(Acts));
    end
    for i = 1:numel(Acts)
        for k = 1:numel(keepFields)
            f = keepFields{k};
            if isfield(Acts, f) && ~isempty(Acts(i).(f))
                out.(f){i} = Acts(i).(f);
            else
                out.(f){i} = [];
            end
        end
    end
end

function agg = bodyPartsAggregates(BodyPartsTraces, Point)
    agg = struct();
    parts = struct('Tailbase', Point.Tailbase, 'Center', Point.Center);
    fns = fieldnames(parts);
    for i = 1:numel(fns)
        idx = parts.(fns{i});
        if ~isempty(idx) && idx >= 1 && idx <= numel(BodyPartsTraces)
            t = BodyPartsTraces(idx);
            agg.(fns{i}).AverageDistance = getOrEmpty(t, 'AverageDistance');
            agg.(fns{i}).AverageSpeed    = getOrEmpty(t, 'AverageSpeed');
        else
            agg.(fns{i}).AverageDistance = NaN;
            agg.(fns{i}).AverageSpeed    = NaN;
        end
    end
end

function v = getOrEmpty(s, f)
    if isfield(s, f) && ~isempty(s.(f))
        v = s.(f);
    else
        v = NaN;
    end
end

function sha = currentGitSha(repo)
    [status, out] = system(sprintf('git -C "%s" rev-parse HEAD', repo));
    if status == 0
        sha = strtrim(out);
    else
        sha = '<unknown>';
    end
end

function kb = dirSizeKB(path)
    d = dir(path);
    if isempty(d)
        kb = NaN;
    else
        kb = d(1).bytes / 1024;
    end
end
```

- [ ] **Step 2: Run buildSnapshots from MATLAB**

```matlab
run(fullfile(sphynx.util.repoRoot(), 'tests', '+golden', 'buildSnapshots.m'))
```

Expected console output:
```
[INFO] Reading <repo>/Demo/Behavior/NOF_H01_1D/22-Jan-2026_1/NOF_H01_1D_WorkSpace.mat
[INFO] Wrote <repo>/tests/+golden/snapshots/NOF_H01_1D_Acts.mat (1.x KB)
```

- [ ] **Step 3: Inspect the snapshot**

```matlab
snap = load(fullfile(sphynx.util.repoRoot(), 'tests', '+golden', 'snapshots', 'NOF_H01_1D_Acts.mat'));
disp(snap.meta);
fprintf('Acts: %d entries\n', numel(snap.Acts.ActName));
disp(snap.Acts.ActName);
```

Expected: prints meta struct (snapshotDate, n_frames, FrameRate, legacyGitSha), and a list of act names like `'rest','walk','locomotion','freezing','rear','corners','walls','center', ...`.

- [ ] **Step 4: Commit (script + snapshot binary)**

```bash
git add tests/+golden/buildSnapshots.m "tests/+golden/snapshots/NOF_H01_1D_Acts.mat"
git commit -m "$(cat <<'EOF'
test: golden snapshot builder + NOF_H01_1D baseline

buildSnapshots reads legacy WorkSpace.mat from Demo/Behavior/
and writes a numeric-only snapshot (~few KB) for regression
tests. NOF_H01_1D snapshot committed as initial baseline.

Other Demo sessions (2D, 3D, 4D) added in a later pass per
sprint-mode reduced golden scope.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 0.7 — `tests/+smoke/demoPipelineTest.m` (placeholder)

**Files:**
- Create: `tests/+smoke/demoPipelineTest.m`

- [ ] **Step 1: Implement placeholder**

Create `tests/+smoke/demoPipelineTest.m`:

```matlab
function tests = demoPipelineTest
% DEMOPIPELINETEST  End-to-end smoke test on Demo/NOF_H01_1D.
%
% PASS 0 STATE: placeholder that always passes. The real test
% body is filled in during Pass B (slice 6) after analyzeSession exists.
    tests = functiontests(localfunctions);
end

function testNOF_H01_1D_runsWithoutError(testCase)
    % TODO(pass-B): replace with actual call:
    %   config = sphynx.pipeline.defaultConfig();
    %   config.paths.video = fullfile(sphynx.util.repoRoot(), 'Demo','Video','NOF_H01_1D.mp4');
    %   config.paths.dlc = fullfile(sphynx.util.repoRoot(), 'Demo','DLC','NOF_H01_1D...');
    %   config.paths.preset = fullfile(sphynx.util.repoRoot(), 'Demo','Preset','NOF_H01_1D_Preset.mat');
    %   config.viz.headless = true;
    %   config.viz.makeVideo = false;
    %   result = sphynx.pipeline.analyzeSession(config);
    %   verifyTrue(testCase, isstruct(result));
    %   verifyTrue(testCase, isfield(result, 'Acts'));
    assumeFail(testCase, 'pass-0 placeholder; real test arrives in Pass B');
end
```

(This uses `assumeFail` to mark the test as filtered/skipped, not failed. In `matlab.unittest`, `assumeFail` causes the test result to be Incomplete but does not fail the suite. The runAllTests summary will show it as skipped, which is correct: the test is intentionally deferred.)

- [ ] **Step 2: Verify behavior**

```matlab
runtests('tests/+smoke/demoPipelineTest.m')
```

Expected: 1 test, status "Incomplete" with reason "pass-0 placeholder; real test arrives in Pass B". Suite is not failed.

- [ ] **Step 3: Commit**

```bash
git add tests/+smoke/demoPipelineTest.m
git commit -m "$(cat <<'EOF'
test: placeholder smoke test for NOF_H01_1D end-to-end

Will be replaced in Pass B once analyzeSession exists.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 0.8 — README addendum on running tests

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Read current README**

```bash
cat README.md
```

Expected (current content):
```
# sphynx
SPHYNX - Segmented PHYsical aNalysis of eXploration

Download this videos in folder Demo/Video for demo analysis:
https://disk.yandex.ru/i/8ULS0Vg3Q27tPQ
https://disk.yandex.ru/i/s45V4KR61tt6HA

Documentation is under development, please write to Viktor Plusnin for any questions witkax@mail.ru
```

- [ ] **Step 2: Append testing section**

Use Edit tool to add at end of `README.md`:

Append the following (after a blank line):

```markdown

## Running tests (sphynx-GUI branch)

From MATLAB Command Window, with the repo root as the current folder:

```matlab
startup                            % once per MATLAB session, adds paths
runAllTests('tag','fast')          % unit + synthetic + smoke (~30 sec)
runAllTests('tag','full')          % adds golden regression (~9 min)
runAllTests('tag','golden')        % golden only
```

To rebuild the golden snapshot (after a known intentional change):

```matlab
run(fullfile(sphynx.util.repoRoot(),'tests','+golden','buildSnapshots.m'))
```

Tests run with `SPHYNX_HEADLESS=1` set automatically — no figures or videos
are written by tests.
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
docs: add testing section to README

Documents runAllTests entry point and how to rebuild golden
snapshots.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 0.9 — Pass 0 final check + tag

- [ ] **Step 1: Run full fast suite**

```matlab
runAllTests('tag','fast')
```

Expected console:
```
Running 8 tests (tag=fast)
...
=== Summary ===
Total:   8
Passed:  7
Failed:  0
Skipped: 1   <- the smoke placeholder
```

(7 = sanityTest×2 + logTest×5; 1 skipped = demoPipelineTest placeholder.)

- [ ] **Step 2: Tag Pass 0 complete**

```bash
git tag stage-c-pass-0-complete
git log --oneline -10
```

Expected: tag is on the latest commit; log shows recent Pass 0 commits.

- [ ] **Step 3: Homework packet for user**

User reports back to Claude:
- Output of `runAllTests('tag','fast')` summary
- Any unexpected MATLAB errors or warnings
- Confirmation that no windows opened

Once confirmed, Pass A starts.

---

# Pass A.1 — Slice 1: Zones (Bug-1 + zone partitioning feature 1.3)

**Goal of Pass A.1:** A working `sphynx.zones.classifySquare` and `classifyCircle` that correctly handle the case when arena geometry touches the frame border (Bug-1), and support new partitioning options (strips for square, rings for circle).

---

## Task A.1.1 — `sphynx.util.circleFit`

**Files:**
- Create: `+sphynx/+util/circleFit.m`
- Test:   `tests/+unit/circleFitTest.m`

- [ ] **Step 1: Read legacy `functions/circfit.m`**

```bash
cat functions/circfit.m
```

This is the source of behavior to preserve. Note the algorithm: linear least-squares fit of `[x, y, ones] * [a; b; c] = -(x.^2 + y.^2)`, giving center `(xc, yc) = (-a/2, -b/2)` and radius `R = sqrt((a^2 + b^2)/4 - c)`.

- [ ] **Step 2: Write the test**

Create `tests/+unit/circleFitTest.m`:

```matlab
function tests = circleFitTest
    tests = functiontests(localfunctions);
end

function testFitsKnownUnitCircle(testCase)
    % 100 points on unit circle centered at (0, 0)
    th = linspace(0, 2*pi, 100)';
    x = cos(th); y = sin(th);
    [xc, yc, r] = sphynx.util.circleFit(x, y);
    verifyEqual(testCase, xc, 0, 'AbsTol', 1e-9);
    verifyEqual(testCase, yc, 0, 'AbsTol', 1e-9);
    verifyEqual(testCase, r, 1, 'AbsTol', 1e-9);
end

function testFitsOffsetCircle(testCase)
    th = linspace(0, 2*pi, 50)';
    x = 5 + 3*cos(th); y = -7 + 3*sin(th);
    [xc, yc, r] = sphynx.util.circleFit(x, y);
    verifyEqual(testCase, xc, 5, 'AbsTol', 1e-9);
    verifyEqual(testCase, yc, -7, 'AbsTol', 1e-9);
    verifyEqual(testCase, r, 3, 'AbsTol', 1e-9);
end

function testFitsThreeNonCollinearPoints(testCase)
    % 3 points on unit circle at 0, 120, 240 deg
    th = [0; 2*pi/3; 4*pi/3];
    x = cos(th); y = sin(th);
    [xc, yc, r] = sphynx.util.circleFit(x, y);
    verifyEqual(testCase, xc, 0, 'AbsTol', 1e-9);
    verifyEqual(testCase, yc, 0, 'AbsTol', 1e-9);
    verifyEqual(testCase, r, 1, 'AbsTol', 1e-9);
end

function testRejectsTooFewPoints(testCase)
    verifyError(testCase, @() sphynx.util.circleFit([0;1],[0;0]), ...
        'sphynx:circleFit:tooFewPoints');
end

function testRejectsCollinearPoints(testCase)
    verifyError(testCase, @() sphynx.util.circleFit([0;1;2;3],[0;0;0;0]), ...
        'sphynx:circleFit:degenerate');
end
```

- [ ] **Step 3: Run test to verify it fails**

```matlab
runtests('tests/+unit/circleFitTest.m')
```

Expected: 5 FAILED with "Unrecognized function 'sphynx.util.circleFit'".

- [ ] **Step 4: Implement**

Create `+sphynx/+util/circleFit.m`:

```matlab
function [xc, yc, r] = circleFit(x, y)
% CIRCLEFIT  Least-squares circle fit through given (x, y) points.
%
%   [xc, yc, r] = sphynx.util.circleFit(x, y) returns the center
%   (xc, yc) and radius r of the best-fit circle.
%
%   Algorithm: linear LS solve of (x^2 + y^2) + a*x + b*y + c = 0
%   then xc = -a/2, yc = -b/2, r = sqrt((a^2+b^2)/4 - c).
%
%   Errors:
%     sphynx:circleFit:tooFewPoints  if numel(x) < 3
%     sphynx:circleFit:degenerate    if points are collinear (singular A)
%
%   Replacement for legacy functions/circfit.m, with explicit error
%   on degenerate input (legacy returned NaN silently).

    x = x(:); y = y(:);
    if numel(x) ~= numel(y)
        error('sphynx:circleFit:sizeMismatch', 'x and y must have the same length');
    end
    if numel(x) < 3
        error('sphynx:circleFit:tooFewPoints', ...
            'Need at least 3 points; got %d', numel(x));
    end

    A = [x, y, ones(numel(x), 1)];
    b = -(x.^2 + y.^2);

    if rcond(A' * A) < 1e-12
        error('sphynx:circleFit:degenerate', ...
            'Points appear collinear; cannot fit a circle');
    end

    sol = A \ b;
    a = sol(1); bb = sol(2); c = sol(3);
    xc = -a/2;
    yc = -bb/2;
    r = sqrt((a^2 + bb^2)/4 - c);
end
```

- [ ] **Step 5: Run test to verify it passes**

```matlab
runtests('tests/+unit/circleFitTest.m')
```

Expected: 5 PASSED.

- [ ] **Step 6: Commit**

```bash
git add "+sphynx/+util/circleFit.m" tests/+unit/circleFitTest.m
git commit -m "$(cat <<'EOF'
feat(util): sphynx.util.circleFit replacing legacy circfit

Least-squares circle fit. Differs from legacy by raising
explicit errors on too-few-points and collinear input,
instead of silently returning NaN.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task A.1.2 — `sphynx.util.polygonFit`

**Files:**
- Create: `+sphynx/+util/polygonFit.m`
- Test:   `tests/+unit/polygonFitTest.m`

- [ ] **Step 1: Read legacy `functions/PolygonFit.m`**

```bash
cat functions/PolygonFit.m
```

Note: PolygonFit takes a list of corner points (clicked by user) and returns the closed polygon outline + per-side dense traces (for use with mask creation). Confirm exact return signature — the legacy returns `[x_arena, y_arena, border_separate_x, border_separate_y]` where the latter two are cell arrays of per-side x/y traces.

- [ ] **Step 2: Write the test**

Create `tests/+unit/polygonFitTest.m`:

```matlab
function tests = polygonFitTest
    tests = functiontests(localfunctions);
end

function testSquareReturnsClosedPolygon(testCase)
    % Square corners
    x = [0; 10; 10;  0];
    y = [0;  0; 10; 10];
    [px, py, sx, sy] = sphynx.util.polygonFit(x, y);
    verifyEqual(testCase, numel(px), numel(py));
    verifyEqual(testCase, px(1), px(end), 'AbsTol', 1e-9, ...
        'polygon should be closed');
    verifyEqual(testCase, numel(sx), 4, 'square has 4 sides');
    verifyEqual(testCase, numel(sy), 4);
end

function testSidesAreDense(testCase)
    x = [0; 10; 10;  0];
    y = [0;  0; 10; 10];
    [~, ~, sx, ~] = sphynx.util.polygonFit(x, y);
    % Each side should have many points (linspace), not just 2
    for i = 1:4
        verifyGreaterThan(testCase, numel(sx{i}), 10);
    end
end

function testRejectsTooFewCorners(testCase)
    verifyError(testCase, @() sphynx.util.polygonFit([0;1],[0;1]), ...
        'sphynx:polygonFit:tooFewCorners');
end
```

- [ ] **Step 3: Run test, verify fail**

```matlab
runtests('tests/+unit/polygonFitTest.m')
```

Expected: 3 FAIL.

- [ ] **Step 4: Implement**

Create `+sphynx/+util/polygonFit.m`:

```matlab
function [x, y, sidesX, sidesY] = polygonFit(xCorners, yCorners, varargin)
% POLYGONFIT  Build closed dense polygon outline + per-side traces.
%
%   [x, y, sidesX, sidesY] = sphynx.util.polygonFit(xCorners, yCorners)
%
%   Inputs:
%     xCorners, yCorners — vectors of corner coordinates (>=3 points)
%
%   Outputs:
%     x, y        — closed dense outline (last point repeats first)
%     sidesX{i}   — dense x-coords for side i (corner i to corner i+1)
%     sidesY{i}   — dense y-coords for side i
%
%   Optional name-value:
%     'PointsPerSide' — number of points per side (default 1000)
%
%   Replacement for legacy functions/PolygonFit.m.

    p = inputParser;
    addParameter(p, 'PointsPerSide', 1000, @(v) isnumeric(v) && v > 1);
    parse(p, varargin{:});
    nPerSide = p.Results.PointsPerSide;

    xCorners = xCorners(:); yCorners = yCorners(:);
    if numel(xCorners) ~= numel(yCorners)
        error('sphynx:polygonFit:sizeMismatch', ...
            'xCorners and yCorners must match in length');
    end
    if numel(xCorners) < 3
        error('sphynx:polygonFit:tooFewCorners', ...
            'Need at least 3 corners; got %d', numel(xCorners));
    end

    nSides = numel(xCorners);
    sidesX = cell(1, nSides);
    sidesY = cell(1, nSides);
    for i = 1:nSides
        i2 = mod(i, nSides) + 1; % wrap
        sidesX{i} = linspace(xCorners(i), xCorners(i2), nPerSide);
        sidesY{i} = linspace(yCorners(i), yCorners(i2), nPerSide);
    end

    % Concatenate sides; for a closed outline, last point of side i == first of side i+1
    x = [];
    y = [];
    for i = 1:nSides
        x = [x; sidesX{i}(:)]; %#ok<AGROW>
        y = [y; sidesY{i}(:)]; %#ok<AGROW>
    end
end
```

- [ ] **Step 5: Run test**

```matlab
runtests('tests/+unit/polygonFitTest.m')
```

Expected: 3 PASSED.

- [ ] **Step 6: Commit**

```bash
git add "+sphynx/+util/polygonFit.m" tests/+unit/polygonFitTest.m
git commit -m "$(cat <<'EOF'
feat(util): sphynx.util.polygonFit replacing legacy PolygonFit

Builds closed dense polygon outline + per-side traces from
corner points. Cleaner inputs (vectors), explicit error on
too-few-corners (legacy was silent).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task A.1.3 — `sphynx.util.inMaskSafe` (frame-edge safe mask query)

**Files:**
- Create: `+sphynx/+util/inMaskSafe.m`
- Test:   `tests/+unit/inMaskSafeTest.m`

This is the **direct fix for Bug-1**: when arena polygon touches the frame edge, mask operations in `bwdist` need a padded frame so "outside frame" doesn't read as "inside arena".

- [ ] **Step 1: Write the test**

Create `tests/+unit/inMaskSafeTest.m`:

```matlab
function tests = inMaskSafeTest
    tests = functiontests(localfunctions);
end

function testInsideMask(testCase)
    mask = false(10, 10); mask(3:7, 3:7) = true;
    verifyTrue(testCase, sphynx.util.inMaskSafe(mask, 5, 5));
end

function testOutsideMask(testCase)
    mask = false(10, 10); mask(3:7, 3:7) = true;
    verifyFalse(testCase, sphynx.util.inMaskSafe(mask, 1, 1));
end

function testOutsideFrameReturnsFalse(testCase)
    mask = false(10, 10); mask(3:7, 3:7) = true;
    verifyFalse(testCase, sphynx.util.inMaskSafe(mask, -3, 5));
    verifyFalse(testCase, sphynx.util.inMaskSafe(mask, 5, -3));
    verifyFalse(testCase, sphynx.util.inMaskSafe(mask, 100, 5));
    verifyFalse(testCase, sphynx.util.inMaskSafe(mask, 5, 100));
end

function testNonIntegerCoordinates(testCase)
    mask = false(10, 10); mask(3:7, 3:7) = true;
    verifyTrue(testCase, sphynx.util.inMaskSafe(mask, 5.7, 4.3));
end

function testVectorizedInput(testCase)
    mask = false(10, 10); mask(3:7, 3:7) = true;
    xs = [5; 1; -3; 100];
    ys = [5; 1;  5; 5];
    expected = [true; false; false; false];
    verifyEqual(testCase, sphynx.util.inMaskSafe(mask, xs, ys), expected);
end
```

- [ ] **Step 2: Run, verify fail**

```matlab
runtests('tests/+unit/inMaskSafeTest.m')
```

Expected: 5 FAIL.

- [ ] **Step 3: Implement**

Create `+sphynx/+util/inMaskSafe.m`:

```matlab
function inside = inMaskSafe(mask, x, y)
% INMASKSAFE  Query a 2D logical mask at (x, y) safely.
%
%   inside = sphynx.util.inMaskSafe(mask, x, y) returns true if the
%   given pixel is inside the mask. Coordinates are floored to the
%   nearest pixel. Coordinates outside the mask bounds return false.
%
%   Vectorized: x and y can be vectors of the same length, returning
%   a logical column vector.
%
%   Use this instead of direct mask(round(y), round(x)) — that
%   crashes or returns garbage for out-of-bounds, contributing to
%   Bug-1 (arena boundary at frame edge).
%
%   See also: sphynx.zones.classifySquare

    x = x(:); y = y(:);
    if numel(x) ~= numel(y)
        error('sphynx:inMaskSafe:sizeMismatch', 'x and y must have same length');
    end

    [H, W] = size(mask);
    xi = round(x);
    yi = round(y);
    inBounds = xi >= 1 & xi <= W & yi >= 1 & yi <= H;
    inside = false(numel(x), 1);
    if any(inBounds)
        idx = sub2ind([H, W], yi(inBounds), xi(inBounds));
        inside(inBounds) = mask(idx) > 0;
    end
end
```

- [ ] **Step 4: Run test**

```matlab
runtests('tests/+unit/inMaskSafeTest.m')
```

Expected: 5 PASSED.

- [ ] **Step 5: Commit**

```bash
git add "+sphynx/+util/inMaskSafe.m" tests/+unit/inMaskSafeTest.m
git commit -m "$(cat <<'EOF'
feat(util): sphynx.util.inMaskSafe — frame-edge-safe mask query

Returns false (not error/garbage) for coordinates outside the
mask bounds. Vectorized. This is the building block for the
Bug-1 fix in zone classification (legacy crashed or read
arbitrary values when arena touched frame edge).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task A.1.4 — `sphynx.zones.partitionStrips`

**Files:**
- Create: `+sphynx/+zones/partitionStrips.m`
- Test:   `tests/+unit/partitionStripsTest.m`

This implements feature 1.3 for square arenas: divide into N equal vertical or horizontal strips.

- [ ] **Step 1: Write the test**

Create `tests/+unit/partitionStripsTest.m`:

```matlab
function tests = partitionStripsTest
    tests = functiontests(localfunctions);
end

function testThreeHorizontalStrips(testCase)
    arenaMask = false(30, 60);
    arenaMask(:, :) = true;  % whole frame is the arena
    zones = sphynx.zones.partitionStrips(arenaMask, 3, 'horizontal');
    verifyEqual(testCase, numel(zones), 3);
    % Top strip should have rows ~1-10, all cols
    verifyEqual(testCase, zones(1).name, 'strip1');
    % Each strip should be ~330 of the area
    for i = 1:3
        verifyGreaterThan(testCase, sum(zones(i).maskfilled(:)), 30*60/3 - 30);
        verifyLessThan(testCase, sum(zones(i).maskfilled(:)), 30*60/3 + 30);
    end
end

function testTwoVerticalStrips(testCase)
    arenaMask = false(20, 40);
    arenaMask(:, :) = true;
    zones = sphynx.zones.partitionStrips(arenaMask, 2, 'vertical');
    verifyEqual(testCase, numel(zones), 2);
    % strip1 should be left half
    verifyTrue(testCase, zones(1).maskfilled(10, 5));
    verifyFalse(testCase, zones(1).maskfilled(10, 35));
    verifyTrue(testCase, zones(2).maskfilled(10, 35));
    verifyFalse(testCase, zones(2).maskfilled(10, 5));
end

function testRejectsZeroStrips(testCase)
    arenaMask = true(10, 10);
    verifyError(testCase, @() sphynx.zones.partitionStrips(arenaMask, 0, 'horizontal'), ...
        'sphynx:partitionStrips:invalidN');
end

function testRejectsUnknownDirection(testCase)
    arenaMask = true(10, 10);
    verifyError(testCase, @() sphynx.zones.partitionStrips(arenaMask, 3, 'diagonal'), ...
        'sphynx:partitionStrips:unknownDirection');
end

function testStripsArePartitionOfArena(testCase)
    arenaMask = false(20, 30);
    arenaMask(5:15, 5:25) = true;  % rectangular arena inside frame
    zones = sphynx.zones.partitionStrips(arenaMask, 4, 'horizontal');
    summed = false(20, 30);
    for i = 1:4
        % no overlap
        verifyFalse(testCase, any(summed(:) & zones(i).maskfilled(:)));
        summed = summed | zones(i).maskfilled;
    end
    % union == arenaMask
    verifyEqual(testCase, summed, arenaMask);
end
```

- [ ] **Step 2: Run, verify fail**

```matlab
runtests('tests/+unit/partitionStripsTest.m')
```

Expected: 5 FAIL.

- [ ] **Step 3: Implement**

Create `+sphynx/+zones/partitionStrips.m`:

```matlab
function zones = partitionStrips(arenaMask, N, direction)
% PARTITIONSTRIPS  Divide arena mask into N equal strips.
%
%   zones = sphynx.zones.partitionStrips(arenaMask, N, direction)
%
%   Inputs:
%     arenaMask  — H×W logical, true inside arena
%     N          — positive integer, number of strips
%     direction  — 'horizontal' (top→bottom) | 'vertical' (left→right)
%
%   Output:
%     zones — 1×N struct array with fields:
%               name        — 'strip1', 'strip2', ...
%               type        — 'area'
%               maskfilled  — H×W logical, true inside strip i
%
%   The strips partition the arena: their union equals the input
%   arena mask, and they are pairwise disjoint. Strips are computed
%   by splitting the bounding box of the arena into N equal slabs
%   along the chosen direction, then intersecting with arenaMask.
%
%   Implements feature 1.3 (square arena partitioning) from
%   docs/superpowers/specs/2026-04-27-sphynx-stage-c-design.md.

    if ~islogical(arenaMask)
        arenaMask = arenaMask > 0;
    end
    if ~isnumeric(N) || N < 1 || N ~= round(N)
        error('sphynx:partitionStrips:invalidN', ...
            'N must be a positive integer; got %g', N);
    end
    if ~ismember(direction, {'horizontal','vertical'})
        error('sphynx:partitionStrips:unknownDirection', ...
            'direction must be horizontal|vertical; got "%s"', direction);
    end

    [H, W] = size(arenaMask);

    % Bounding box of arena
    [yIdx, xIdx] = find(arenaMask);
    if isempty(yIdx)
        error('sphynx:partitionStrips:emptyArena', 'arenaMask is empty');
    end
    yMin = min(yIdx); yMax = max(yIdx);
    xMin = min(xIdx); xMax = max(xIdx);

    zones = struct('name',{},'type',{},'maskfilled',{});
    for i = 1:N
        m = false(H, W);
        switch direction
            case 'horizontal'
                yLo = yMin + round((i-1) * (yMax - yMin + 1) / N);
                yHi = yMin + round(i     * (yMax - yMin + 1) / N) - 1;
                yLo = max(yLo, 1); yHi = min(yHi, H);
                m(yLo:yHi, :) = true;
            case 'vertical'
                xLo = xMin + round((i-1) * (xMax - xMin + 1) / N);
                xHi = xMin + round(i     * (xMax - xMin + 1) / N) - 1;
                xLo = max(xLo, 1); xHi = min(xHi, W);
                m(:, xLo:xHi) = true;
        end
        zones(i).name = sprintf('strip%d', i);
        zones(i).type = 'area';
        zones(i).maskfilled = m & arenaMask;
    end
end
```

- [ ] **Step 4: Run test**

```matlab
runtests('tests/+unit/partitionStripsTest.m')
```

Expected: 5 PASSED.

- [ ] **Step 5: Commit**

```bash
git add "+sphynx/+zones/partitionStrips.m" tests/+unit/partitionStripsTest.m
git commit -m "$(cat <<'EOF'
feat(zones): partitionStrips — N equal strips for square arena

Implements feature 1.3: split arena into N equal strips top->bottom
or left->right. Strips partition the arena exactly (no overlap,
union equals arena mask).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task A.1.5 — `sphynx.zones.classifyCircle`

**Files:**
- Create: `+sphynx/+zones/classifyCircle.m`
- Test:   `tests/+unit/classifyCircleTest.m`

Generalizes the legacy circle wall/center to ring-based partitioning. For radius r and ring widths `[w_wall, w_middle, w_middle, ...]`:
- `wall`: outer ring of width `w_wall`
- `middle1`: next ring of width `w_middle`
- `middle2`: next, etc.
- `center`: remainder if at least 10 cm radius left

- [ ] **Step 1: Write the test**

Create `tests/+unit/classifyCircleTest.m`:

```matlab
function tests = classifyCircleTest
    tests = functiontests(localfunctions);
end

function testSmallArenaWallAndCenter(testCase)
    % 30 cm radius arena, 10 cm wall, no middle, leftover 20 cm = center
    H = 200; W = 200; pxlPerCm = 2;
    arenaMask = makeCircleMask(H, W, 100, 100, 30 * pxlPerCm);
    zones = sphynx.zones.classifyCircle(arenaMask, ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 10, ...
        'MiddleWidthCm', 20);
    names = {zones.name};
    verifyTrue(testCase, ismember('wall', names));
    verifyTrue(testCase, ismember('center', names));
    verifyFalse(testCase, ismember('middle1', names));
end

function testLargeArenaWithMiddleRings(testCase)
    % 80 cm radius: 10 wall + 20 middle1 + 20 middle2 + center (rest = 30, wait 80-50=30)
    % wait: wall=10, middle1=10..30 (20 wide), middle2=30..50, center=50..80 (>= 10)
    H = 400; W = 400; pxlPerCm = 2;
    arenaMask = makeCircleMask(H, W, 200, 200, 80 * pxlPerCm);
    zones = sphynx.zones.classifyCircle(arenaMask, ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 10, ...
        'MiddleWidthCm', 20);
    names = {zones.name};
    verifyTrue(testCase, ismember('wall', names));
    verifyTrue(testCase, ismember('middle1', names));
    verifyTrue(testCase, ismember('middle2', names));
    verifyTrue(testCase, ismember('center', names));
end

function testNoCenterIfTooSmall(testCase)
    % 25 cm radius: wall 10 + middle 20 leaves -5; only wall and middle1 exist
    H = 200; W = 200; pxlPerCm = 2;
    arenaMask = makeCircleMask(H, W, 100, 100, 25 * pxlPerCm);
    zones = sphynx.zones.classifyCircle(arenaMask, ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 10, ...
        'MiddleWidthCm', 20, ...
        'MinCenterCm', 10);
    names = {zones.name};
    verifyTrue(testCase, ismember('wall', names));
    verifyFalse(testCase, ismember('center', names));
end

function testZonesArePartitionOfArena(testCase)
    H = 300; W = 300; pxlPerCm = 2;
    arenaMask = makeCircleMask(H, W, 150, 150, 60 * pxlPerCm);
    zones = sphynx.zones.classifyCircle(arenaMask, ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 10, ...
        'MiddleWidthCm', 20);
    summed = false(H, W);
    for i = 1:numel(zones)
        verifyFalse(testCase, any(summed(:) & zones(i).maskfilled(:)));
        summed = summed | zones(i).maskfilled;
    end
    verifyEqual(testCase, summed, arenaMask);
end

function testArenaTouchingFrameEdgeBug1(testCase)
    % Bug-1 case: arena center near frame edge, arena touches edge
    H = 200; W = 200; pxlPerCm = 2;
    arenaMask = makeCircleMask(H, W, 60, 60, 60 * pxlPerCm);  % touches frame
    zones = sphynx.zones.classifyCircle(arenaMask, ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 10, ...
        'MiddleWidthCm', 20);
    % Should not crash; should have wall zone non-empty
    wall = zones(strcmp({zones.name},'wall'));
    verifyGreaterThan(testCase, sum(wall.maskfilled(:)), 0);
end

function mask = makeCircleMask(H, W, cx, cy, r)
    [X, Y] = meshgrid(1:W, 1:H);
    mask = (X - cx).^2 + (Y - cy).^2 <= r^2;
end
```

- [ ] **Step 2: Run, verify fail**

```matlab
runtests('tests/+unit/classifyCircleTest.m')
```

Expected: 5 FAIL.

- [ ] **Step 3: Implement**

Create `+sphynx/+zones/classifyCircle.m`:

```matlab
function zones = classifyCircle(arenaMask, varargin)
% CLASSIFYCIRCLE  Ring-based zone classification for round arena.
%
%   zones = sphynx.zones.classifyCircle(arenaMask, ...) returns a
%   struct array of concentric ring zones inside arenaMask:
%     wall     — outermost ring of width WallWidthCm
%     middle1  — next ring inward of width MiddleWidthCm
%     middle2  — next ring inward of width MiddleWidthCm
%     ...
%     center   — innermost remaining disk, if >= MinCenterCm radius
%
%   Name-value parameters:
%     PixelsPerCm    (required) — calibration scale
%     WallWidthCm    (default 10)
%     MiddleWidthCm  (default 20)
%     MinCenterCm    (default 10) — minimum center radius to keep
%
%   Bug-1 fix: uses sphynx.util.inMaskSafe-style operations on a
%   padded frame so arena boundaries touching the original frame
%   edge are handled correctly.
%
%   Implements feature 1.3 (round arena ring partitioning).

    p = inputParser;
    addRequired(p, 'arenaMask', @(m) islogical(m) || isnumeric(m));
    addParameter(p, 'PixelsPerCm', [], @(v) isnumeric(v) && v > 0);
    addParameter(p, 'WallWidthCm', 10, @(v) isnumeric(v) && v >= 0);
    addParameter(p, 'MiddleWidthCm', 20, @(v) isnumeric(v) && v > 0);
    addParameter(p, 'MinCenterCm', 10, @(v) isnumeric(v) && v >= 0);
    parse(p, arenaMask, varargin{:});

    if isempty(p.Results.PixelsPerCm)
        error('sphynx:classifyCircle:missingPixelsPerCm', ...
            'PixelsPerCm is required');
    end

    pxlPerCm = p.Results.PixelsPerCm;
    wallW = p.Results.WallWidthCm * pxlPerCm;
    midW  = p.Results.MiddleWidthCm * pxlPerCm;
    minC  = p.Results.MinCenterCm * pxlPerCm;

    arenaMask = arenaMask > 0;

    % Padded distance transform to handle arena touching frame edges
    pad = max(round(wallW + midW * 4 + minC + 10), 20);
    paddedMask = padarray(arenaMask, [pad pad], false, 'both');
    distFromOutside = bwdist(~paddedMask);

    zones = struct('name',{},'type',{},'maskfilled',{});

    cumW = wallW;
    % Wall ring: 0 < dist <= wallW
    wallRingPadded = paddedMask & distFromOutside > 0 & distFromOutside <= wallW;
    zones(end+1) = mkZone('wall', wallRingPadded, pad);

    ringIdx = 1;
    while true
        prevW = cumW;
        cumW = cumW + midW;
        ring = paddedMask & distFromOutside > prevW & distFromOutside <= cumW;
        % Estimate remaining inner radius after this ring
        remaining = paddedMask & distFromOutside > cumW;
        remainingDist = bwdist(~remaining);
        maxRemainingRadius = max(remainingDist(:));
        if maxRemainingRadius < minC
            % Fold remainder into a center zone
            if any(ring(:))
                zones(end+1) = mkZone(sprintf('middle%d', ringIdx), ring, pad); %#ok<AGROW>
            end
            if any(remaining(:))
                zones(end+1) = mkZone('center', remaining, pad); %#ok<AGROW>
            end
            break;
        else
            zones(end+1) = mkZone(sprintf('middle%d', ringIdx), ring, pad); %#ok<AGROW>
            ringIdx = ringIdx + 1;
        end
        if ringIdx > 50
            error('sphynx:classifyCircle:tooManyRings', ...
                'Computed > 50 middle rings; check input parameters');
        end
    end
end

function zone = mkZone(name, paddedMask, pad)
    [Hp, Wp] = size(paddedMask);
    H = Hp - 2*pad;
    W = Wp - 2*pad;
    zone.name = name;
    zone.type = 'area';
    zone.maskfilled = paddedMask(pad+1 : pad+H, pad+1 : pad+W);
end
```

- [ ] **Step 4: Run test**

```matlab
runtests('tests/+unit/classifyCircleTest.m')
```

Expected: 5 PASSED.

If a test fails because of how `bwdist` rounds, adjust thresholds slightly or report which assertion fails so we can iterate.

- [ ] **Step 5: Commit**

```bash
git add "+sphynx/+zones/classifyCircle.m" tests/+unit/classifyCircleTest.m
git commit -m "$(cat <<'EOF'
feat(zones): classifyCircle — generalized ring-based partitioning

Replaces legacy wall+center for round arenas with arbitrary
ring widths supporting arenas up to 3 m.

Bug-1 mitigation included: distance transform runs on a padded
frame so arenas touching the frame edge classify correctly.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task A.1.6 — `sphynx.zones.classifySquare`

**Files:**
- Create: `+sphynx/+zones/classifySquare.m`
- Test:   `tests/+unit/classifySquareTest.m`

This is the **direct fix for Bug-1** in the most common case (rectangular open field). Supports two modes:
- `'corners-walls-center'` — legacy default
- `'strips'` — uses `partitionStrips`

- [ ] **Step 1: Write the test**

Create `tests/+unit/classifySquareTest.m`:

```matlab
function tests = classifySquareTest
    tests = functiontests(localfunctions);
end

function testCornersWallsCenterBasic(testCase)
    H = 200; W = 300; pxlPerCm = 5;
    arenaCorners = [[50 250 250  50]; [50  50 150 150]]'; % x; y -> Nx2 not needed; legacy uses two vectors
    xC = arenaCorners(:,1); yC = arenaCorners(:,2);
    [arenaMask, arenaPolyX, arenaPolyY] = makeRectMask(H, W, xC, yC);
    zones = sphynx.zones.classifySquare(arenaMask, ...
        'Strategy', 'corners-walls-center', ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 3, ...
        'CornerPoints', [xC yC]);
    names = {zones.name};
    verifyTrue(testCase, ismember('corners', names));
    verifyTrue(testCase, ismember('walls', names));
    verifyTrue(testCase, ismember('center', names));
end

function testCornersWallsCenterArenaTouchingFrameEdge(testCase)
    % Bug-1: arena that touches frame edges must not crash and must
    % produce non-empty wall/corner zones.
    H = 100; W = 200; pxlPerCm = 5;
    xC = [1 200 200 1]'; yC = [1 1 100 100]'; % arena = whole frame
    arenaMask = true(H, W);
    zones = sphynx.zones.classifySquare(arenaMask, ...
        'Strategy', 'corners-walls-center', ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 3, ...
        'CornerPoints', [xC yC]);
    walls = zones(strcmp({zones.name},'walls'));
    corners = zones(strcmp({zones.name},'corners'));
    verifyGreaterThan(testCase, sum(walls.maskfilled(:)), 0);
    verifyGreaterThan(testCase, sum(corners.maskfilled(:)), 0);
end

function testStripsStrategyDelegatesToPartition(testCase)
    H = 100; W = 200; pxlPerCm = 5;
    arenaMask = false(H, W); arenaMask(20:80, 20:180) = true;
    zones = sphynx.zones.classifySquare(arenaMask, ...
        'Strategy', 'strips', ...
        'NumStrips', 3, ...
        'StripDirection', 'vertical');
    verifyEqual(testCase, numel(zones), 3);
    verifyEqual(testCase, zones(1).name, 'strip1');
end

function testNoneStrategyReturnsArenaOnly(testCase)
    H = 100; W = 200;
    arenaMask = false(H, W); arenaMask(20:80, 20:180) = true;
    zones = sphynx.zones.classifySquare(arenaMask, 'Strategy', 'none');
    verifyEqual(testCase, numel(zones), 1);
    verifyEqual(testCase, zones(1).name, 'arena');
end

function testRejectsUnknownStrategy(testCase)
    arenaMask = true(10, 10);
    verifyError(testCase, @() sphynx.zones.classifySquare(arenaMask, 'Strategy', 'blah'), ...
        'sphynx:classifySquare:unknownStrategy');
end

function [mask, px, py] = makeRectMask(H, W, xC, yC)
    [X, Y] = meshgrid(1:W, 1:H);
    mask = inpolygon(X, Y, xC, yC);
    px = xC; py = yC;
end
```

- [ ] **Step 2: Run, verify fail**

```matlab
runtests('tests/+unit/classifySquareTest.m')
```

Expected: 5 FAIL.

- [ ] **Step 3: Implement**

Create `+sphynx/+zones/classifySquare.m`:

```matlab
function zones = classifySquare(arenaMask, varargin)
% CLASSIFYSQUARE  Zone classification for square/polygon arena.
%
%   zones = sphynx.zones.classifySquare(arenaMask, ...) returns a
%   struct array of zone masks for a polygon arena, depending on the
%   chosen Strategy.
%
%   Name-value parameters:
%     'Strategy'        (default 'corners-walls-center')
%                       'corners-walls-center' | 'strips' | 'none'
%     'PixelsPerCm'     scale factor (required for corners-walls-center)
%     'WallWidthCm'     default 3
%     'CornerPoints'    Nx2 [x y] corner positions (required for corners-walls-center)
%     'NumStrips'       integer, for 'strips' strategy
%     'StripDirection'  'horizontal' | 'vertical', for 'strips'
%
%   Bug-1 fix: distance transforms run on a padded frame so arena
%   boundaries touching the original frame edge classify correctly.
%
%   See also: sphynx.zones.partitionStrips, sphynx.zones.classifyCircle

    p = inputParser;
    addRequired(p, 'arenaMask');
    addParameter(p, 'Strategy', 'corners-walls-center', @ischar);
    addParameter(p, 'PixelsPerCm', [], @(v) isempty(v) || (isnumeric(v) && v > 0));
    addParameter(p, 'WallWidthCm', 3, @(v) isnumeric(v) && v >= 0);
    addParameter(p, 'CornerPoints', [], @(v) isempty(v) || (size(v,2) == 2));
    addParameter(p, 'NumStrips', 3, @(v) isnumeric(v) && v >= 1);
    addParameter(p, 'StripDirection', 'horizontal', @ischar);
    parse(p, arenaMask, varargin{:});

    arenaMask = arenaMask > 0;

    switch p.Results.Strategy
        case 'corners-walls-center'
            zones = cornersWallsCenter(arenaMask, p.Results);
        case 'strips'
            zones = sphynx.zones.partitionStrips(arenaMask, p.Results.NumStrips, p.Results.StripDirection);
        case 'none'
            zones = struct('name','arena','type','area','maskfilled',arenaMask);
        otherwise
            error('sphynx:classifySquare:unknownStrategy', ...
                'Strategy must be corners-walls-center|strips|none; got "%s"', ...
                p.Results.Strategy);
    end
end

function zones = cornersWallsCenter(arenaMask, opts)
    if isempty(opts.PixelsPerCm)
        error('sphynx:classifySquare:missingPixelsPerCm', ...
            'PixelsPerCm is required for corners-walls-center strategy');
    end
    if isempty(opts.CornerPoints)
        error('sphynx:classifySquare:missingCornerPoints', ...
            'CornerPoints is required for corners-walls-center strategy');
    end

    pxlPerCm = opts.PixelsPerCm;
    wallW = opts.WallWidthCm * pxlPerCm;
    cornerW = wallW * sqrt(2);

    [H, W] = size(arenaMask);

    % Bug-1 fix: pad the frame so distance transform doesn't see frame edge
    % as "outside arena" when arena actually extends to the edge.
    pad = max(round(wallW + cornerW + 10), 20);
    paddedMask = padarray(arenaMask, [pad pad], false, 'both');

    distFromOutside = bwdist(~paddedMask);

    % Center: pixels deeper than wallW from the boundary
    centerPadded = paddedMask & distFromOutside > wallW;

    % Walls and corners region: arena minus center
    wallsAndCornersPadded = paddedMask & ~centerPadded;

    % Corners: pixels within cornerW of any corner POINT
    cornersPadded = false(size(paddedMask));
    if ~isempty(opts.CornerPoints)
        for i = 1:size(opts.CornerPoints, 1)
            cx = round(opts.CornerPoints(i,1)) + pad;
            cy = round(opts.CornerPoints(i,2)) + pad;
            if cx < 1 || cx > size(paddedMask,2) || cy < 1 || cy > size(paddedMask,1)
                continue;
            end
            seed = false(size(paddedMask));
            seed(cy, cx) = true;
            distFromCorner = bwdist(seed);
            cornerNeighborhood = distFromCorner <= cornerW;
            cornersPadded = cornersPadded | (wallsAndCornersPadded & cornerNeighborhood);
        end
    end

    wallsPadded = wallsAndCornersPadded & ~cornersPadded;

    % Crop back to original size
    zones = struct('name',{},'type',{},'maskfilled',{});
    zones(1) = mkZone('corners', cornersPadded, pad);
    zones(2) = mkZone('walls',   wallsPadded,   pad);
    zones(3) = mkZone('center',  centerPadded,  pad);
end

function zone = mkZone(name, paddedMask, pad)
    [Hp, Wp] = size(paddedMask);
    H = Hp - 2*pad;
    W = Wp - 2*pad;
    zone.name = name;
    zone.type = 'area';
    zone.maskfilled = paddedMask(pad+1 : pad+H, pad+1 : pad+W);
end
```

- [ ] **Step 4: Run test**

```matlab
runtests('tests/+unit/classifySquareTest.m')
```

Expected: 5 PASSED.

- [ ] **Step 5: Commit**

```bash
git add "+sphynx/+zones/classifySquare.m" tests/+unit/classifySquareTest.m
git commit -m "$(cat <<'EOF'
feat(zones): classifySquare — Bug-1 fix + new strategies

Three strategies: corners-walls-center (legacy default),
strips (feature 1.3), none.

Bug-1 fix: distance transform runs on a padded frame so arenas
touching the original frame edge produce correct wall/corner
zones. Legacy crashed or returned zero-size zones in this case.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task A.1.7 — Synthetic test fixtures for zones

**Files:**
- Create: `+sphynx/+testing/makeArenaAtFrameEdgeDLC.m`
- Create: `+sphynx/+testing/makeZoneCrossDLC.m`

These produce synthetic data structures used by the synthetic test in Task A.1.8.

- [ ] **Step 1: Implement makeArenaAtFrameEdgeDLC**

Create `+sphynx/+testing/makeArenaAtFrameEdgeDLC.m`:

```matlab
function fixture = makeArenaAtFrameEdgeDLC()
% MAKEARENAATFRAMEEDGEDLC  Synthetic arena that touches frame edge.
%
%   fixture = sphynx.testing.makeArenaAtFrameEdgeDLC() returns a
%   struct with fields:
%     arenaMask    — H×W logical, arena occupying the whole frame
%     pxlPerCm     — pixels per cm calibration
%     cornerPoints — 4×2 matrix of arena corners
%
%   Used to verify Bug-1 zone classification on edge-touching arena.

    H = 200; W = 300;
    fixture.arenaMask = true(H, W);
    fixture.pxlPerCm = 5;
    fixture.cornerPoints = [1 1; W 1; W H; 1 H];
end
```

- [ ] **Step 2: Implement makeZoneCrossDLC**

Create `+sphynx/+testing/makeZoneCrossDLC.m`:

```matlab
function fixture = makeZoneCrossDLC()
% MAKEZONECROSSDLC  Synthetic mouse trajectory crossing zones.
%
%   fixture = sphynx.testing.makeZoneCrossDLC() returns a struct:
%     trajectory   — N×2 (x, y) matrix of body-center positions
%     arenaMask    — H×W logical
%     pxlPerCm     — calibration
%     cornerPoints — 4×2 corner positions
%     expectedZones — cell array, expected zone name at each frame
%
%   Trajectory: starts in a corner, walks along wall, turns into
%   center, crosses to the opposite wall, ends in another corner.
%   Used to verify zone-visit detection.

    H = 200; W = 300;
    pxlPerCm = 5;

    fixture.arenaMask = false(H, W);
    fixture.arenaMask(20:180, 20:280) = true;
    fixture.pxlPerCm = pxlPerCm;
    fixture.cornerPoints = [20 20; 280 20; 280 180; 20 180];

    % Trajectory waypoints (x, y) and the expected zone for each
    waypoints = [
        25  25  ; ...   corner
        25  100 ; ...   wall
        100 100 ; ...   center
        275 100 ; ...   wall
        275 175 ; ...   corner
    ];
    expectedNames = {'corners','walls','center','walls','corners'};
    nPerSegment = 30; % frames between waypoints

    traj = [];
    expected = {};
    for i = 1:size(waypoints,1)-1
        for k = 1:nPerSegment
            t = (k-1) / (nPerSegment-1);
            x = (1-t)*waypoints(i,1) + t*waypoints(i+1,1);
            y = (1-t)*waypoints(i,2) + t*waypoints(i+1,2);
            traj(end+1, :) = [x, y]; %#ok<AGROW>
            % Use the segment's start label (rough; the test checks set membership)
            expected{end+1} = expectedNames{i}; %#ok<AGROW>
        end
    end
    fixture.trajectory = traj;
    fixture.expectedZones = expected;
end
```

- [ ] **Step 3: Smoke-check**

```matlab
f = sphynx.testing.makeArenaAtFrameEdgeDLC();
assert(all(f.arenaMask(:)));
g = sphynx.testing.makeZoneCrossDLC();
fprintf('Trajectory length: %d frames\n', size(g.trajectory,1));
```

Expected: prints `Trajectory length: 120 frames` (4 segments × 30).

- [ ] **Step 4: Commit**

```bash
git add "+sphynx/+testing/makeArenaAtFrameEdgeDLC.m" "+sphynx/+testing/makeZoneCrossDLC.m"
git commit -m "$(cat <<'EOF'
test(fixtures): synthetic DLC fixtures for zone tests

makeArenaAtFrameEdgeDLC  — arena occupies whole frame (Bug-1)
makeZoneCrossDLC         — trajectory wall→center→wall→corner

Used by tests/+synthetic/zoneVisitTest.m.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task A.1.8 — Synthetic test: zone visits

**Files:**
- Create: `tests/+synthetic/zoneVisitTest.m`

- [ ] **Step 1: Write the test**

Create `tests/+synthetic/zoneVisitTest.m`:

```matlab
function tests = zoneVisitTest
% ZONEVISITTEST  Synthetic mouse crosses wall→center→wall and is detected.
%
%   Uses sphynx.testing.makeZoneCrossDLC + sphynx.zones.classifySquare
%   + sphynx.util.inMaskSafe to verify each frame is classified into
%   the expected zone (set-membership rather than exact label, since
%   transitions span a few frames).
    tests = functiontests(localfunctions);
end

function testEachWaypointHitsExpectedZone(testCase)
    f = sphynx.testing.makeZoneCrossDLC();
    zones = sphynx.zones.classifySquare(f.arenaMask, ...
        'Strategy','corners-walls-center', ...
        'PixelsPerCm',f.pxlPerCm, ...
        'WallWidthCm',3, ...
        'CornerPoints',f.cornerPoints);

    % Spot-check waypoint frames (1, 30, 60, 90, 120)
    waypointFrames = [1 30 60 90 120];
    expected = {'corners','walls','center','walls','corners'};

    for k = 1:numel(waypointFrames)
        frame = waypointFrames(k);
        if frame > size(f.trajectory,1); frame = size(f.trajectory,1); end
        x = f.trajectory(frame, 1);
        y = f.trajectory(frame, 2);
        active = '';
        for z = 1:numel(zones)
            if sphynx.util.inMaskSafe(zones(z).maskfilled, x, y)
                active = zones(z).name;
                break;
            end
        end
        verifyEqual(testCase, active, expected{k}, ...
            sprintf('frame %d at (%.1f,%.1f) expected %s, got %s', ...
            frame, x, y, expected{k}, active));
    end
end

function testArenaAtFrameEdgeDoesNotCrash(testCase)
    f = sphynx.testing.makeArenaAtFrameEdgeDLC();
    zones = sphynx.zones.classifySquare(f.arenaMask, ...
        'Strategy','corners-walls-center', ...
        'PixelsPerCm',f.pxlPerCm, ...
        'WallWidthCm',3, ...
        'CornerPoints',f.cornerPoints);
    walls = zones(strcmp({zones.name},'walls'));
    corners = zones(strcmp({zones.name},'corners'));
    verifyGreaterThan(testCase, sum(walls.maskfilled(:)), 0, ...
        'Bug-1: arena at frame edge produced empty walls zone');
    verifyGreaterThan(testCase, sum(corners.maskfilled(:)), 0, ...
        'Bug-1: arena at frame edge produced empty corners zone');
end
```

- [ ] **Step 2: Run, verify pass**

```matlab
runtests('tests/+synthetic/zoneVisitTest.m')
```

Expected: 2 PASSED.

(If `testEachWaypointHitsExpectedZone` fails on certain transitions, check whether the priority order matters: a point could be in both `corners` and `walls`. The test resolves by first match in `zones` order: corners, walls, center. This matches the typical "more specific zone wins" semantics.)

- [ ] **Step 3: Commit**

```bash
git add tests/+synthetic/zoneVisitTest.m
git commit -m "$(cat <<'EOF'
test(synthetic): zone-visit detection (Bug-1 coverage)

Two scenarios:
1. Mouse trajectory crossing corner→wall→center→wall→corner:
   verify each waypoint hits the expected zone.
2. Arena occupying entire frame: walls and corners zones must
   be non-empty (Bug-1 regression test).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task A.1.9 — Pass A.1 final check + tag

- [ ] **Step 1: Run full fast suite**

```matlab
runAllTests('tag','fast')
```

Expected: ~25 tests, all passed (or 1 skipped — the smoke placeholder).

- [ ] **Step 2: Tag**

```bash
git tag stage-c-pass-A1-zones-fixed
```

- [ ] **Step 3: Homework packet**

User reports back:
- Test summary
- Anything weird in output

If green → proceed to Pass A.2.

---

# Pass A.2 — Slice 2: Angles (Bug-2)

**Goal of Pass A.2:** `sphynx.angles.wrap`, `sphynx.angles.unwrapForSmooth`, `sphynx.angles.headDirection` — functions that produce smooth, in-range angle traces, fixing Bug-2.

---

## Task A.2.1 — `sphynx.angles.wrap`

**Files:**
- Create: `+sphynx/+angles/wrap.m`
- Test:   `tests/+unit/wrapTest.m`

- [ ] **Step 1: Write the test**

Create `tests/+unit/wrapTest.m`:

```matlab
function tests = wrapTest
    tests = functiontests(localfunctions);
end

function testZeroStaysZero(testCase)
    verifyEqual(testCase, sphynx.angles.wrap(0), 0);
end

function testWrapsPositive(testCase)
    verifyEqual(testCase, sphynx.angles.wrap(3*pi), pi, 'AbsTol', 1e-12);
    verifyEqual(testCase, sphynx.angles.wrap(2*pi), 0, 'AbsTol', 1e-12);
end

function testWrapsNegative(testCase)
    verifyEqual(testCase, sphynx.angles.wrap(-3*pi), -pi, 'AbsTol', 1e-12);
    verifyEqual(testCase, sphynx.angles.wrap(-2*pi), 0, 'AbsTol', 1e-12);
end

function testInRangeUnchanged(testCase)
    angles = [-pi+0.01; -pi/2; 0; pi/2; pi-0.01];
    verifyEqual(testCase, sphynx.angles.wrap(angles), angles, 'AbsTol', 1e-12);
end

function testVectorized(testCase)
    in  = [3*pi; -3*pi; 0; pi/4];
    out = sphynx.angles.wrap(in);
    verifyEqual(testCase, out, [pi; -pi; 0; pi/4], 'AbsTol', 1e-12);
end

function testEdgeCases(testCase)
    % Exactly pi: by convention map to pi (not -pi)
    verifyEqual(testCase, sphynx.angles.wrap(pi), pi, 'AbsTol', 1e-12);
    % Very large
    verifyEqual(testCase, sphynx.angles.wrap(1000*pi), 0, 'AbsTol', 1e-9);
end
```

- [ ] **Step 2: Run, verify fail**

```matlab
runtests('tests/+unit/wrapTest.m')
```

Expected: 6 FAIL.

- [ ] **Step 3: Implement**

Create `+sphynx/+angles/wrap.m`:

```matlab
function out = wrap(angles)
% WRAP  Wrap angles into (-pi, pi].
%
%   out = sphynx.angles.wrap(angles) returns angles wrapped into the
%   half-open interval (-pi, pi]. Vectorized; preserves shape.
%
%   Convention: pi maps to pi (not -pi). 2*pi*N maps to 0.
%
%   Use this instead of MATLAB's wrapToPi (Mapping Toolbox dependency)
%   or hand-rolled mod expressions scattered through the legacy code.
%
%   See also: sphynx.angles.unwrapForSmooth, sphynx.angles.headDirection

    out = angles - 2*pi * floor((angles + pi) / (2*pi));
    % Map exactly -pi to pi for symmetric convention
    out(out == -pi) = pi;
end
```

- [ ] **Step 4: Run test**

```matlab
runtests('tests/+unit/wrapTest.m')
```

Expected: 6 PASSED.

- [ ] **Step 5: Commit**

```bash
git add "+sphynx/+angles/wrap.m" tests/+unit/wrapTest.m
git commit -m "$(cat <<'EOF'
feat(angles): wrap — angles into (-pi, pi]

Replaces ad-hoc wrapping. Vectorized. No Mapping Toolbox dep.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task A.2.2 — `sphynx.angles.unwrapForSmooth`

**Files:**
- Create: `+sphynx/+angles/unwrapForSmooth.m`
- Test:   `tests/+unit/unwrapForSmoothTest.m`

This is the Bug-2 fix: we need a function that unwraps angles, smooths them, then re-wraps — so smoothing across the ±π discontinuity works correctly.

- [ ] **Step 1: Write the test**

Create `tests/+unit/unwrapForSmoothTest.m`:

```matlab
function tests = unwrapForSmoothTest
    tests = functiontests(localfunctions);
end

function testConstantInputUnchanged(testCase)
    in = ones(100, 1) * (pi/3);
    out = sphynx.angles.unwrapForSmooth(in, 11);
    verifyEqual(testCase, out, in, 'AbsTol', 1e-9);
end

function testNoArtifactAcrossDiscontinuity(testCase)
    % Build a signal that goes from pi-0.1 to -pi+0.1 (a single 0.2 step
    % when correctly unwrapped, NOT a 2*pi-0.2 jump)
    n = 200;
    t = (1:n)';
    raw = pi - 0.1 * (t - n/2) / (n/2);  % decreases linearly through pi
    raw = sphynx.angles.wrap(raw);
    out = sphynx.angles.unwrapForSmooth(raw, 11);
    % After unwrap-smooth-wrap, the result should still vary smoothly:
    % no jump > pi between consecutive samples
    diffs = diff(out);
    diffs = sphynx.angles.wrap(diffs);
    verifyLessThan(testCase, max(abs(diffs)), 0.05);
end

function testOutputInRange(testCase)
    in = (rand(100,1) - 0.5) * 4*pi;  % random in [-2pi, 2pi]
    out = sphynx.angles.unwrapForSmooth(in, 11);
    verifyTrue(testCase, all(out >= -pi & out <= pi));
end

function testRespectsWindowSize(testCase)
    in = randn(50, 1) * 0.1;
    out11 = sphynx.angles.unwrapForSmooth(in, 11);
    out3  = sphynx.angles.unwrapForSmooth(in, 3);
    % Wider window => smoother => smaller std
    verifyLessThan(testCase, std(out11), std(out3));
end
```

- [ ] **Step 2: Run, verify fail**

```matlab
runtests('tests/+unit/unwrapForSmoothTest.m')
```

Expected: 4 FAIL.

- [ ] **Step 3: Implement**

Create `+sphynx/+angles/unwrapForSmooth.m`:

```matlab
function out = unwrapForSmooth(angles, windowLen, varargin)
% UNWRAPFORSMOOTH  Smooth a circular angle signal correctly.
%
%   out = sphynx.angles.unwrapForSmooth(angles, windowLen) unwraps
%   the input, applies a Savitzky-Golay smoother of length windowLen,
%   and wraps the result back into (-pi, pi].
%
%   Optional name-value:
%     'PolyOrder' — sgolay polynomial order (default 3, capped at windowLen-1)
%
%   This is the Bug-2 fix for HeadDirection and BodyDirection traces:
%   smoothing the wrapped (-pi, pi] signal directly produces severe
%   artifacts at the ±pi discontinuity.

    p = inputParser;
    addRequired(p, 'angles');
    addRequired(p, 'windowLen', @(v) isnumeric(v) && v >= 3 && mod(v,2)==1);
    addParameter(p, 'PolyOrder', 3, @(v) isnumeric(v) && v >= 1);
    parse(p, angles, windowLen, varargin{:});

    polyOrder = min(p.Results.PolyOrder, windowLen - 1);

    angles = angles(:);
    unwrapped = unwrap(angles);
    if numel(unwrapped) < windowLen
        smoothed = unwrapped;
    else
        smoothed = smooth(unwrapped, windowLen, 'sgolay', polyOrder);
    end
    out = sphynx.angles.wrap(smoothed);
end
```

- [ ] **Step 4: Run test**

```matlab
runtests('tests/+unit/unwrapForSmoothTest.m')
```

Expected: 4 PASSED.

- [ ] **Step 5: Commit**

```bash
git add "+sphynx/+angles/unwrapForSmooth.m" tests/+unit/unwrapForSmoothTest.m
git commit -m "$(cat <<'EOF'
feat(angles): unwrapForSmooth — Bug-2 fix for circular smoothing

Unwraps before smoothing then re-wraps. Without this step,
applying smooth(...,'sgolay') directly to a wrapped angle
trace creates severe artifacts at the +/-pi discontinuity
(legacy HeadDirection issue).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task A.2.3 — `sphynx.angles.headDirection` (end-to-end)

**Files:**
- Create: `+sphynx/+angles/headDirection.m`

(Unit test deferred to slice 4 — it depends on the bodyparts identification machinery. Synthetic test below covers it indirectly.)

- [ ] **Step 1: Implement**

Create `+sphynx/+angles/headDirection.m`:

```matlab
function hd = headDirection(headTipX, headTipY, headCenterX, headCenterY, smoothWindow)
% HEADDIRECTION  Compute head-direction angle, safely smoothed.
%
%   hd = sphynx.angles.headDirection(tipX, tipY, centerX, centerY, win)
%   returns the head-direction angle in (-pi, pi] for each frame,
%   computed as atan2(tipY - centerY, tipX - centerX) and smoothed
%   with a Savitzky-Golay filter of length `win` after unwrapping.
%
%   Bug-2 fix: angle is unwrapped before smoothing and wrapped after,
%   so the result is continuous across the +/-pi boundary.
%
%   Inputs:
%     headTipX, headTipY       — N×1 trace of head tip position (e.g., nose)
%     headCenterX, headCenterY — N×1 trace of head center position
%     smoothWindow             — odd integer window length (>=3)

    headTipX = headTipX(:); headTipY = headTipY(:);
    headCenterX = headCenterX(:); headCenterY = headCenterY(:);

    raw = atan2(headTipY - headCenterY, headTipX - headCenterX);
    if smoothWindow >= 3
        hd = sphynx.angles.unwrapForSmooth(raw, smoothWindow);
    else
        hd = sphynx.angles.wrap(raw);
    end
end
```

- [ ] **Step 2: Smoke-check from MATLAB**

```matlab
n = 300;
t = (0:n-1)'/30;
% Mouse rotates uniformly at 1 rev/sec
ang = 2*pi*t;
tipX = cos(ang); tipY = sin(ang);
centerX = zeros(n,1); centerY = zeros(n,1);
hd = sphynx.angles.headDirection(tipX, tipY, centerX, centerY, 11);
fprintf('range: [%.3f, %.3f]\n', min(hd), max(hd));
% Expected: [-pi, pi]
fprintf('continuous (max wrapped diff): %.4f\n', max(abs(sphynx.angles.wrap(diff(hd)))));
% Expected: small (< 0.5 say)
```

- [ ] **Step 3: Commit**

```bash
git add "+sphynx/+angles/headDirection.m"
git commit -m "$(cat <<'EOF'
feat(angles): headDirection end-to-end

Computes atan2 from tip and center, then unwrapForSmooth.
Bug-2 fix encapsulated.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task A.2.4 — Synthetic test: head-direction continuity

**Files:**
- Create: `+sphynx/+testing/makeRotatingMouseDLC.m`
- Create: `tests/+synthetic/headDirectionContinuityTest.m`

- [ ] **Step 1: Implement fixture**

Create `+sphynx/+testing/makeRotatingMouseDLC.m`:

```matlab
function fixture = makeRotatingMouseDLC(totalRotationDeg, durationS, varargin)
% MAKEROTATINGMOUSEDLC  Synthetic mouse rotating uniformly in place.
%
%   fixture = sphynx.testing.makeRotatingMouseDLC(degrees, durationS)
%   returns a struct with simulated head-tip and head-center traces
%   for a mouse rotating uniformly through `degrees` over `durationS`.
%
%   Optional name-value:
%     'FrameRate'     — default 30
%     'NoseRadiusCm'  — default 1.5
%
%   Output struct:
%     headTipX, headTipY, headCenterX, headCenterY  — N×1 traces (cm)
%     frameRate, n_frames

    p = inputParser;
    addParameter(p, 'FrameRate', 30, @(v) isnumeric(v) && v > 0);
    addParameter(p, 'NoseRadiusCm', 1.5, @(v) isnumeric(v) && v > 0);
    parse(p, varargin{:});
    fr = p.Results.FrameRate;
    rNose = p.Results.NoseRadiusCm;

    n = round(durationS * fr);
    t = (0:n-1)' / fr;
    angRad = deg2rad(totalRotationDeg) * t / durationS;

    fixture.headCenterX = zeros(n,1);
    fixture.headCenterY = zeros(n,1);
    fixture.headTipX = rNose * cos(angRad);
    fixture.headTipY = rNose * sin(angRad);
    fixture.frameRate = fr;
    fixture.n_frames = n;
    fixture.expectedTotalRotationRad = deg2rad(totalRotationDeg);
end
```

- [ ] **Step 2: Write the synthetic test**

Create `tests/+synthetic/headDirectionContinuityTest.m`:

```matlab
function tests = headDirectionContinuityTest
% HEADDIRECTIONCONTINUITYTEST  Mouse rotates 720°; HD must be smooth.
    tests = functiontests(localfunctions);
end

function testNoLargeJumpsAfterSmoothing(testCase)
    f = sphynx.testing.makeRotatingMouseDLC(720, 4);  % 720 deg over 4 s
    hd = sphynx.angles.headDirection(f.headTipX, f.headTipY, ...
                                      f.headCenterX, f.headCenterY, 11);
    % After wrapping, consecutive samples should differ by at most
    % a small amount when wrapping is correctly accounted for.
    diffs = sphynx.angles.wrap(diff(hd));
    verifyLessThan(testCase, max(abs(diffs)), 0.5, ...
        'Bug-2: HD has > 0.5 rad jump between consecutive samples');
end

function testHDinValidRange(testCase)
    f = sphynx.testing.makeRotatingMouseDLC(720, 4);
    hd = sphynx.angles.headDirection(f.headTipX, f.headTipY, ...
                                      f.headCenterX, f.headCenterY, 11);
    verifyTrue(testCase, all(hd >= -pi & hd <= pi));
end

function testTotalRotationApproximatelyCorrect(testCase)
    f = sphynx.testing.makeRotatingMouseDLC(720, 4);
    hd = sphynx.angles.headDirection(f.headTipX, f.headTipY, ...
                                      f.headCenterX, f.headCenterY, 11);
    unwrapped = unwrap(hd);
    actualRotation = unwrapped(end) - unwrapped(1);
    verifyEqual(testCase, actualRotation, f.expectedTotalRotationRad, ...
        'AbsTol', 0.1);
end
```

- [ ] **Step 3: Run, verify pass**

```matlab
runtests('tests/+synthetic/headDirectionContinuityTest.m')
```

Expected: 3 PASSED.

- [ ] **Step 4: Commit**

```bash
git add "+sphynx/+testing/makeRotatingMouseDLC.m" tests/+synthetic/headDirectionContinuityTest.m
git commit -m "$(cat <<'EOF'
test(synthetic): head-direction continuity (Bug-2 coverage)

Synthetic mouse rotating 720 deg over 4 s. Verifies that the
new headDirection produces a smooth, in-range angle trace
without artifacts at +/-pi (Bug-2 regression).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task A.2.5 — Pass A.2 final + tag

- [ ] **Step 1: Run fast suite**

```matlab
runAllTests('tag','fast')
```

Expected: ~33 tests, all green (or 1 skipped).

- [ ] **Step 2: Tag**

```bash
git tag stage-c-pass-A2-angles-fixed
```

- [ ] **Step 3: Homework**: user reports outcome.

---

# Pass A.3 — Slice 3: Velocity & smoothing (Bug-3 + Bug-4)

**Goal of Pass A.3:** `sphynx.preprocess.smoothTrace` (Bug-3 — edge artifacts) and `sphynx.preprocess.computeVelocity` (Bug-4 — outlier clipping at 50 cm/s).

---

## Task A.3.1 — `sphynx.preprocess.smoothTrace`

**Files:**
- Create: `+sphynx/+preprocess/smoothTrace.m`
- Test:   `tests/+unit/smoothTraceTest.m`

- [ ] **Step 1: Write the test**

Create `tests/+unit/smoothTraceTest.m`:

```matlab
function tests = smoothTraceTest
    tests = functiontests(localfunctions);
end

function testConstantSignalStaysConstantIncludingEdges(testCase)
    in = ones(100, 1) * 5.7;
    out = sphynx.preprocess.smoothTrace(in, 11);
    verifyEqual(testCase, out, in, 'AbsTol', 1e-9, ...
        'Bug-3: edges of constant signal must remain constant');
end

function testLinearTrendPreserved(testCase)
    in = (1:100)' * 0.1;
    out = sphynx.preprocess.smoothTrace(in, 11);
    % S-G of order >=1 preserves linear trends exactly (in interior;
    % mirror padding ensures it at edges too)
    verifyEqual(testCase, out, in, 'AbsTol', 0.05);
end

function testReducesGaussianNoise(testCase)
    rng(42);
    in = randn(200, 1);
    out = sphynx.preprocess.smoothTrace(in, 21);
    % Smoothed should have lower std than original
    verifyLessThan(testCase, std(out), 0.5 * std(in));
end

function testWindowLengthValidation(testCase)
    in = ones(50, 1);
    verifyError(testCase, @() sphynx.preprocess.smoothTrace(in, 4), ...
        'sphynx:smoothTrace:windowEven');
    verifyError(testCase, @() sphynx.preprocess.smoothTrace(in, 1), ...
        'sphynx:smoothTrace:windowTooSmall');
end

function testTraceShorterThanWindowReturnsInput(testCase)
    in = (1:5)';
    out = sphynx.preprocess.smoothTrace(in, 11);
    verifyEqual(testCase, out, in);
end
```

- [ ] **Step 2: Run, verify fail**

```matlab
runtests('tests/+unit/smoothTraceTest.m')
```

Expected: 6 FAIL.

- [ ] **Step 3: Implement**

Create `+sphynx/+preprocess/smoothTrace.m`:

```matlab
function out = smoothTrace(trace, windowLen, varargin)
% SMOOTHTRACE  Edge-aware Savitzky-Golay smoothing.
%
%   out = sphynx.preprocess.smoothTrace(trace, windowLen) smooths the
%   input with an sgolay filter of length windowLen and polynomial
%   order min(3, windowLen-1).
%
%   Bug-3 fix: input is mirror-padded by (windowLen-1)/2 samples on
%   each side before smoothing, then the padding is stripped. This
%   prevents the inflated values at trace edges that the legacy
%   smooth(...,'sgolay') exhibits.
%
%   Optional name-value:
%     'PolyOrder' — default 3, capped at windowLen-1
%
%   Edge cases:
%     - If trace is shorter than windowLen, returns trace unchanged.
%     - windowLen must be odd and >= 3.

    p = inputParser;
    addRequired(p, 'trace', @(v) isnumeric(v));
    addRequired(p, 'windowLen', @(v) isnumeric(v));
    addParameter(p, 'PolyOrder', 3, @(v) isnumeric(v) && v >= 1);
    parse(p, trace, windowLen, varargin{:});

    if mod(windowLen, 2) == 0
        error('sphynx:smoothTrace:windowEven', ...
            'windowLen must be odd; got %d', windowLen);
    end
    if windowLen < 3
        error('sphynx:smoothTrace:windowTooSmall', ...
            'windowLen must be >= 3; got %d', windowLen);
    end

    trace = trace(:);
    n = numel(trace);
    if n < windowLen
        out = trace;
        return;
    end

    polyOrder = min(p.Results.PolyOrder, windowLen - 1);
    halfPad = (windowLen - 1) / 2;

    % Mirror-pad: reflect the first/last halfPad samples around the
    % first/last actual sample.
    padFront = 2*trace(1)   - trace(halfPad+1 : -1 : 2);
    padBack  = 2*trace(end) - trace(end-1 : -1 : end-halfPad);
    padded = [padFront; trace; padBack];

    smoothed = smooth(padded, windowLen, 'sgolay', polyOrder);

    out = smoothed(halfPad+1 : halfPad+n);
end
```

- [ ] **Step 4: Run test**

```matlab
runtests('tests/+unit/smoothTraceTest.m')
```

Expected: 6 PASSED. If `testLinearTrendPreserved` fails with > 0.05 error, the mirror-padding may need tweaking — report which assertion failed.

- [ ] **Step 5: Commit**

```bash
git add "+sphynx/+preprocess/smoothTrace.m" tests/+unit/smoothTraceTest.m
git commit -m "$(cat <<'EOF'
feat(preprocess): smoothTrace — Bug-3 fix

Edge-aware Savitzky-Golay smoothing using mirror-padding to
prevent the inflated edge values seen in legacy smooth(...,'sgolay').

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task A.3.2 — `sphynx.preprocess.computeVelocity`

**Files:**
- Create: `+sphynx/+preprocess/computeVelocity.m`
- Test:   `tests/+unit/computeVelocityTest.m`

- [ ] **Step 1: Write the test**

Create `tests/+unit/computeVelocityTest.m`:

```matlab
function tests = computeVelocityTest
    tests = functiontests(localfunctions);
end

function testStationaryYieldsZero(testCase)
    x = ones(100,1) * 50;
    y = ones(100,1) * 50;
    v = sphynx.preprocess.computeVelocity(x, y, 30, 5, 'MaxVelocityCmS', 50, 'SmoothWindow', 11);
    verifyEqual(testCase, max(v), 0, 'AbsTol', 1e-9);
end

function testUniformMotion(testCase)
    % Mouse moves 1 cm per frame at 30 fps -> 30 cm/s
    n = 200;
    pxlPerCm = 5;
    x = (1:n)' * pxlPerCm;  % 1 cm per frame in pxl
    y = ones(n,1) * 100;
    v = sphynx.preprocess.computeVelocity(x, y, 30, pxlPerCm, ...
        'MaxVelocityCmS', 50, 'SmoothWindow', 11);
    % Skip first/last few frames (smoothing transient)
    coreV = v(20:end-20);
    verifyEqual(testCase, mean(coreV), 30, 'AbsTol', 1);
end

function testOutlierIsClipped(testCase)
    % Walking at 10 cm/s plus one giant spike
    n = 200;
    pxlPerCm = 5;
    x = (1:n)' * pxlPerCm * 10/30;  % 10 cm/s
    y = ones(n,1) * 100;
    x(100) = x(100) + 200 * pxlPerCm;  % 200 cm jump in 1 frame -> 6000 cm/s raw
    v = sphynx.preprocess.computeVelocity(x, y, 30, pxlPerCm, ...
        'MaxVelocityCmS', 50, 'SmoothWindow', 11);
    verifyLessThanOrEqual(testCase, max(v), 50, ...
        'Bug-4: velocity must be clipped to MaxVelocityCmS');
end

function testRequiredArgs(testCase)
    verifyError(testCase, @() sphynx.preprocess.computeVelocity([1;2],[1;2],30,0), ...
        'MATLAB:expectedPositive');
end
```

- [ ] **Step 2: Run, verify fail**

```matlab
runtests('tests/+unit/computeVelocityTest.m')
```

Expected: 4 FAIL.

- [ ] **Step 3: Implement**

Create `+sphynx/+preprocess/computeVelocity.m`:

```matlab
function v = computeVelocity(x, y, frameRate, pxlPerCm, varargin)
% COMPUTEVELOCITY  Velocity from position trace, clipped + smoothed.
%
%   v = sphynx.preprocess.computeVelocity(x, y, frameRate, pxlPerCm, ...)
%
%   Inputs:
%     x, y        — N×1 position traces (pixels)
%     frameRate   — Hz
%     pxlPerCm    — calibration scale
%
%   Name-value:
%     'MaxVelocityCmS' — biological clipping cap (default 50)
%     'SmoothWindow'   — sgolay window length (default 11, must be odd)
%
%   Output:
%     v — N×1 velocity in cm/s
%
%   Bug-4 fix: per-frame velocity > MaxVelocityCmS is replaced with
%   NaN, then linearly interpolated, then smoothed. This prevents
%   single-frame DLC outliers from leaking through to the smoothed
%   trace.
%
%   Bug-3 partial fix: smoothing is delegated to sphynx.preprocess.smoothTrace
%   which handles edges with mirror-padding.

    p = inputParser;
    addRequired(p, 'x');
    addRequired(p, 'y');
    addRequired(p, 'frameRate', @(v) isnumeric(v) && v > 0);
    addRequired(p, 'pxlPerCm', @(v) validateattributes(v, {'numeric'}, {'positive'}));
    addParameter(p, 'MaxVelocityCmS', 50, @(v) isnumeric(v) && v > 0);
    addParameter(p, 'SmoothWindow', 11, @(v) isnumeric(v) && v >= 3 && mod(v,2)==1);
    parse(p, x, y, frameRate, pxlPerCm, varargin{:});

    x = x(:); y = y(:);
    n = numel(x);

    dx = [0; diff(x)];
    dy = [0; diff(y)];

    rawV = sqrt(dx.^2 + dy.^2) * frameRate / pxlPerCm;  % cm/s per frame

    % Clip outliers
    bad = rawV > p.Results.MaxVelocityCmS;
    cleanedV = rawV;
    cleanedV(bad) = NaN;

    % Linear interpolate over NaN gaps
    if any(isnan(cleanedV))
        good = ~isnan(cleanedV);
        if any(good)
            idx = (1:n)';
            cleanedV(~good) = interp1(idx(good), cleanedV(good), idx(~good), 'linear', 'extrap');
        else
            cleanedV(:) = 0;
        end
    end

    % Cap any extrapolated outliers (paranoia)
    cleanedV(cleanedV > p.Results.MaxVelocityCmS) = p.Results.MaxVelocityCmS;
    cleanedV(cleanedV < 0) = 0;

    % Smooth with edge-aware sgolay
    v = sphynx.preprocess.smoothTrace(cleanedV, p.Results.SmoothWindow);

    % Final cap (smoothing can over- or under-shoot slightly)
    v(v > p.Results.MaxVelocityCmS) = p.Results.MaxVelocityCmS;
    v(v < 0) = 0;
end
```

- [ ] **Step 4: Run test**

```matlab
runtests('tests/+unit/computeVelocityTest.m')
```

Expected: 4 PASSED.

- [ ] **Step 5: Commit**

```bash
git add "+sphynx/+preprocess/computeVelocity.m" tests/+unit/computeVelocityTest.m
git commit -m "$(cat <<'EOF'
feat(preprocess): computeVelocity — Bug-4 clip + Bug-3 edge-aware

Velocity computed from positions, with single-frame outliers
above MaxVelocityCmS (default 50) replaced by NaN and linearly
interpolated, then smoothed via smoothTrace (mirror-padded).

Bug-4: outliers no longer leak through the smoother.
Bug-3 (partial): smoothing delegated to edge-aware smoothTrace.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task A.3.3 — Synthetic tests: velocity clipping + edge smoothing

**Files:**
- Create: `+sphynx/+testing/makeWalkingDLC.m`
- Create: `+sphynx/+testing/makeJumpyDLC.m`
- Create: `tests/+synthetic/velocityClippingTest.m`
- Create: `tests/+synthetic/edgeSmoothingTest.m`

- [ ] **Step 1: Implement walking fixture**

Create `+sphynx/+testing/makeWalkingDLC.m`:

```matlab
function fixture = makeWalkingDLC(speedCmS, durationS, varargin)
% MAKEWALKINGDLC  Synthetic mouse walking in a straight line.
%
%   fixture = sphynx.testing.makeWalkingDLC(speedCmS, durationS)
%
%   Outputs:
%     x, y         — N×1 traces (pixels)
%     frameRate    — Hz
%     pxlPerCm     — calibration
%     n_frames

    p = inputParser;
    addParameter(p, 'FrameRate', 30, @(v) isnumeric(v) && v > 0);
    addParameter(p, 'PixelsPerCm', 5, @(v) isnumeric(v) && v > 0);
    parse(p, varargin{:});
    fr = p.Results.FrameRate;
    ppc = p.Results.PixelsPerCm;

    n = round(durationS * fr);
    pxlPerFrame = speedCmS / fr * ppc;
    fixture.x = 100 + (0:n-1)' * pxlPerFrame;
    fixture.y = ones(n, 1) * 100;
    fixture.frameRate = fr;
    fixture.pxlPerCm = ppc;
    fixture.n_frames = n;
    fixture.expectedSpeedCmS = speedCmS;
end
```

- [ ] **Step 2: Implement jumpy fixture**

Create `+sphynx/+testing/makeJumpyDLC.m`:

```matlab
function fixture = makeJumpyDLC(spikeFrame, spikeMagnitudePxl, varargin)
% MAKEJUMPYDLC  Walking trace with one DLC-style spike.
%
%   fixture = sphynx.testing.makeJumpyDLC(spikeFrame, spikePxl, ...)
%
%   Returns a 200-frame walking trace (10 cm/s) with x(spikeFrame)
%   shifted by spikeMagnitudePxl, simulating a DLC tracking outlier.

    p = inputParser;
    addParameter(p, 'BaseSpeedCmS', 10);
    addParameter(p, 'NFrames', 200);
    addParameter(p, 'FrameRate', 30);
    addParameter(p, 'PixelsPerCm', 5);
    parse(p, varargin{:});

    f = sphynx.testing.makeWalkingDLC(p.Results.BaseSpeedCmS, ...
        p.Results.NFrames / p.Results.FrameRate, ...
        'FrameRate', p.Results.FrameRate, 'PixelsPerCm', p.Results.PixelsPerCm);
    f.x(spikeFrame) = f.x(spikeFrame) + spikeMagnitudePxl;
    f.spikeFrame = spikeFrame;
    f.spikeMagnitudePxl = spikeMagnitudePxl;
    fixture = f;
end
```

- [ ] **Step 3: Write velocityClippingTest**

Create `tests/+synthetic/velocityClippingTest.m`:

```matlab
function tests = velocityClippingTest
% VELOCITYCLIPPINGTEST  DLC outlier must be clipped to <= 50 cm/s.
    tests = functiontests(localfunctions);
end

function testSingleSpikeIsClipped(testCase)
    f = sphynx.testing.makeJumpyDLC(100, 1000); % 200 cm jump in 1 frame
    v = sphynx.preprocess.computeVelocity(f.x, f.y, f.frameRate, f.pxlPerCm, ...
        'MaxVelocityCmS', 50, 'SmoothWindow', 11);
    verifyLessThanOrEqual(testCase, max(v), 50, ...
        'Bug-4: spike survived clipping');
end

function testWalkingSpeedRecovered(testCase)
    f = sphynx.testing.makeJumpyDLC(100, 1000);
    v = sphynx.preprocess.computeVelocity(f.x, f.y, f.frameRate, f.pxlPerCm, ...
        'MaxVelocityCmS', 50, 'SmoothWindow', 11);
    coreV = v(20:end-20); % skip transients near edges and spike
    verifyEqual(testCase, mean(coreV), 10, 'AbsTol', 2);
end
```

- [ ] **Step 4: Write edgeSmoothingTest**

Create `tests/+synthetic/edgeSmoothingTest.m`:

```matlab
function tests = edgeSmoothingTest
% EDGESMOOTHINGTEST  Constant signal must remain constant at edges.
%   Also: linear trend stays linear at edges.
    tests = functiontests(localfunctions);
end

function testConstantSpeedAtEdges(testCase)
    f = sphynx.testing.makeWalkingDLC(15, 5); % 15 cm/s for 5 s
    v = sphynx.preprocess.computeVelocity(f.x, f.y, f.frameRate, f.pxlPerCm, ...
        'MaxVelocityCmS', 50, 'SmoothWindow', 11);
    % After the first ~5 frames (where diff(x) startup transient
    % settles), velocity should be ~15 cm/s including very near the end.
    verifyEqual(testCase, mean(v(end-10:end)), 15, 'AbsTol', 1, ...
        'Bug-3: speed at trace end deviates due to edge smoothing artifact');
end

function testFlatTraceStaysFlat(testCase)
    n = 200;
    x = ones(n,1) * 100;
    y = ones(n,1) * 100;
    v = sphynx.preprocess.computeVelocity(x, y, 30, 5, ...
        'MaxVelocityCmS', 50, 'SmoothWindow', 11);
    verifyEqual(testCase, max(v), 0, 'AbsTol', 1e-6);
end
```

- [ ] **Step 5: Run tests, verify pass**

```matlab
runtests('tests/+synthetic/velocityClippingTest.m')
runtests('tests/+synthetic/edgeSmoothingTest.m')
```

Expected: 2 + 2 = 4 PASSED.

- [ ] **Step 6: Commit**

```bash
git add "+sphynx/+testing/makeWalkingDLC.m" "+sphynx/+testing/makeJumpyDLC.m" tests/+synthetic/velocityClippingTest.m tests/+synthetic/edgeSmoothingTest.m
git commit -m "$(cat <<'EOF'
test(synthetic): velocity clipping + edge smoothing (Bug-3, Bug-4)

velocityClippingTest — DLC spike of 200 cm in 1 frame; verify
v stays <= 50 cm/s and walking baseline (10 cm/s) is recovered.

edgeSmoothingTest — constant 15 cm/s walk; verify edges stay
flat instead of inflating per legacy edge artifact.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task A.3.4 — Pass A.3 final + tag

- [ ] **Step 1: Run fast suite**

```matlab
runAllTests('tag','fast')
```

Expected: ~46 tests, all green (or 1 skipped).

- [ ] **Step 2: Tag**

```bash
git tag stage-c-pass-A-bugs-fixed
```

- [ ] **Step 3: Homework**: user reports outcome.

After Pass A is green, the next plan (`2026-04-27-sphynx-stage-c-pass-B.md`) covers slices 4–6 (body parts, acts, pipeline integration with golden baseline).

---

# Self-review summary

**Spec coverage:**
- Bug-1 (zone at frame edge) — Tasks A.1.3, A.1.5, A.1.6, A.1.7, A.1.8 ✓
- Bug-2 (angle wrap)         — Tasks A.2.1, A.2.2, A.2.3, A.2.4 ✓
- Bug-3 (edge smoothing)     — Tasks A.3.1, A.3.3 ✓
- Bug-4 (velocity clipping)  — Tasks A.3.2, A.3.3 ✓
- Feature 1.3 (zones)        — Tasks A.1.4, A.1.5, A.1.6 ✓
- Test infra (matlab.unittest, runAllTests, golden, smoke) — Tasks 0.5, 0.6, 0.7 ✓
- `+sphynx/` package layout   — Tasks 0.2 (skeleton), and slices A.1–A.3 populate util/zones/angles/preprocess/testing ✓
- `functions/*.m` migration policy (audit + bring + test) — Tasks A.1.1 (circleFit), A.1.2 (polygonFit) ✓; full inventory continues in Pass B
- Branch `sphynx-GUI`         — Task 0.1 ✓
- Compute/viz/io separation rule — enforced (no `figure`, no `save`, no `VideoReader` in any new file) ✓

**Out of plan, deferred to Pass B:**
- Body parts identification (slice 4)
- Acts detectors (slice 5)
- Pipeline integration `analyzeSession` (slice 6)
- Golden regression test bodies (currently snapshot exists; comparison logic in Pass B)
- Smoke test body (currently placeholder)

**Tasks numbered:** 0.1–0.9, A.1.1–A.1.9, A.2.1–A.2.5, A.3.1–A.3.4 (24 tasks total).

**Tag points:** `stage-c-pass-0-complete`, `stage-c-pass-A1-zones-fixed`, `stage-c-pass-A2-angles-fixed`, `stage-c-pass-A-bugs-fixed`.
