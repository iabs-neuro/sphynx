function tests = analyzeSessionFastPathTest
% ANALYZESESSIONFASTPATHTEST  When a sibling _Preprocessed.mat exists,
% analyzeSession should consume it and skip clean/interp/smooth.
    tests = functiontests(localfunctions);
end

function testFastPathConsumesSavedTraces(testCase)
    repo = sphynx.util.repoRoot();
    dlcPath = fullfile(repo, 'Demo', 'DLC', ...
        'NOF_H01_1DDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv');
    presetPath = fullfile(repo, 'Demo', 'Preset', 'NOF_H01_1D_Preset.mat');
    assumeTrue(testCase, isfile(dlcPath));
    assumeTrue(testCase, isfile(presetPath));

    % Stage a session-level Preprocessed.mat next to the DLC csv.
    % We synthesize via the GUI controller path so format matches.
    app = sphynx.app.CreatePresetApp();
    cleaner = onCleanup(@() delete(app));
    pc = app.PreprocessController;
    pc.setPaths(struct('dlc', dlcPath));
    pc.loadAll();

    [d, base, ~] = fileparts(dlcPath);
    sessionFile = fullfile(d, [base '_Preprocessed.mat']);
    cleanerFile = onCleanup(@() removeIfExists(sessionFile));

    pc.OutputDirField.Value = d;  % drop next to the DLC
    pc.SavePlotsCheckbox.Value = false;
    paths = pc.savePreprocessed();
    verifyTrue(testCase, isfile(paths.session));

    % Now run analyzeSession — the fast path should fire and trim
    % miniscope* parts that came back as NotFound.
    cfg = sphynx.pipeline.defaultConfig();
    cfg.paths.dlc = dlcPath;
    cfg.paths.preset = presetPath;
    cfg.io.saveWorkspace = false;
    cfg.viz.headless = true;
    cfg.viz.makeVideo = false;
    cfg.verbose = 'warn';
    result = sphynx.pipeline.analyzeSession(cfg);

    verifyClass(testCase, result, 'struct');
    verifyTrue(testCase, isfield(result, 'BodyPartsTraces'));
    verifyGreaterThan(testCase, numel(result.BodyPartsTraces), 0);
    verifyGreaterThan(testCase, result.n_frames, 0);
    % Velocity must still respect the biological clip
    for k = 1:numel(result.BodyPartsTraces)
        v = result.BodyPartsTraces(k).VelocitySmoothed;
        if ~isempty(v)
            verifyLessThanOrEqual(testCase, max(v), cfg.preprocess.maxVelocityCmS + 1e-6);
        end
    end
end

function removeIfExists(p)
    if isfile(p); delete(p); end
end
