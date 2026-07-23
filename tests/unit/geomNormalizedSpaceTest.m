function tests = geomNormalizedSpaceTest
% GEOMNORMALIZEDSPACETEST  Unit tests for the +sphynx/+geom normalized-space
% primitives that undo the x_kcorr pixel anisotropy (px <-> isotropic cm).
    tests = functiontests(localfunctions);
end

function testPointRoundTrip(testCase)
    x = [10; 20; 33.5]; y = [5; 8; 12];
    k = 1.7;
    [xn, yn] = sphynx.geom.toNormPoints(x, y, k);
    [xb, yb] = sphynx.geom.fromNormPoints(xn, yn, k);
    verifyEqual(testCase, xb, x, 'AbsTol', 1e-10);
    verifyEqual(testCase, yb, y, 'AbsTol', 1e-10);
end

function testPointScalesXOnly(testCase)
    [xn, yn] = sphynx.geom.toNormPoints(10, 4, 2);
    verifyEqual(testCase, xn, 20, 'AbsTol', 1e-10);
    verifyEqual(testCase, yn, 4, 'AbsTol', 1e-10);
end

function testPointIdentityWhenKcorrOne(testCase)
    [xn, yn] = sphynx.geom.toNormPoints(7, 9, 1);
    verifyEqual(testCase, xn, 7);
    verifyEqual(testCase, yn, 9);
end

function testMaskIdentityWhenKcorrOne(testCase)
    m = false(20, 30); m(5:15, 8:22) = true;
    mn = sphynx.geom.toNormMask(m, 1);
    verifyEqual(testCase, mn, m);
end

function testMaskRoundTripPreservesShape(testCase)
    m = false(40, 60); m(10:30, 15:45) = true;  % thick block
    k = 1.5;
    mn = sphynx.geom.toNormMask(m, k);
    mb = sphynx.geom.fromNormMask(mn, size(m));
    verifyEqual(testCase, size(mb), size(m));
    iou = sum(mb(:) & m(:)) / sum(mb(:) | m(:));
    verifyGreaterThan(testCase, iou, 0.97);
end

function testMaskWidthStretchedByKcorr(testCase)
    m = false(40, 40); m(:, 18:22) = true;  % 5-px vertical stripe
    k = 2;
    mn = sphynx.geom.toNormMask(m, k);
    verifyEqual(testCase, size(mn, 2), 80);
    colCount = sum(any(mn, 1));
    verifyGreaterThanOrEqual(testCase, colCount, 9);
    verifyLessThanOrEqual(testCase, colCount, 11);
end

function testEllipseBecomesCircleInNorm(testCase)
    % A physical circle appears as an X-compressed (tall) ellipse in pixel
    % space when x_kcorr > 1. Normalizing must restore a near-circular mask.
    H = 200; W = 200;
    [xx, yy] = meshgrid(1:W, 1:H);
    cx = 100; cy = 100; ry = 60; k = 2;      % X pixel radius = ry/k
    ell = ((xx - cx) * k).^2 + (yy - cy).^2 <= ry^2;
    n = sphynx.geom.toNormMask(ell, k);
    s = regionprops(n, 'BoundingBox');
    bb = s(1).BoundingBox;                    % [x y w h]
    aspect = bb(3) / bb(4);
    verifyEqual(testCase, aspect, 1, 'AbsTol', 0.06);
end
