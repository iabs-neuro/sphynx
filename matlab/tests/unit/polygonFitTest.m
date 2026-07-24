function tests = polygonFitTest
    tests = functiontests(localfunctions);
end

function testSquareReturnsClosedPolygon(testCase)
    x = [0; 10; 10;  0];
    y = [0;  0; 10; 10];
    [px, py, sx, sy] = sphynx.util.polygonFit(x, y);
    verifyEqual(testCase, numel(px), numel(py));
    verifyEqual(testCase, numel(sx), 4, 'square has 4 sides');
    verifyEqual(testCase, numel(sy), 4);
end

function testSidesAreDense(testCase)
    x = [0; 10; 10;  0];
    y = [0;  0; 10; 10];
    [~, ~, sx, ~] = sphynx.util.polygonFit(x, y);
    for i = 1:4
        verifyGreaterThan(testCase, numel(sx{i}), 10);
    end
end

function testRejectsTooFewCorners(testCase)
    verifyError(testCase, @() sphynx.util.polygonFit([0;1],[0;1]), ...
        'sphynx:polygonFit:tooFewCorners');
end
