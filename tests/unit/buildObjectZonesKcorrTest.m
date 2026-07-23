function tests = buildObjectZonesKcorrTest
% BUILDOBJECTZONESKCORRTEST  Object interaction rings must be built in
% normalized (isotropic-cm) space so a ZoneWidthCm ring is physically
% uniform on the video frame when x_kcorr ~= 1.
    tests = functiontests(localfunctions);
end

function z = getZone(Z, name)
    idx = find(strcmp({Z.name}, name), 1);
    assert(~isempty(idx), 'zone %s missing', name);
    z = logical(Z(idx).maskfilled);
end

function testDefaultKcorrIsIsotropic(testCase)
    H = 200; W = 200;
    obj = struct('type', 'object1', 'mask', false(H, W));
    obj.mask(91:110, 91:110) = true;
    Z = sphynx.preset.buildObjectZones(obj, H, W, ...
        'PixelsPerCm', 1, 'ZoneWidthCm', 15);   % no XKcorr -> default 1
    ro = getZone(Z, 'object1_realout');
    rows = find(any(ro, 2)); cols = find(any(ro, 1));
    vTop = 91 - min(rows); hLeft = 91 - min(cols);
    verifyEqual(testCase, vTop, hLeft, 'AbsTol', 2, ...
        'default (kcorr=1) must inflate equally on X and Y');
end

function testKcorrRingNarrowerInX(testCase)
    % x_kcorr = 2 means X has half the px/cm of Y, so a 20 cm ring must be
    % ~20 px along Y but ~10 px along X on the video frame.
    H = 200; W = 200;
    obj = struct('type', 'object1', 'mask', false(H, W));
    obj.mask(91:110, 91:110) = true;
    Z = sphynx.preset.buildObjectZones(obj, H, W, ...
        'PixelsPerCm', 1, 'ZoneWidthCm', 20, 'XKcorr', 2);
    ro = getZone(Z, 'object1_realout');
    rows = find(any(ro, 2)); cols = find(any(ro, 1));
    vTop  = 91 - min(rows);  vBot   = max(rows) - 110;
    hLeft = 91 - min(cols);  hRight = max(cols) - 110;
    verifyEqual(testCase, vTop,  20, 'AbsTol', 3);
    verifyEqual(testCase, vBot,  20, 'AbsTol', 3);
    verifyEqual(testCase, hLeft, 10, 'AbsTol', 3);
    verifyEqual(testCase, hRight, 10, 'AbsTol', 3);
end

function testRealZoneUnchangedByKcorr(testCase)
    % The object polygon itself (_real) is the drawn mask, untouched.
    H = 120; W = 120;
    obj = struct('type', 'object1', 'mask', false(H, W));
    obj.mask(50:70, 50:70) = true;
    Z = sphynx.preset.buildObjectZones(obj, H, W, ...
        'PixelsPerCm', 1, 'ZoneWidthCm', 10, 'XKcorr', 1.8);
    real = getZone(Z, 'object1_real');
    verifyEqual(testCase, real, obj.mask);
end
