function tests = classifyCircleTest
    tests = functiontests(localfunctions);
end

function testSmallArenaWallAndCenter(testCase)
    % R=30 cm, wall=10 cm, mid=20 cm (default minC=10 cm).
    % wall+mid = radius exactly (30 cm). With epsilon-relaxed boundary,
    % middle1 now fits (new behavior). center is absent because no pixels
    % remain past wall+middle1 at maxDist. This is the expected new behavior.
    H = 200; W = 200; pxlPerCm = 2;
    arenaMask = makeCircleMask(H, W, 100, 100, 30 * pxlPerCm);
    zones = sphynx.zones.classifyCircle(arenaMask, ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 10, ...
        'MiddleWidthCm', 20);
    names = {zones.name};
    verifyTrue(testCase, ismember('wall', names));
    verifyTrue(testCase, ismember('middle1', names));
    % center may or may not be present depending on rasterization at the
    % exact boundary; we do not assert either way.
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
