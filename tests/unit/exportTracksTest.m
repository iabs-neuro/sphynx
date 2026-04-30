function tests = exportTracksTest
% EXPORTTRACKSTEST  Round-trip writes for sphynx.preprocess.exportTracks.
    tests = functiontests(localfunctions);
end

function testWritesSettingsAndSession(testCase)
    tmp = tempname();
    mkdir(tmp);
    cleaner = onCleanup(@() rmdir(tmp, 's'));

    % Synthetic state
    n = 200;
    state.dlc.X = [linspace(50, 100, n); linspace(60, 110, n)];
    state.dlc.Y = [linspace(50, 100, n); linspace(60, 110, n)];
    state.dlc.likelihood = ones(2, n) * 0.99;
    state.dlc.bodyPartsNames = {'nose', 'tailbase'};
    state.dlc.nFrames = n;
    state.paths.root = '';
    state.paths.dlc = fullfile(tmp, 'fake.csv');
    state.paths.video = '';
    state.paths.preset = '';

    cfg = sphynx.pipeline.defaultConfig();
    state.perPart = struct('name', {'nose', 'tailbase'}, 'use', {true, true}, ...
        'likelihoodThreshold', {0.95, 0.95}, ...
        'smoothWindowSec', {0.10, 0.25}, ...
        'interpolationMethod', {'pchip', 'pchip'}, ...
        'smoothingMethod', {'sgolay', 'sgolay'}, ...
        'smoothingPolyOrder', {3, 3}, ...
        'notFoundThresholdPct', {90, 90});

    state.outlier.velocityJump.enabled = true;
    state.outlier.velocityJump.maxVelocityCmS = 50;
    state.outlier.hampel.enabled = false;
    state.outlier.hampel.windowSize = 7;
    state.outlier.hampel.nSigma = 3;
    state.outlier.kalman.processNoise = 1e-2;
    state.outlier.kalman.measNoiseScale = 1.0;

    state.manualRegions = struct('vertices', {[10 10; 50 10; 50 50; 10 50]}, ...
                                 'appliesTo', {'all'});

    % Run a real compute to populate state.processed
    ctx = struct('frameWidth', 800, 'frameHeight', 600, 'frameRate', 30);
    state.processed = struct('X_clean', {}, 'Y_clean', {}, ...
        'X_interp', {}, 'Y_interp', {}, 'X_smooth', {}, 'Y_smooth', {}, ...
        'percentNaN', {}, 'percentLowLikelihood', {}, ...
        'percentBadCombined', {}, 'percentOutliers', {}, 'status', {});
    for k = 1:2
        state.processed(k) = sphynx.preprocess.applyPerPartSettings( ...
            state.dlc.X(k, :)', state.dlc.Y(k, :)', state.dlc.likelihood(k, :)', ...
            state.perPart(k), ctx);
    end

    opts = struct('outputDir', tmp, 'savePlots', false, 'experimentName', 'demoExp');
    paths = sphynx.preprocess.exportTracks(state, opts);

    % Settings file
    verifyTrue(testCase, isfile(paths.settings));
    Settings = sphynx.io.readTracksSettings(paths.settings);
    verifyEqual(testCase, numel(Settings.bodyparts), 2);
    verifyEqual(testCase, Settings.outlier.velocityJump.maxVelocityCmS, 50);

    % Session file
    verifyTrue(testCase, isfile(paths.session));
    s = load(paths.session);
    verifyTrue(testCase, isfield(s, 'BodyPartsTraces'));
    verifyEqual(testCase, numel(s.BodyPartsTraces), 2);
    verifyEqual(testCase, s.BodyPartsTraces(1).BodyPartName, 'nose');
    verifyTrue(testCase, isfield(s, 'ManualExclusionRegions'));
    verifyEqual(testCase, numel(s.ManualExclusionRegions), 1);
end

function testSavePlotsCreatesPNG(testCase)
    tmp = tempname();
    mkdir(tmp);
    cleaner = onCleanup(@() rmdir(tmp, 's'));

    n = 100;
    state.dlc.X = linspace(50, 100, n);
    state.dlc.Y = linspace(60, 110, n);
    state.dlc.likelihood = ones(1, n) * 0.99;
    state.dlc.bodyPartsNames = {'nose'};
    state.dlc.nFrames = n;
    state.paths.root = '';
    state.paths.dlc = fullfile(tmp, 'fake.csv');
    state.paths.video = '';
    state.paths.preset = '';

    state.perPart = struct('name', {'nose'}, 'use', {true}, ...
        'likelihoodThreshold', {0.95}, 'smoothWindowSec', {0.10}, ...
        'interpolationMethod', {'pchip'}, 'smoothingMethod', {'sgolay'}, ...
        'smoothingPolyOrder', {3}, 'notFoundThresholdPct', {90});

    state.outlier.velocityJump.enabled = false;
    state.outlier.velocityJump.maxVelocityCmS = 50;
    state.outlier.hampel.enabled = false;
    state.outlier.hampel.windowSize = 7;
    state.outlier.hampel.nSigma = 3;
    state.outlier.kalman.processNoise = 1e-2;
    state.outlier.kalman.measNoiseScale = 1.0;

    state.manualRegions = struct('vertices', {}, 'appliesTo', {});

    ctx = struct('frameWidth', 800, 'frameHeight', 600, 'frameRate', 30);
    state.processed(1) = sphynx.preprocess.applyPerPartSettings( ...
        state.dlc.X', state.dlc.Y', state.dlc.likelihood', ...
        state.perPart(1), ctx);

    opts = struct('outputDir', tmp, 'savePlots', true, 'experimentName', 'e');
    paths = sphynx.preprocess.exportTracks(state, opts);
    verifyTrue(testCase, isfolder(paths.plotsDir));
    verifyTrue(testCase, isfile(fullfile(paths.plotsDir, 'nose.png')));
end
