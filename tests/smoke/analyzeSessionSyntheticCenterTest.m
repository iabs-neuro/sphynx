function tests = analyzeSessionSyntheticCenterTest
% ANALYZESESSIONSYNTHETICCENTERTEST  R31 audit #1 (HIGH) and #3.
%   #1: when identifyParts resolves a head part but no body center,
%       analyzeSession synthesizes a center. Pre-fix, freezing() then
%       indexed a velocity row (Point.Center) that did not exist in BPV,
%       throwing "Index exceeds array elements" and aborting the run.
%   #3: the synthesized center must carry its own velocity trace so
%       per-act velocity/distance stats use it, not the last body part.
    tests = functiontests(localfunctions);
end

function testNoCrashWhenCenterIsSynthesized(testCase)
    presetPath = fullfile(sphynx.util.repoRoot(), 'Demo', 'Preset', ...
        'NOF_H01_1D_Preset.mat');
    assumeTrue(testCase, isfile(presetPath));

    csv = writeSyntheticNoCenterDLC();
    cleaner = onCleanup(@() cleanupDir(fileparts(csv))); %#ok<NASGU>

    result = runIt(csv, presetPath);

    verifyClass(testCase, result, 'struct');
    verifyGreaterThan(testCase, result.n_frames, 0);
    verifyTrue(testCase, any(strcmp({result.Acts.ActName}, 'freezing')), ...
        'built-in freezing act must be present after a synthetic-center run');
end

function testSyntheticCenterHasOwnTrace(testCase)
    presetPath = fullfile(sphynx.util.repoRoot(), 'Demo', 'Preset', ...
        'NOF_H01_1D_Preset.mat');
    assumeTrue(testCase, isfile(presetPath));

    csv = writeSyntheticNoCenterDLC();
    cleaner = onCleanup(@() cleanupDir(fileparts(csv))); %#ok<NASGU>

    result = runIt(csv, presetPath);

    % Point.Center must index a real trace row (the synthesized center),
    % so line-393 per-act velocity picks the center, not BodyPartsTraces(end).
    verifyEmpty(testCase, ...
        sphynx.bodyparts.identifyParts(result.bodyPartsNames).Center, ...
        'test schema must have no native center part');
    verifyGreaterThanOrEqual(testCase, numel(result.BodyPartsTraces), ...
        result.Point.Center);
    verifyEqual(testCase, ...
        result.BodyPartsTraces(result.Point.Center).BodyPartName, ...
        'synthetic_center');
end

% --- helpers -------------------------------------------------------------

function result = runIt(csv, presetPath)
    cfg = sphynx.pipeline.defaultConfig();
    cfg.paths.dlc = csv;
    cfg.paths.preset = presetPath;
    cfg.io.saveWorkspace = false;
    cfg.viz.headless = true;
    cfg.viz.makeVideo = false;
    cfg.verbose = 'error';
    result = sphynx.pipeline.analyzeSession(cfg);
end

function csv = writeSyntheticNoCenterDLC()
    d = tempname; mkdir(d);
    csv = fullfile(d, 'synthetic_nocenter.csv');
    % 'neck' -> HeadCenter; no center synonym and not both left+right body
    % -> analyzeSession must synthesize the center.
    sphynx.preprocess.makeSyntheticDLC( ...
        'BodyParts', {'nose', 'neck', 'tailbase', 'leftforelimb', 'rightforelimb'}, ...
        'OutlierMode', 'none', 'NFrames', 300, 'Seed', 7, 'CsvPath', csv);
end

function cleanupDir(d)
    if isfolder(d); rmdir(d, 's'); end
end
