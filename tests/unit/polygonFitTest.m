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

function testLongSideOutlineFillsSolid(testCase)
    % A slanted 1200-px side: with 1000 points the outline has gaps and imfill
    % leaves a bare contour.
    cx = [40 1243 1243 40]; cy = [146 107 154 191];
    [x, y] = sphynx.util.polygonFit(cx, cy);
    filled = imfill(sphynx.preset.maskFromBorder(320, 1280, x, y), 'holes');
    verifyTrue(testCase, filled(150, 640));
    expected = polyarea(cx, cy);
    verifyLessThan(testCase, abs(nnz(filled) - expected) / expected, 0.05);
end

function testShortSidesKeepRequestedCount(testCase)
    [x, ~, sx] = sphynx.util.polygonFit([10 90 90 10], [10 10 70 70], 'PointsPerSide', 1000);
    verifyEqual(testCase, numel(sx{1}), 1000);
    verifyEqual(testCase, numel(x), 4000);
end
