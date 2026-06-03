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
