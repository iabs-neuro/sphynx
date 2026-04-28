function tests = createPresetAppSmokeTest
% CREATEPRESETAPPSMOKETEST  App constructs and tears down without error.
%   GUI logic itself requires manual checklist; this only verifies
%   the class instantiates, builds the UI tree, and closes cleanly.
    tests = functiontests(localfunctions);
end

function testConstructAndDestroy(testCase)
    app = sphynx.app.CreatePresetApp();
    cleaner = onCleanup(@() delete(app));
    verifyTrue(testCase, isvalid(app.Figure));
    verifyTrue(testCase, isvalid(app.PreviewAxes));
    verifyClass(testCase, app.ExpTypeDropDown.Items, 'cell');
    verifyTrue(testCase, ismember('Polygon', app.ArenaGeometryDropDown.Items));
end

function testProgrammaticDriveSquareArena(testCase)
    app = sphynx.app.CreatePresetApp();
    cleaner = onCleanup(@() delete(app));

    % Inject a synthetic frame instead of loading a real video
    H = 200; W = 300;
    app.State = sphynx.app.CreatePresetApp.emptyState();
    app.State.videoPath = '<synthetic>';
    app.State.frame = uint8(zeros(H, W, 3));
    app.State.frameRate = 30;
    app.State.numFrames = 100;
    app.State.height = H;
    app.State.width = W;

    app.setPixelsPerCm(5);
    cornerPts = [50 50; 250 50; 250 150; 50 150];
    app.setArena('Polygon', cornerPts);
    verifyEqual(testCase, app.State.arena.geometry, 'Polygon');

    % Build corners-walls-center zones (Add to set, accumulating)
    app.ZonesStrategyDropDown.Value = 'corners-walls-center';
    app.WallWidthField.Value = 3;
    app.addZones();
    verifyGreaterThan(testCase, numel(app.State.zones), 0);
end
