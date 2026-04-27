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
