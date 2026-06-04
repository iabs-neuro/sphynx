function tests = autoDetectObjectsTest
    tests = functiontests(localfunctions);
end

function testThresholdFreeFormFindsBlobs(testCase)
    H = 200; W = 200;
    gray = uint8(220 * ones(H, W));
    arenaMask = false(H, W);
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask((X - 100).^2 + (Y - 100).^2 <= 80^2) = true;
    centers = [60 60; 100 100; 140 60];
    for k = 1:3
        gray((X - centers(k,1)).^2 + (Y - centers(k,2)).^2 <= 8^2) = 30;
    end
    cfg = struct('mode', 'free-form', 'algorithm', 'threshold', ...
        'sensitivity', 0.5, 'minAreaCm2', 0, 'maxAreaCm2', 1e6, ...
        'pxlPerCm', 1);
    objs = sphynx.preset.autoDetectObjects(gray, arenaMask, cfg);
    verifyEqual(testCase, numel(objs), 3);
end

function testCirclesModeProducesCircleObjects(testCase)
    H = 200; W = 200;
    gray = uint8(220 * ones(H, W));
    arenaMask = false(H, W);
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask((X - 100).^2 + (Y - 100).^2 <= 80^2) = true;
    gray((X - 100).^2 + (Y - 100).^2 <= 8^2) = 30;
    cfg = struct('mode', 'all-circles', 'algorithm', 'threshold', ...
        'sensitivity', 0.5, 'minAreaCm2', 0, 'maxAreaCm2', 1e6, ...
        'pxlPerCm', 1);
    objs = sphynx.preset.autoDetectObjects(gray, arenaMask, cfg);
    verifyGreaterThanOrEqual(testCase, numel(objs), 1);
    verifyEqual(testCase, objs(1).geometry, 'Circle');
end

function testHoughCirclesMode(testCase)
    H = 200; W = 200;
    gray = uint8(220 * ones(H, W));
    arenaMask = false(H, W);
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask((X - 100).^2 + (Y - 100).^2 <= 80^2) = true;
    gray((X - 100).^2 + (Y - 100).^2 <= 8^2) = 30;
    cfg = struct('mode', 'all-circles', 'algorithm', 'hough', ...
        'sensitivity', 0.9, 'radiusRangePx', [5 12], ...
        'minAreaCm2', 0, 'maxAreaCm2', 1e6, 'pxlPerCm', 1);
    objs = sphynx.preset.autoDetectObjects(gray, arenaMask, cfg);
    verifyGreaterThanOrEqual(testCase, numel(objs), 1);
    verifyEqual(testCase, objs(1).geometry, 'Circle');
end

function testOutsideArenaFiltered(testCase)
    H = 200; W = 200;
    gray = uint8(220 * ones(H, W));
    arenaMask = false(H, W);
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask((X - 100).^2 + (Y - 100).^2 <= 30^2) = true;
    gray((X - 180).^2 + (Y - 30).^2 <= 8^2) = 30;
    cfg = struct('mode', 'free-form', 'algorithm', 'threshold', ...
        'sensitivity', 0.5, 'minAreaCm2', 0, 'maxAreaCm2', 1e6, ...
        'pxlPerCm', 1);
    objs = sphynx.preset.autoDetectObjects(gray, arenaMask, cfg);
    verifyEqual(testCase, numel(objs), 0);
end

function testUniformRadiusMode(testCase)
    % Fix 6: all-circles with uniformRadius=true should return circles
    % whose effective radius matches uniformRadiusPx (within tolerance).
    H = 200; W = 200;
    gray = uint8(220 * ones(H, W));
    arenaMask = false(H, W);
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask((X - 100).^2 + (Y - 100).^2 <= 80^2) = true;
    centers = [60 60; 100 100; 140 60];
    for k = 1:3
        gray((X - centers(k,1)).^2 + (Y - centers(k,2)).^2 <= 8^2) = 30;
    end
    cfg = struct('mode', 'all-circles', 'algorithm', 'threshold', ...
        'sensitivity', 0.5, 'minAreaCm2', 0, 'maxAreaCm2', 1e6, ...
        'pxlPerCm', 1, 'uniformRadius', true, 'uniformRadiusPx', 12);
    objs = sphynx.preset.autoDetectObjects(gray, arenaMask, cfg);
    verifyGreaterThanOrEqual(testCase, numel(objs), 1);
    % Verify all returned circles have the same effective radius
    for k = 1:numel(objs)
        cx = mean(objs(k).border_x);
        cy = mean(objs(k).border_y);
        rEff = mean(sqrt((objs(k).border_x - cx).^2 + (objs(k).border_y - cy).^2));
        verifyEqual(testCase, rEff, 12, 'AbsTol', 0.5);
    end
end

function testNoArenaBoundaryComponent(testCase)
    % Pathological: arena boundary ring darkened -> old code returned a giant
    % blob mirroring the arena shape.  New code: arena erosion + 50% area cap.
    % Use pxlPerCm=10 so erosion radius = max(3, round(10)) = 10 px,
    % which is large enough to clip the 5-px-wide boundary ring.
    H = 200; W = 200;
    gray = uint8(220 * ones(H, W));
    arenaMask = false(H, W);
    [X, Y] = meshgrid(1:W, 1:H);
    arenaMask((X - 100).^2 + (Y - 100).^2 <= 80^2) = true;
    % Darken only a thin 5-px ring right at the arena boundary (r=75..80).
    % The arena erosion (10 px) clips this completely, preventing detection.
    boundaryRing = arenaMask & ~((X - 100).^2 + (Y - 100).^2 <= 75^2);
    gray(boundaryRing) = 80;
    % One real small object in center
    gray((X - 100).^2 + (Y - 100).^2 <= 8^2) = 30;
    cfg = struct('mode', 'free-form', 'algorithm', 'threshold', ...
        'sensitivity', 0.5, 'minAreaCm2', 0, 'maxAreaCm2', 1e6, ...
        'pxlPerCm', 10);
    objs = sphynx.preset.autoDetectObjects(gray, arenaMask, cfg);
    % Every returned object must be < 50% of arena area
    arenaArea = sum(arenaMask(:));
    for k = 1:numel(objs)
        objArea = sum(objs(k).mask(:));
        verifyLessThan(testCase, objArea, arenaArea * 0.5);
    end
end
