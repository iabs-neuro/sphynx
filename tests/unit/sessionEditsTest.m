function tests = sessionEditsTest
% SESSIONEDITSTEST  Reading <exp>_SessionEdits.csv and the act-percent
% denominator that excludes time off the arena.
    tests = functiontests(localfunctions);
end

function setup(testCase)
    testCase.TestData.dir = tempname;
    mkdir(testCase.TestData.dir);
    dlcDir = fullfile(testCase.TestData.dir, '3_DLC');
    mkdir(dlcDir);
    testCase.TestData.dlc = fullfile(dlcDir, 'EXP_M01_1DDLC_model.csv');
    fid = fopen(fullfile(testCase.TestData.dir, 'EXP_SessionEdits.csv'), 'w');
    fprintf(fid, 'session,kind,start_s,end_s,source,note\n');
    fprintf(fid, 'EXP_M01_1D,trim,600,,user,timer\n');
    fprintf(fid, 'EXP_M01_1D,outside,10.5,20,user,escape\n');
    fprintf(fid, 'EXP_M02_1D,outside,1,2,auto,\n');
    fclose(fid);
end

function teardown(testCase)
    rmdir(testCase.TestData.dir, 's');
end

function testDiscoveredFromDlcFolder(testCase)
    cfg = sphynx.pipeline.defaultConfig();
    cfg.paths.dlc = testCase.TestData.dlc;
    [e, p] = sphynx.io.readSessionEdits(cfg, 'EXP_M01_1D');
    verifyEqual(testCase, height(e), 2);
    verifyTrue(testCase, endsWith(p, 'EXP_SessionEdits.csv'));
    verifyEqual(testCase, e.kind, {'trim'; 'outside'});
    verifyTrue(testCase, isnan(e.end_s(1)));
    verifyEqual(testCase, e.start_s(2), 10.5);
end

function testOtherSessionGetsNoRows(testCase)
    cfg = sphynx.pipeline.defaultConfig();
    cfg.paths.dlc = testCase.TestData.dlc;
    [e, p] = sphynx.io.readSessionEdits(cfg, 'EXP_M03_1D');
    verifyEqual(testCase, height(e), 0);
    verifyNotEmpty(testCase, p);
end

function testNoFileGivesEmpty(testCase)
    cfg = sphynx.pipeline.defaultConfig();
    cfg.paths.dlc = fullfile(tempdir, 'nowhere', 'X_DLC.csv');
    [e, p] = sphynx.io.readSessionEdits(cfg, 'X');
    verifyEmpty(testCase, e);
    verifyEmpty(testCase, p);
end

function testUnknownKindIsAnError(testCase)
    f = fullfile(testCase.TestData.dir, 'bad.csv');
    fid = fopen(f, 'w');
    fprintf(fid, 'session,kind,start_s,end_s\nS,cut,1,2\n');
    fclose(fid);
    cfg = sphynx.pipeline.defaultConfig();
    cfg.paths.sessionEdits = f;
    verifyError(testCase, @() sphynx.io.readSessionEdits(cfg, 'S'), 'sphynx:sessionEdits');
end

function testPercentOverValidFrames(testCase)
    % 30 of 100 frames active; 50 frames off the arena -> 60% of arena time.
    mask = false(100, 1); mask(1:30) = true;
    valid = true(100, 1); valid(51:100) = false;
    s = sphynx.acts.actStats(mask, 10, 'ValidMask', valid);
    verifyEqual(testCase, s.ActPercent, 60);
    verifyEqual(testCase, s.ActDuration, 3);
    s0 = sphynx.acts.actStats(mask, 10);
    verifyEqual(testCase, s0.ActPercent, 30);
end
