function tests = buildZonesInNormTest
% BUILDZONESINNORMTEST  The arena zone wrapper must produce physically
% uniform rings on an anisotropic (x_kcorr ~= 1) frame.
    tests = functiontests(localfunctions);
end

function testWallRingPhysicallyUniform(testCase)
    % A physical circular arena appears as a tall ellipse when x_kcorr = 2.
    % A wall ring built in normalized space must be ~2x thicker (in px)
    % along Y than along X, i.e. physically the same cm on both axes.
    H = 240; W = 240;
    [xx, yy] = meshgrid(1:W, 1:H);
    cx = 120; cy = 120; ry = 90; k = 2;
    arena = ((xx - cx) * k).^2 + (yy - cy).^2 <= ry^2;   % tall ellipse
    ppc = 5; wallCm = 4;
    bf = @(m) sphynx.preset.buildZonesCircleWall(m, ...
        'PixelsPerCm', ppc, 'WallWidthCm', wallCm);
    Z = sphynx.geom.buildZonesInNorm(arena, k, bf);
    wall = logical(Z(strcmp({Z.name}, 'wall')).maskfilled);
    tY = sum(wall(:, cx));    % vertical slice: top + bottom bands
    tX = sum(wall(cy, :));    % horizontal slice: left + right bands
    verifyGreaterThan(testCase, tY / tX, 1.6);
    verifyLessThan(testCase, tY / tX, 2.4);
end

function testIdentityMatchesDirectBuild(testCase)
    H = 120; W = 120;
    [xx, yy] = meshgrid(1:W, 1:H);
    arena = (xx - 60).^2 + (yy - 60).^2 <= 40^2;
    bf = @(m) sphynx.preset.buildZonesCircleWall(m, ...
        'PixelsPerCm', 5, 'WallWidthCm', 4);
    Zwrap = sphynx.geom.buildZonesInNorm(arena, 1, bf);
    Zdirect = bf(arena);
    verifyEqual(testCase, {Zwrap.name}, {Zdirect.name});
    verifyEqual(testCase, Zwrap(1).maskfilled, Zdirect(1).maskfilled);
end
