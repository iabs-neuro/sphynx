function tests = classifyCircleTest
    tests = functiontests(localfunctions);
end

function testSmallArenaWallAndCenter(testCase)
    H = 200; W = 200; pxlPerCm = 2;
    arenaMask = makeCircleMask(H, W, 100, 100, 30 * pxlPerCm);
    zones = sphynx.zones.classifyCircle(arenaMask, ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 10, ...
        'MiddleWidthCm', 20);
    names = {zones.name};
    verifyTrue(testCase, ismember('wall', names));
    verifyTrue(testCase, ismember('center', names));
    verifyFalse(testCase, ismember('middle1', names));
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

function testNoCenterIfTooSmall(testCase)
    % R=15, wall=10: only 5cm radius left, < minC=10, so no center fits.
    H = 200; W = 200; pxlPerCm = 2;
    arenaMask = makeCircleMask(H, W, 100, 100, 15 * pxlPerCm);
    zones = sphynx.zones.classifyCircle(arenaMask, ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 10, ...
        'MiddleWidthCm', 20, ...
        'MinCenterCm', 10);
    names = {zones.name};
    verifyTrue(testCase, ismember('wall', names));
    verifyFalse(testCase, ismember('center', names));
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

function mask = makeCircleMask(H, W, cx, cy, r)
    [X, Y] = meshgrid(1:W, 1:H);
    mask = (X - cx).^2 + (Y - cy).^2 <= r^2;
end
