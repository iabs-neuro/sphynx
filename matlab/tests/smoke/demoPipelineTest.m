function tests = demoPipelineTest
% DEMOPIPELINETEST  End-to-end smoke test on Demo/NOF_H01_1D.
%   Runs sphynx.pipeline.analyzeSession against the Demo fixture and
%   verifies the result struct has the expected shape and basic
%   sanity properties (partition, velocity clip).
    tests = functiontests(localfunctions);
end

function testNOF_H01_1D_runsWithoutError(testCase)
    repo = sphynx.util.repoRoot();
    cfg = sphynx.pipeline.defaultConfig();
    cfg.paths.dlc = fullfile(repo, 'Demo', 'DLC', ...
        'NOF_H01_1DDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv');
    cfg.paths.preset = fullfile(repo, 'Demo', 'Preset', 'NOF_H01_1D_Preset.mat');
    cfg.io.saveWorkspace = false;
    cfg.viz.headless = true;
    cfg.viz.makeVideo = false;
    cfg.verbose = 'warn';

    result = sphynx.pipeline.analyzeSession(cfg);

    verifyClass(testCase, result, 'struct');
    verifyTrue(testCase, isfield(result, 'Acts'));
    verifyTrue(testCase, isfield(result, 'BodyPartsTraces'));
    verifyTrue(testCase, isfield(result, 'Point'));
    verifyTrue(testCase, isfield(result, 'Options'));
    verifyTrue(testCase, isfield(result, 'Zones'));
    verifyGreaterThan(testCase, numel(result.Acts), 0);
    verifyGreaterThan(testCase, result.n_frames, 0);

    % Sanity: rest + walk + locomotion must partition every frame
    actNames = {result.Acts.ActName};
    rIdx = find(strcmp(actNames, 'rest'), 1);
    wIdx = find(strcmp(actNames, 'walk'), 1);
    lIdx = find(strcmp(actNames, 'locomotion'), 1);
    if ~isempty(rIdx) && ~isempty(wIdx) && ~isempty(lIdx)
        partition = result.Acts(rIdx).ActArrayRefine + ...
                    result.Acts(wIdx).ActArrayRefine + ...
                    result.Acts(lIdx).ActArrayRefine;
        verifyEqual(testCase, sum(partition == 1), result.n_frames, ...
            'rest+walk+locomotion must partition every frame');
    end

    % Velocity must respect the biological clip (Bug-4 fix)
    for k = 1:numel(result.BodyPartsTraces)
        v = result.BodyPartsTraces(k).VelocitySmoothed;
        if ~isempty(v)
            verifyLessThanOrEqual(testCase, max(v), cfg.preprocess.maxVelocityCmS + 1e-6);
        end
    end
end
