function tests = moveTargetSyncsSavedTest
% MOVETARGETSYNCSSAVEDTEST  R14.10 regression -- main-window move/rotate
%   must propagate to State.savedObjects so refreshPreview (which reads
%   savedObjects when the manager is closed) reflects the change. Before
%   the fix, the move silently had no visual effect AND reopening the
%   manager wiped the transform.
    tests = functiontests(localfunctions);
end

function testMoveTargetUpdatesSavedObjects(testCase)
    [app, cleaner] = makeApp(); %#ok<ASGLU>
    app.MoveTargetDropDown.Value = 'object1';
    app.MoveStepField.Value = 5;
    bxBefore = app.State.savedObjects(1).border_x;
    app.moveTarget([1 0]);   % move right by 5 px
    bxAfter = app.State.savedObjects(1).border_x;
    verifyEqual(testCase, bxAfter, bxBefore + 5, 'AbsTol', 1e-9);
    % working == saved when manager is closed
    verifyEqual(testCase, app.State.objects(1).border_x, ...
                          app.State.savedObjects(1).border_x);
end

function testRotateTargetUpdatesSavedObjects(testCase)
    [app, cleaner] = makeApp(); %#ok<ASGLU>
    app.MoveTargetDropDown.Value = 'object1';
    app.MoveStepField.Value = 10;
    bxBefore = app.State.savedObjects(1).border_x;
    app.rotateTarget(1);   % rotate +10 deg
    bxAfter = app.State.savedObjects(1).border_x;
    verifyFalse(testCase, isequal(bxBefore, bxAfter));
    verifyEqual(testCase, app.State.objects(1).border_x, ...
                          app.State.savedObjects(1).border_x);
end

function testSelectionMoveUpdatesSavedObjects(testCase)
    [app, cleaner] = makeApp({'object1', 'object2'}); %#ok<ASGLU>
    % setSelectedObjectIdx normally drives the listbox + refresh chain;
    % the listbox lives in the manager (closed in this headless test), so
    % we set state directly and rebuild the dropdown by hand.
    app.State.selectedObjectIdx = [1; 2];
    app.refreshMoveTargets();
    app.MoveTargetDropDown.Value = '<selection>';
    app.MoveStepField.Value = 3;
    bx1Before = app.State.savedObjects(1).border_x;
    bx2Before = app.State.savedObjects(2).border_x;
    app.moveTarget([0 1]);   % move down by 3 px
    verifyEqual(testCase, app.State.savedObjects(1).border_x, bx1Before, 'AbsTol', 1e-9);
    verifyEqual(testCase, app.State.savedObjects(2).border_x, bx2Before, 'AbsTol', 1e-9);
    verifyEqual(testCase, app.State.savedObjects(1).border_y, ...
                          app.State.objects(1).border_y);
    verifyEqual(testCase, app.State.savedObjects(2).border_y, ...
                          app.State.objects(2).border_y);
end

function testSyncSkippedWhileManagerOpen(testCase)
    % While the manager is open the draft model says main preview must NOT
    % reflect working changes -- savedObjects stays frozen at last finish.
    [app, cleaner] = makeApp(); %#ok<ASGLU>
    % Force "manager open" by stubbing a uifigure.
    app.ObjectsManagerFig = uifigure('Visible', 'off');
    figCleaner = onCleanup(@() delete(app.ObjectsManagerFig)); %#ok<NASGU>
    savedBefore = app.State.savedObjects(1).border_x;
    app.State.objects(1).border_x = app.State.objects(1).border_x + 100;
    app.syncSavedFromWorking();
    verifyEqual(testCase, app.State.savedObjects(1).border_x, savedBefore);
end

% ------------------------------------------------------------------
function [app, cleaner] = makeApp(typeNames)
    if nargin < 1; typeNames = {'object1'}; end
    app = sphynx.app.CreatePresetApp();
    cleaner = onCleanup(@() delete(app));
    H = 120; W = 120;
    app.State.frame = uint8(zeros(H, W, 3));
    app.State.height = H;
    app.State.width = W;
    app.setPixelsPerCm(2.0);
    objs = struct('type', {}, 'geometry', {}, 'border_x', {}, ...
        'border_y', {}, 'border_separate_x', {}, ...
        'border_separate_y', {}, 'mask', {}, 'class', {});
    for k = 1:numel(typeNames)
        ang = linspace(0, 2*pi, 60)';
        cx = 30 + 30 * k; cy = 60; r = 8;
        o.type = typeNames{k};
        o.geometry = 'Circle';
        o.border_x = cx + r * cos(ang);
        o.border_y = cy + r * sin(ang);
        o.border_separate_x = {};
        o.border_separate_y = {};
        o.mask = false(H, W);
        o.class = '';
        if isempty(objs); objs = o; else; objs(end+1) = o; end %#ok<AGROW>
    end
    app.State.objects = objs;
    app.State.savedObjects = objs;
    app.refreshMoveTargets();
end
