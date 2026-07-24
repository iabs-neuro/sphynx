function tests = classifySquareTest
    tests = functiontests(localfunctions);
end

function testCornersWallsCenterBasic(testCase)
    H = 200; W = 300; pxlPerCm = 5;
    xC = [50; 250; 250;  50];
    yC = [50;  50; 150; 150];
    arenaMask = makeRectMask(H, W, xC, yC);
    zones = sphynx.zones.classifySquare(arenaMask, ...
        'Strategy', 'corners-walls-center', ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 3, ...
        'CornerPoints', [xC yC]);
    names = {zones.name};
    verifyTrue(testCase, ismember('corners', names));
    verifyTrue(testCase, ismember('walls', names));
    verifyTrue(testCase, ismember('center', names));
end

function testCornersWallsCenterArenaTouchingFrameEdge(testCase)
    H = 100; W = 200; pxlPerCm = 5;
    xC = [1; 200; 200; 1];
    yC = [1; 1; 100; 100];
    arenaMask = true(H, W);
    zones = sphynx.zones.classifySquare(arenaMask, ...
        'Strategy', 'corners-walls-center', ...
        'PixelsPerCm', pxlPerCm, ...
        'WallWidthCm', 3, ...
        'CornerPoints', [xC yC]);
    walls = zones(strcmp({zones.name},'walls'));
    corners = zones(strcmp({zones.name},'corners'));
    verifyGreaterThan(testCase, sum(walls.maskfilled(:)), 0);
    verifyGreaterThan(testCase, sum(corners.maskfilled(:)), 0);
end

function testStripsStrategyDelegatesToPartition(testCase)
    H = 100; W = 200;
    arenaMask = false(H, W); arenaMask(20:80, 20:180) = true;
    zones = sphynx.zones.classifySquare(arenaMask, ...
        'Strategy', 'strips', ...
        'NumStrips', 3, ...
        'StripDirection', 'vertical');
    verifyEqual(testCase, numel(zones), 3);
    verifyEqual(testCase, zones(1).name, 'strip1');
end

function testNoneStrategyReturnsArenaOnly(testCase)
    H = 100; W = 200;
    arenaMask = false(H, W); arenaMask(20:80, 20:180) = true;
    zones = sphynx.zones.classifySquare(arenaMask, 'Strategy', 'none');
    verifyEqual(testCase, numel(zones), 1);
    verifyEqual(testCase, zones(1).name, 'arena');
end

function testRejectsUnknownStrategy(testCase)
    arenaMask = true(10, 10);
    verifyError(testCase, @() sphynx.zones.classifySquare(arenaMask, 'Strategy', 'blah'), ...
        'sphynx:classifySquare:unknownStrategy');
end

function mask = makeRectMask(H, W, xC, yC)
    [X, Y] = meshgrid(1:W, 1:H);
    mask = inpolygon(X, Y, xC, yC);
end
