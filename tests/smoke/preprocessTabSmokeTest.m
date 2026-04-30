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
