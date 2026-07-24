function tests = arenaExclusionRingTest
    tests = functiontests(localfunctions);
end

function testRingAroundCircle(testCase)
    H = 100; W = 100;
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask = (X - 50).^2 + (Y - 50).^2 <= 30^2;
    regions = sphynx.preprocess.arenaExclusionRing(arenaMask, 5);
    verifyGreaterThanOrEqual(testCase, numel(regions), 1);
    sizes = cellfun(@(r) size(r.vertices, 1), num2cell(regions));
    verifyGreaterThan(testCase, max(sizes), 20);
end

function testZeroWidthReturnsEmpty(testCase)
    H = 100; W = 100;
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask = (X - 50).^2 + (Y - 50).^2 <= 30^2;
    regions = sphynx.preprocess.arenaExclusionRing(arenaMask, 0);
    verifyEqual(testCase, numel(regions), 0);
end
