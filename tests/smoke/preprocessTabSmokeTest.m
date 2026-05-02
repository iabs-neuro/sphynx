function tests = preprocessTabSmokeTest
% PREPROCESSTABSMOKETEST  Preprocess Tracking tab builds, loads DLC,
% and switches body parts without errors.
    tests = functiontests(localfunctions);
end

function testTabConstructs(testCase)
    app = sphynx.app.CreatePresetApp();
    cleaner = onCleanup(@() delete(app));
    verifyTrue(testCase, isvalid(app.TabPreprocess));
    verifyTrue(testCase, isa(app.PreprocessController, 'sphynx.app.PreprocessTabController'));
    pc = app.PreprocessController;
    verifyTrue(testCase, isvalid(pc.AxX));
    verifyTrue(testCase, isvalid(pc.AxY));
    verifyTrue(testCase, isvalid(pc.AxLk));
    verifyTrue(testCase, isvalid(pc.BodyPartDropDown));
end

function testLoadDLCFromDemo(testCase)
    app = sphynx.app.CreatePresetApp();
    cleaner = onCleanup(@() delete(app));
    pc = app.PreprocessController;

    repo = sphynx.util.repoRoot();
    dlcPath = fullfile(repo, 'Demo', 'DLC', ...
        'NOF_H01_1DDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv');
    assumeTrue(testCase, isfile(dlcPath), ...
        sprintf('Demo DLC csv not found at %s', dlcPath));

    pc.setPaths(struct('dlc', dlcPath));
    pc.loadAll();

    verifyNotEmpty(testCase, pc.State.dlc);
    verifyGreaterThan(testCase, pc.State.dlc.nFrames, 0);
    verifyGreaterThan(testCase, numel(pc.State.dlc.bodyPartsNames), 0);
    verifyEqual(testCase, pc.BodyPartDropDown.Items, pc.State.dlc.bodyPartsNames);
end

function testBodyPartSwitch(testCase)
    app = sphynx.app.CreatePresetApp();
    cleaner = onCleanup(@() delete(app));
    pc = app.PreprocessController;

    repo = sphynx.util.repoRoot();
    dlcPath = fullfile(repo, 'Demo', 'DLC', ...
        'NOF_H01_1DDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv');
    assumeTrue(testCase, isfile(dlcPath));
    pc.setPaths(struct('dlc', dlcPath));
    pc.loadAll();

    nParts = numel(pc.State.dlc.bodyPartsNames);
    verifyEqual(testCase, pc.State.currentBodyPart, 1);

    pc.nextBodyPart();
    verifyEqual(testCase, pc.State.currentBodyPart, 2);

    pc.setCurrentBodyPart(nParts);
    verifyEqual(testCase, pc.State.currentBodyPart, nParts);

    % Out-of-range stays clamped
    pc.setCurrentBodyPart(nParts + 100);
    verifyEqual(testCase, pc.State.currentBodyPart, nParts);
    pc.prevBodyPart();
    verifyEqual(testCase, pc.State.currentBodyPart, nParts - 1);
end

function testPerPartDefaultsPopulated(testCase)
    app = sphynx.app.CreatePresetApp();
    cleaner = onCleanup(@() delete(app));
    pc = app.PreprocessController;

    repo = sphynx.util.repoRoot();
    dlcPath = fullfile(repo, 'Demo', 'DLC', ...
        'NOF_H01_1DDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv');
    assumeTrue(testCase, isfile(dlcPath));
    pc.setPaths(struct('dlc', dlcPath));
    pc.loadAll();

    nParts = numel(pc.State.dlc.bodyPartsNames);
    verifyEqual(testCase, numel(pc.State.perPart), nParts);
    bcIdx = find(strcmpi({pc.State.perPart.name}, 'bodycenter'), 1);
    noseIdx = find(strcmpi({pc.State.perPart.name}, 'nose'), 1);
    verifyNotEmpty(testCase, bcIdx);
    verifyNotEmpty(testCase, noseIdx);
    % bodycenter should pick the bigger smoothing window
    verifyGreaterThan(testCase, ...
        pc.State.perPart(bcIdx).smoothWindowSec, ...
        pc.State.perPart(noseIdx).smoothWindowSec);
    % All defaults populated
    for k = 1:nParts
        verifyEqual(testCase, pc.State.perPart(k).smoothingMethod, 'sgolay');
        verifyEqual(testCase, pc.State.perPart(k).interpolationMethod, 'pchip');
        verifyTrue(testCase, pc.State.perPart(k).use);
    end
end

function testAutoThresholdSinglePart(testCase)
    app = sphynx.app.CreatePresetApp();
    cleaner = onCleanup(@() delete(app));
    pc = app.PreprocessController;
    repo = sphynx.util.repoRoot();
    dlcPath = fullfile(repo, 'Demo', 'DLC', ...
        'NOF_H01_1DDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv');
    assumeTrue(testCase, isfile(dlcPath));
    pc.setPaths(struct('dlc', dlcPath));
    pc.loadAll();

    idx = find(strcmpi({pc.State.perPart.name}, 'nose'), 1);
    assumeTrue(testCase, ~isempty(idx));
    before = pc.State.perPart(idx).likelihoodThreshold;

    pc.AutoMethodDropDown.Value = 'quantile';
    pc.AutoParamField.Value = '0.05';
    pc.autoThresholdPart(idx);

    after = pc.State.perPart(idx).likelihoodThreshold;
    verifyTrue(testCase, after >= 0 && after <= 1);
    verifyTrue(testCase, after ~= before);  % some change occurred
end

function testManualRegionsListAndDelete(testCase)
    app = sphynx.app.CreatePresetApp();
    cleaner = onCleanup(@() delete(app));
    pc = app.PreprocessController;
    repo = sphynx.util.repoRoot();
    dlcPath = fullfile(repo, 'Demo', 'DLC', ...
        'NOF_H01_1DDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv');
    assumeTrue(testCase, isfile(dlcPath));
    pc.setPaths(struct('dlc', dlcPath));
    pc.loadAll();

    % Inject regions programmatically (drawpolygon needs interactive UI).
    % Build a complete struct array first to avoid empty-struct extension
    % corner cases under R2020a.
    regs = struct('vertices', {[10 10; 50 10; 50 50; 10 50], ...
                              [100 100; 150 100; 150 150; 100 150]}, ...
                  'appliesTo', {'all', 'nose'});
    pc.setManualRegions(regs);
    verifyEqual(testCase, numel(pc.RegionsListBox.Items), 2);

    % Delete second
    pc.deleteManualRegion(2);
    verifyEqual(testCase, numel(pc.State.manualRegions), 1);

    % Clear all
    pc.clearManualRegions();
    verifyEqual(testCase, numel(pc.State.manualRegions), 0);
end

function testVideoToggleAndFrameNav(testCase)
    app = sphynx.app.CreatePresetApp();
    cleaner = onCleanup(@() delete(app));
    pc = app.PreprocessController;
    repo = sphynx.util.repoRoot();
    dlcPath = fullfile(repo, 'Demo', 'DLC', ...
        'NOF_H01_1DDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv');
    videoPath = fullfile(repo, 'Demo', 'Video', 'NOF_H01_1D.mp4');
    assumeTrue(testCase, isfile(dlcPath));
    assumeTrue(testCase, isfile(videoPath));
    pc.setPaths(struct('dlc', dlcPath, 'video', videoPath));
    pc.loadAll();

    % Toggle video on (programmatic — just call the method)
    pc.toggleVideoPanel(true);
    verifyTrue(testCase, ~isempty(pc.VideoReader_));

    % Move playhead
    pc.setCurrentFrame(100);
    verifyEqual(testCase, pc.State.currentFrame, 100);
    pc.setCurrentFrame(99999);  % clamp
    verifyEqual(testCase, pc.State.currentFrame, pc.State.dlc.nFrames);

    % Toggle off — standalone window should close
    pc.toggleVideoPanel(false);
    verifyTrue(testCase, isempty(pc.VideoWindow) || ~isvalid(pc.VideoWindow));
end

function testSavePreprocessedRoundTrip(testCase)
    app = sphynx.app.CreatePresetApp();
    cleaner = onCleanup(@() delete(app));
    pc = app.PreprocessController;
    repo = sphynx.util.repoRoot();
    dlcPath = fullfile(repo, 'Demo', 'DLC', ...
        'NOF_H01_1DDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv');
    assumeTrue(testCase, isfile(dlcPath));

    tmp = tempname();
    mkdir(tmp);
    cleaner2 = onCleanup(@() rmdir(tmp, 's'));

    pc.setPaths(struct('dlc', dlcPath));
    pc.loadAll();
    pc.OutputDirField.Value = tmp;
    pc.SavePlotsCheckbox.Value = false;  % keep test fast

    paths = pc.savePreprocessed();
    verifyTrue(testCase, isfile(paths.settings));
    verifyTrue(testCase, isfile(paths.session));
    s = load(paths.session);
    verifyTrue(testCase, isfield(s, 'BodyPartsTraces'));
    % NotFound parts (miniscopeNVista on the demo csv) are filtered out
    % at Save time; expect 13 = 14 - 1.
    verifyEqual(testCase, numel(s.BodyPartsTraces), 13);
    statuses = {s.BodyPartsTraces.Status};
    verifyEqual(testCase, sum(strcmp(statuses, 'NotFound')), 0);
end

function testComputeSinglePart(testCase)
    app = sphynx.app.CreatePresetApp();
    cleaner = onCleanup(@() delete(app));
    pc = app.PreprocessController;

    repo = sphynx.util.repoRoot();
    dlcPath = fullfile(repo, 'Demo', 'DLC', ...
        'NOF_H01_1DDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv');
    assumeTrue(testCase, isfile(dlcPath));
    pc.setPaths(struct('dlc', dlcPath));
    pc.loadAll();

    idx = find(strcmpi({pc.State.perPart.name}, 'bodycenter'), 1);
    assumeTrue(testCase, ~isempty(idx));
    pc.computePart(idx);

    verifyGreaterThanOrEqual(testCase, numel(pc.State.processed), idx);
    p = pc.State.processed(idx);
    verifyEqual(testCase, numel(p.X_smooth), pc.State.dlc.nFrames);
    verifyTrue(testCase, ismember(p.status, {'Good', 'NotFound'}));
end
