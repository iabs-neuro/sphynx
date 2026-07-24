function tests = readDefaultsJsoncTest
% READDEFAULTSJSONCTEST  Coverage for the jsonc loader + override
%   merge: comment stripping, missing-file resilience, mapping of
%   tab-shaped jsonc onto flat cfg.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testCase.TestData.tmp = tempname;
    mkdir(testCase.TestData.tmp);
end

function teardownOnce(testCase)
    rmdir(testCase.TestData.tmp, 's');
end

function testStripsLineAndBlockComments(testCase)
    p = fullfile(testCase.TestData.tmp, 'a.jsonc');
    writeText(p, [...
        '// header line', newline, ...
        '{', newline, ...
        '  "k": 42, // inline tail', newline, ...
        '  /* block', newline, ...
        '     spans lines */ "m": "ok"', newline, ...
        '}', newline]);
    out = sphynx.io.readDefaultsJsonc(p);
    verifyEqual(testCase, out.k, 42);
    verifyEqual(testCase, out.m, 'ok');
end

function testMissingFileReturnsEmpty(testCase)
    out = sphynx.io.readDefaultsJsonc(fullfile(testCase.TestData.tmp, 'nope.jsonc'));
    verifyEmpty(testCase, out);
end

function testApplyJsoncDefaultsMergesPipelineBlocks(testCase)
    cfg = sphynx.pipeline.defaultConfig();
    j = struct();
    j.range.startFrame = 50;
    j.range.endFrame   = 100;
    j.range.autoStart  = true;
    j.verbose          = 'warn';
    j.io.saveWorkspace = false;
    j.viz.headless     = false;
    out = sphynx.pipeline.applyJsoncDefaults(cfg, j);
    verifyEqual(testCase, out.range.startFrame, 50);
    verifyEqual(testCase, out.range.endFrame, 100);
    verifyTrue(testCase, out.range.autoStart);
    verifyEqual(testCase, out.verbose, 'warn');
    verifyFalse(testCase, out.io.saveWorkspace);
    verifyFalse(testCase, out.viz.headless);
end

function testApplyJsoncDefaultsMapsPreprocessTab(testCase)
    cfg = sphynx.pipeline.defaultConfig();
    j = struct();
    j.preprocessTab.individual           = 'animal3';
    j.preprocessTab.likelihoodThreshold  = 0.5;
    j.preprocessTab.smoothWindowSmallSec = 0.2;
    j.preprocessTab.maxVelocityCmS       = 80;
    j.preprocessTab.interpolationMethod  = 'linear';
    j.preprocessTab.perPart.smoothingMethod    = 'gaussian';
    j.preprocessTab.perPart.smoothingPolyOrder = 4;
    j.preprocessTab.perPart.notFoundThresholdPct = 80;
    out = sphynx.pipeline.applyJsoncDefaults(cfg, j);
    verifyEqual(testCase, out.preprocess.individual,            'animal3');
    verifyEqual(testCase, out.preprocess.likelihoodThreshold,   0.5);
    verifyEqual(testCase, out.preprocess.smoothWindowSmallSec,  0.2);
    verifyEqual(testCase, out.preprocess.maxVelocityCmS,        80);
    verifyEqual(testCase, out.preprocess.interpolationMethod,   'linear');
    verifyEqual(testCase, out.preprocess.perPart.smoothingMethod,    'gaussian');
    verifyEqual(testCase, out.preprocess.perPart.smoothingPolyOrder, 4);
    verifyEqual(testCase, out.preprocess.perPart.notFoundThresholdPct, 80);
end

function testApplyJsoncDefaultsMapsDefineActs(testCase)
    cfg = sphynx.pipeline.defaultConfig();
    j = struct();
    j.defineActs.restThresholdCmS              = 2;
    j.defineActs.locThresholdCmS               = 7;
    j.defineActs.freezingMode                  = 'AllBodyParts';
    j.defineActs.rearMode                      = 'AllBodyParts';
    j.defineActs.rearThresholdAllBodyPartsPxl  = 200;
    j.defineActs.rearAutoThreshold             = false;
    out = sphynx.pipeline.applyJsoncDefaults(cfg, j);
    verifyEqual(testCase, out.acts.restThresholdCmS,             2);
    verifyEqual(testCase, out.acts.locThresholdCmS,              7);
    verifyEqual(testCase, out.acts.freezingMode,                 'AllBodyParts');
    verifyEqual(testCase, out.acts.rearMode,                     'AllBodyParts');
    verifyEqual(testCase, out.acts.rearThresholdAllBodyPartsPxl, 200);
    verifyFalse(testCase, out.acts.rearAutoThreshold);
end

function testEmptyJsoncStructLeavesCfgUntouched(testCase)
    cfg = sphynx.pipeline.defaultConfig();
    out = sphynx.pipeline.applyJsoncDefaults(cfg, struct());
    verifyEqual(testCase, out.acts.restThresholdCmS, cfg.acts.restThresholdCmS);
    verifyEqual(testCase, out.preprocess.likelihoodThreshold, ...
        cfg.preprocess.likelihoodThreshold);
end

function testRepoRootJsoncParsesOk(testCase)
    % End-to-end: the actual repo-root file must load and merge
    % without error -- catches a broken comment or trailing comma
    % before it bites a user mid-run.
    repo = sphynx.util.repoRoot();
    p = fullfile(repo, 'sphynx_defaults.jsonc');
    assumeTrue(testCase, isfile(p), 'sphynx_defaults.jsonc not in repo root');
    j = sphynx.io.readDefaultsJsonc(p);
    verifyNotEmpty(testCase, j);
    verifyTrue(testCase, isfield(j, 'preprocessTab'));
    verifyTrue(testCase, isfield(j, 'defineActs'));

    cfg = sphynx.pipeline.defaultConfig();
    out = sphynx.pipeline.applyJsoncDefaults(cfg, j);
    verifyTrue(testCase, isstruct(out));
    verifyTrue(testCase, isfield(out, 'preprocess'));
end

% --- helpers --------------------------------------------------------
function writeText(path, txt)
    fid = fopen(path, 'w');
    cleaner = onCleanup(@() fclose(fid));
    fwrite(fid, txt);
end
