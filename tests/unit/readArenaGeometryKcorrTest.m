function tests = readArenaGeometryKcorrTest
% READARENAGEOMETRYKCORRTEST  Circle geometry must be interpolated in
% normalized (isotropic-cm) space so a physically round object comes back
% as the correct pixel-space ellipse when x_kcorr ~= 1.
    tests = functiontests(localfunctions);
end

function testCircleFitInNormSpaceProducesEllipseBorder(testCase)
    xk = 2; cx = 110; cy = 110; Rpx = 60;
    ang = linspace(0, 2*pi, 40)';
    px = cx + (Rpx / xk) * cos(ang);   % X-compressed (tall) pixel ellipse
    py = cy + Rpx * sin(ang);
    frame = zeros(240, 240, 3, 'uint8');
    a = sphynx.preset.readArenaGeometry(frame, 'Circle', ...
        'Points', [px py], 'XKcorr', xk);
    exX = max(a.border_x) - min(a.border_x);
    exY = max(a.border_y) - min(a.border_y);
    verifyEqual(testCase, exY / exX, 2, 'AbsTol', 0.15);
    [bnx, bny] = sphynx.geom.toNormPoints(a.border_x, a.border_y, xk);
    exNX = max(bnx) - min(bnx);
    exNY = max(bny) - min(bny);
    verifyEqual(testCase, exNX / exNY, 1, 'AbsTol', 0.05);
end

function testCircleDefaultXKcorrUnchanged(testCase)
    frame = zeros(200, 200, 3, 'uint8');
    ang = linspace(0, 2*pi, 40)';
    px = 100 + 50 * cos(ang);
    py = 100 + 50 * sin(ang);
    a1 = sphynx.preset.readArenaGeometry(frame, 'Circle', 'Points', [px py]);
    a2 = sphynx.preset.readArenaGeometry(frame, 'Circle', 'Points', [px py], 'XKcorr', 1);
    verifyEqual(testCase, a1.border_x, a2.border_x, 'AbsTol', 1e-9);
    verifyEqual(testCase, a1.border_y, a2.border_y, 'AbsTol', 1e-9);
end
