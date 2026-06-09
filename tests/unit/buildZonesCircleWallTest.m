function tests = buildZonesCircleWallTest
    tests = functiontests(localfunctions);
end

function testTwoZonesWallAndCenter(testCase)
    % Round arena, wall=10 cm at pxlPerCm=2 -> wall ring + center.
    mask = makeDisc(120, 60);
    Z = sphynx.preset.buildZonesCircleWall(mask, ...
        'PixelsPerCm', 2, 'WallWidthCm', 10);
    verifyEqual(testCase, numel(Z), 2);
    verifyEqual(testCase, Z(1).name, 'wall');
    verifyEqual(testCase, Z(2).name, 'center');
    % wall pixels + center pixels == arena pixels (partition).
    verifyEqual(testCase, sum(Z(1).maskfilled(:)) + sum(Z(2).maskfilled(:)), ...
        sum(mask(:)));
end

function testWallZeroOnlyCenter(testCase)
    % WallWidthCm = 0 -> single 'center' zone covering the whole arena.
    mask = makeDisc(120, 60);
    Z = sphynx.preset.buildZonesCircleWall(mask, ...
        'PixelsPerCm', 2, 'WallWidthCm', 0);
    verifyEqual(testCase, numel(Z), 1);
    verifyEqual(testCase, Z(1).name, 'center');
    verifyEqual(testCase, sum(Z(1).maskfilled(:)), sum(mask(:)));
end

function testEllipseShapeSupported(testCase)
    % Wall ring works on an elongated mask too (it's bwdist-based).
    [H, W] = deal(120, 200);
    [Y, X] = ndgrid(1:H, 1:W);
    cx = W/2; cy = H/2;
    a = 80; b = 40;  % semi-axes
    mask = ((X - cx)/a).^2 + ((Y - cy)/b).^2 <= 1;
    Z = sphynx.preset.buildZonesCircleWall(mask, ...
        'PixelsPerCm', 2, 'WallWidthCm', 5);
    verifyEqual(testCase, numel(Z), 2);
    verifyTrue(testCase, sum(Z(1).maskfilled(:)) > 0);
    verifyTrue(testCase, sum(Z(2).maskfilled(:)) > 0);
end

function mask = makeDisc(diameterPx, radiusOffset)
    H = diameterPx; W = diameterPx;
    [Y, X] = ndgrid(1:H, 1:W);
    cy = H/2; cx = W/2;
    mask = (X - cx).^2 + (Y - cy).^2 <= radiusOffset^2;
end
