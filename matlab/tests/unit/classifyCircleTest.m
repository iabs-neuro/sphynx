function tests = classifyCircleTest
    tests = functiontests(localfunctions);
end

function testSmallArenaWallAndCenter(testCase)
    % R=30 cm, wall=10 cm, mid=20 cm (default minC=10 cm).
    % In pixels: wallW=20, midW=40, cumW after middle1=60.
    % bwdist of a discrete circle of r=60 px yields maxDist ~= 60.0083 px
    % (rasterization rounds inward at the center pixel), so a tiny sliver
    % of pixels with distFromOutside > 60 remains. Center IS present and
    % this is deterministic for a given bwdist on this exact mask.
    H = 200; W = 200; pxlPerCm = 2;
    arenaMask = makeCircleMask(H, W, 100, 100, 30 * pxlPerCm);
    zones = sphynx.zones.classifyCircle(arenaMask, ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 10, ...
        'MiddleWidthCm', 20);
    names = {zones.name};
    verifyTrue(testCase, ismember('wall', names));
    verifyTrue(testCase, ismember('middle1', names));
    % maxDist = 60.0083 > cumW = 60, so a center sliver exists deterministically.
    verifyTrue(testCase, ismember('center', names));
end

function testLargeArenaWithMiddleRings(testCase)
    % R=80, wall=10, middle=20, minC=10:
    %   wall(10) + middle1(20) + middle2(20) + middle3(20) + center(10)
    H = 400; W = 400; pxlPerCm = 2;
    arenaMask = makeCircleMask(H, W, 200, 200, 80 * pxlPerCm);
    zones = sphynx.zones.classifyCircle(arenaMask, ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 10, ...
        'MiddleWidthCm', 20);
    names = {zones.name};
    verifyTrue(testCase, ismember('wall', names));
    verifyTrue(testCase, ismember('middle1', names));
    verifyTrue(testCase, ismember('middle2', names));
    verifyTrue(testCase, ismember('middle3', names));
    verifyTrue(testCase, ismember('center', names));
end

function testCenterAlwaysAddedEvenIfNarrow(testCase)
    % R=15 cm, wall=10 cm: only 5 cm of center remains (< minC=10).
    % Old behavior: dropped center. New behavior: center is kept,
    % just narrower than MinCenterCm.
    H = 200; W = 200; pxlPerCm = 2;
    arenaMask = makeCircleMask(H, W, 100, 100, 15 * pxlPerCm);
    zones = sphynx.zones.classifyCircle(arenaMask, ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 10, ...
        'MiddleWidthCm', 20, ...
        'MinCenterCm', 10);
    names = {zones.name};
    verifyTrue(testCase, ismember('wall', names));
    verifyTrue(testCase, ismember('center', names));
    verifyFalse(testCase, ismember('middle1', names));
end

function testZonesArePartitionOfArena(testCase)
    H = 300; W = 300; pxlPerCm = 2;
    arenaMask = makeCircleMask(H, W, 150, 150, 60 * pxlPerCm);
    zones = sphynx.zones.classifyCircle(arenaMask, ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 10, ...
        'MiddleWidthCm', 20);
    summed = false(H, W);
    for i = 1:numel(zones)
        verifyFalse(testCase, any(summed(:) & zones(i).maskfilled(:)));
        summed = summed | zones(i).maskfilled;
    end
    verifyEqual(testCase, summed, arenaMask);
end

function testArenaTouchingFrameEdgeBug1(testCase)
    H = 200; W = 200; pxlPerCm = 2;
    arenaMask = makeCircleMask(H, W, 60, 60, 60 * pxlPerCm);
    zones = sphynx.zones.classifyCircle(arenaMask, ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 10, ...
        'MiddleWidthCm', 20);
    wall = zones(strcmp({zones.name},'wall'));
    verifyGreaterThan(testCase, sum(wall.maskfilled(:)), 0);
end

function testBoundary92cmArenaKeepsMiddleAndCenter(testCase)
    % User repro: WallW=12, MidW=24, arena diameter 92 cm.
    % wallW+midW+minC = 12+24+10 = 46 cm = arena radius exactly.
    % Old behavior: middle1 sometimes dropped due to float boundary.
    % New behavior: {wall, middle1, center} always returned.
    %
    % NOTE: this scenario already passed under old code (the boundary
    % math worked out at pxlPerCm=5). Kept as a regression-doc test
    % pinning the user's exact repro; the actual fix is gated by
    % `testCenterAlwaysAddedEvenIfNarrow`.
    H = 600; W = 600; pxlPerCm = 5;
    arenaMask = makeCircleMask(H, W, 300, 300, 46 * pxlPerCm);
    zones = sphynx.zones.classifyCircle(arenaMask, ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 12, ...
        'MiddleWidthCm', 24, ...
        'MinCenterCm', 10);
    names = {zones.name};
    verifyTrue(testCase, ismember('wall', names));
    verifyTrue(testCase, ismember('middle1', names));
    verifyTrue(testCase, ismember('center', names));
end

function testEllipseThinMinorAxisStillProducesCenter(testCase)
    % Ellipse 90x60 cm with wall=12, mid=24, minC=10.
    % Minor radius = 30 cm, so maxDist ~= 30 cm.
    % wallW+midW+minC = 46 > 30 -> old behavior returned only wall.
    % New behavior: {wall, center} (center fills 30-12=18 cm wide).
    %
    % NOTE: this scenario did NOT pass under old code (center was dropped
    % when narrower than MinCenterCm). Kept as a regression-doc test
    % pinning the user's exact repro; the actual fix is gated by
    % `testCenterAlwaysAddedEvenIfNarrow`.
    H = 600; W = 600; pxlPerCm = 5;
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask = ((X - 300) / (45 * pxlPerCm)).^2 + ...
                ((Y - 300) / (30 * pxlPerCm)).^2 <= 1;
    zones = sphynx.zones.classifyCircle(arenaMask, ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 12, ...
        'MiddleWidthCm', 24, ...
        'MinCenterCm', 10);
    names = {zones.name};
    verifyTrue(testCase, ismember('wall', names));
    verifyTrue(testCase, ismember('center', names));
end

function mask = makeCircleMask(H, W, cx, cy, r)
    [X, Y] = meshgrid(1:W, 1:H);
    mask = (X - cx).^2 + (Y - cy).^2 <= r^2;
end
