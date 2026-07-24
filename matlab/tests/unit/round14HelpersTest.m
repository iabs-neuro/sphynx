function tests = round14HelpersTest
% ROUND14HELPERSTEST  Unit tests for round-14 helpers in CreatePresetApp:
%   - ensureUniqueTypes (R14.2 dedup on auto-detect commit)
%   - isCalibrated      (R14.1 calibration gate)
%   - 1-line angle math (R14.6 guard) -- duplicated here from the inline
%     branch so we can test the rule without driving the figure.
    tests = functiontests(localfunctions);
end

function testEnsureUniqueTypesNoCollision(testCase)
    app = sphynx.app.CreatePresetApp();
    cleaner = onCleanup(@() delete(app)); %#ok<NASGU>
    objs = makeObjs({'a', 'b', 'c'});
    out = app.ensureUniqueTypes(objs);
    verifyEqual(testCase, {out.type}, {'a', 'b', 'c'});
end

function testEnsureUniqueTypesCollisionBumpsTrailingDigit(testCase)
    app = sphynx.app.CreatePresetApp();
    cleaner = onCleanup(@() delete(app)); %#ok<NASGU>
    objs = makeObjs({'object1', 'object2', 'object1', 'object2'});
    out = app.ensureUniqueTypes(objs);
    verifyEqual(testCase, numel(unique({out.type})), 4);
    verifyEqual(testCase, out(1).type, 'object1');
    verifyEqual(testCase, out(2).type, 'object2');
    % object1 was taken; ensureUniqueTypes finds object3 (next free)
    verifyEqual(testCase, out(3).type, 'object3');
    verifyEqual(testCase, out(4).type, 'object4');
end

function testEnsureUniqueTypesCollisionFromNonNumericBase(testCase)
    app = sphynx.app.CreatePresetApp();
    cleaner = onCleanup(@() delete(app)); %#ok<NASGU>
    objs = makeObjs({'target', 'target'});
    out = app.ensureUniqueTypes(objs);
    verifyEqual(testCase, out(1).type, 'target');
    verifyEqual(testCase, out(2).type, 'target1');
end

function testIsCalibratedFalseByDefault(testCase)
    app = sphynx.app.CreatePresetApp();
    cleaner = onCleanup(@() delete(app)); %#ok<NASGU>
    verifyFalse(testCase, app.isCalibrated());
end

function testIsCalibratedTrueAfterSetPixelsPerCm(testCase)
    app = sphynx.app.CreatePresetApp();
    cleaner = onCleanup(@() delete(app)); %#ok<NASGU>
    app.setPixelsPerCm(5.0);
    verifyTrue(testCase, app.isCalibrated());
end

function testOneLineAngleWithinRange(testCase)
    % Diagonal line: dx=100, dy=100 -> 45 deg, inside [20, 70].
    verifyTrue(testCase, oneLineAngleOk(0, 0, 100, 100));
    % 30 deg
    verifyTrue(testCase, oneLineAngleOk(0, 0, 100, 100*tand(30)));
    % 60 deg
    verifyTrue(testCase, oneLineAngleOk(0, 0, 100, 100*tand(60)));
end

function testOneLineAngleTooHorizontal(testCase)
    % 5 deg from horizontal: dx=100, dy=tand(5)*100
    verifyFalse(testCase, oneLineAngleOk(0, 0, 100, 100 * tand(5)));
    % exactly horizontal
    verifyFalse(testCase, oneLineAngleOk(0, 0, 100, 0));
end

function testOneLineAngleTooVertical(testCase)
    % 85 deg: nearly vertical
    verifyFalse(testCase, oneLineAngleOk(0, 0, 100*tand(5), 100));
    % exactly vertical
    verifyFalse(testCase, oneLineAngleOk(0, 0, 0, 100));
end

function testOneLineAngleAcceptsNegativeDirections(testCase)
    % 45 deg drawn from bottom-right to top-left should still be 45.
    verifyTrue(testCase, oneLineAngleOk(100, 100, 0, 0));
    % -45 deg
    verifyTrue(testCase, oneLineAngleOk(0, 100, 100, 0));
end

% ------------------------------------------------------------------
function objs = makeObjs(types)
    objs = struct('type', {}, 'geometry', {}, 'border_x', {}, ...
        'border_y', {}, 'border_separate_x', {}, ...
        'border_separate_y', {}, 'mask', {}, 'class', {});
    for k = 1:numel(types)
        o.type = types{k};
        o.geometry = 'Polygon';
        o.border_x = [];
        o.border_y = [];
        o.border_separate_x = {};
        o.border_separate_y = {};
        o.mask = [];
        o.class = '';
        if isempty(objs); objs = o; else; objs(end + 1) = o; end %#ok<AGROW>
    end
end

function ok = oneLineAngleOk(x1, y1, x2, y2)
    % Mirror of the rule inside onCalibrateChoose '1 line' branch (R14.6).
    dx = x2 - x1;
    dy = y2 - y1;
    angDeg = abs(atan2d(dy, dx));
    if angDeg > 90; angDeg = 180 - angDeg; end
    ok = angDeg >= 20 && angDeg <= 70;
end
