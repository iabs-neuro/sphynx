function tests = actsLibraryEndToEndTest
% End-to-end check: build a custom acts library, save it, run
% analyzeSession with cfg.acts.libraryPath pointing at it, and confirm
% the result struct has the custom acts on top of the built-ins.
    tests = functiontests(localfunctions);
end

function testCustomActsAppendedToResult(testCase)
    repo = sphynx.util.repoRoot();
    dlcPath = fullfile(repo, 'Demo', 'DLC', ...
        'NOF_H01_1DDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv');
    presetPath = fullfile(repo, 'Demo', 'Preset', 'NOF_H01_1D_Preset.mat');
    assumeTrue(testCase, isfile(dlcPath));
    assumeTrue(testCase, isfile(presetPath));

    % Build a 3-act library: one simple, one complex
    acts = sphynx.acts.emptyActsArray();
    acts(end+1) = sphynx.acts.buildSimpleAct( ...
        'Name', 'fast_movement', 'BodyPart', 'bodycenter', ...
        'SpeedMin', 10, 'SpeedMax', Inf);
    acts(end+1) = sphynx.acts.buildSimpleAct( ...
        'Name', 'slow_movement', 'BodyPart', 'bodycenter', ...
        'SpeedMin', 0, 'SpeedMax', 2);
    acts(end+1) = sphynx.acts.buildComplexAct( ...
        'Name', 'slow_or_fast', 'Components', {'fast_movement', 'slow_movement'}, ...
        'Operation', 'union');

    tmp = tempname(); mkdir(tmp);
    cleaner = onCleanup(@() rmdir(tmp, 's'));
    libraryPath = fullfile(tmp, 'acts.mat');
    sphynx.io.saveActsSet(libraryPath, acts, 'Novelty OF');

    cfg = sphynx.pipeline.defaultConfig();
    cfg.paths.dlc = dlcPath;
    cfg.paths.preset = presetPath;
    cfg.acts.libraryPath = libraryPath;
    cfg.io.saveWorkspace = false;
    cfg.viz.headless = true;
    cfg.verbose = 'warn';

    result = sphynx.pipeline.analyzeSession(cfg);

    actNames = {result.Acts.ActName};
    verifyTrue(testCase, any(strcmp(actNames, 'fast_movement')));
    verifyTrue(testCase, any(strcmp(actNames, 'slow_movement')));
    verifyTrue(testCase, any(strcmp(actNames, 'slow_or_fast')));

    % Built-ins should still be there
    verifyTrue(testCase, any(strcmp(actNames, 'rest')));
    verifyTrue(testCase, any(strcmp(actNames, 'walk')));
    verifyTrue(testCase, any(strcmp(actNames, 'locomotion')));
end

function testEmptyLibraryPathFallsBackToBuiltins(testCase)
    repo = sphynx.util.repoRoot();
    dlcPath = fullfile(repo, 'Demo', 'DLC', ...
        'NOF_H01_1DDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv');
    presetPath = fullfile(repo, 'Demo', 'Preset', 'NOF_H01_1D_Preset.mat');
    assumeTrue(testCase, isfile(dlcPath));
    assumeTrue(testCase, isfile(presetPath));

    cfg = sphynx.pipeline.defaultConfig();
    cfg.paths.dlc = dlcPath;
    cfg.paths.preset = presetPath;
    % cfg.acts.libraryPath defaults to ''
    cfg.io.saveWorkspace = false;
    cfg.viz.headless = true;
    cfg.verbose = 'warn';

    result = sphynx.pipeline.analyzeSession(cfg);
    actNames = {result.Acts.ActName};
    verifyTrue(testCase, any(strcmp(actNames, 'rest')));
    verifyTrue(testCase, any(strcmp(actNames, 'walk')));
end
