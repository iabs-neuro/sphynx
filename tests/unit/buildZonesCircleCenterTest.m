function tests = buildZonesCircleCenterTest
    tests = functiontests(localfunctions);
end

function testTwoZonesEmittedCenterAndWall(testCase)
    H = 200; W = 200; pxlPerCm = 2;
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask = (X-100).^2 + (Y-100).^2 <= (40 * pxlPerCm)^2;
    Z = sphynx.preset.buildZonesCircleCenter(arenaMask, ...
        'PixelsPerCm', pxlPerCm, 'CenterDiameterCm', 20);
    names = {Z.name};
    verifyEqual(testCase, sort(names), {'center', 'wall'});
end

function testCenterArea(testCase)
    H = 200; W = 200; pxlPerCm = 2;
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask = (X-100).^2 + (Y-100).^2 <= (40 * pxlPerCm)^2;
    Z = sphynx.preset.buildZonesCircleCenter(arenaMask, ...
        'PixelsPerCm', pxlPerCm, 'CenterDiameterCm', 20);
    centerZone = Z(strcmp({Z.name}, 'center'));
    verifyTrue(testCase, sum(centerZone.maskfilled(:)) > 1000);
    verifyTrue(testCase, sum(centerZone.maskfilled(:)) < 1400);
end

function testWallPartitionsArena(testCase)
    H = 200; W = 200; pxlPerCm = 2;
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask = (X-100).^2 + (Y-100).^2 <= (40 * pxlPerCm)^2;
    Z = sphynx.preset.buildZonesCircleCenter(arenaMask, ...
        'PixelsPerCm', pxlPerCm, 'CenterDiameterCm', 20);
    combined = false(H, W);
    for k = 1:numel(Z)
        verifyFalse(testCase, any(combined(:) & Z(k).maskfilled(:)));
        combined = combined | Z(k).maskfilled;
    end
    verifyEqual(testCase, combined, arenaMask);
end
