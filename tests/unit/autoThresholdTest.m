function tests = autoThresholdTest
% AUTOTHRESHOLDTEST  Unit tests for sphynx.preprocess.autoThreshold.
    tests = functiontests(localfunctions);
end

function testOtsuOnBimodal(testCase)
    % Strong bimodal: 80% near 1.0, 20% near 0.2
    n = 1000;
    L = [0.99 + 0.005*randn(800, 1); 0.20 + 0.05*randn(200, 1)];
    L = max(0, min(1, L));
    thr = sphynx.preprocess.autoThreshold(L, 'otsu');
    verifyGreaterThan(testCase, thr, 0.3);
    verifyLessThan(testCase, thr, 0.95);
end

function testKneeOnBimodal(testCase)
    n = 1000;
    L = [0.99 + 0.005*randn(800, 1); 0.20 + 0.05*randn(200, 1)];
    L = max(0, min(1, L));
    thr = sphynx.preprocess.autoThreshold(L, 'knee');
    verifyGreaterThan(testCase, thr, 0.0);
    verifyLessThan(testCase, thr, 1.0);
end

function testQuantile(testCase)
    % Auto threshold has a 0.4 floor for production safety; quantile of
    % 0.05 on linspace(0,1) would be 0.05, but floor clamps to 0.4.
    L = linspace(0, 1, 1000)';
    thr = sphynx.preprocess.autoThreshold(L, 'quantile', 0.05);
    verifyEqual(testCase, thr, 0.4, 'AbsTol', 1e-2);   % floor activates
    thr2 = sphynx.preprocess.autoThreshold(L, 'quantile', 0.5);
    verifyEqual(testCase, thr2, 0.5, 'AbsTol', 1e-2);  % above floor, intact
end

function testQuantileDefaults(testCase)
    L = linspace(0, 1, 1000)';
    thr = sphynx.preprocess.autoThreshold(L, 'quantile');
    verifyEqual(testCase, thr, 0.4, 'AbsTol', 1e-2);   % default 0.05 floored
end

function testQuantileAboveFloor(testCase)
    L = linspace(0, 1, 1000)';
    thr = sphynx.preprocess.autoThreshold(L, 'quantile', 0.6);
    verifyEqual(testCase, thr, 0.6, 'AbsTol', 1e-2);
end

function testPresetKeywords(testCase)
    L = rand(100, 1);
    verifyEqual(testCase, sphynx.preprocess.autoThreshold(L, 'preset', 'aggressive'), 0.99);
    verifyEqual(testCase, sphynx.preprocess.autoThreshold(L, 'preset', 'moderate'), 0.95);
    % lax = 0.60 is above the 0.4 floor, so passes intact
    verifyEqual(testCase, sphynx.preprocess.autoThreshold(L, 'preset', 'lax'), 0.60);
end

function testPresetDefault(testCase)
    L = rand(100, 1);
    verifyEqual(testCase, sphynx.preprocess.autoThreshold(L, 'preset'), 0.95);
end

function testEmptyInputFallback(testCase)
    verifyEqual(testCase, sphynx.preprocess.autoThreshold([], 'otsu'), 0.95);
    verifyEqual(testCase, sphynx.preprocess.autoThreshold([], 'knee'), 0.95);
end

function testAllSameValueFallback(testCase)
    L = ones(500, 1);
    thr = sphynx.preprocess.autoThreshold(L, 'otsu');
    verifyTrue(testCase, thr >= 0 && thr <= 1);
    thr2 = sphynx.preprocess.autoThreshold(L, 'knee');
    verifyTrue(testCase, thr2 >= 0 && thr2 <= 1);
end

function testUnknownMethodErrors(testCase)
    L = rand(100, 1);
    verifyError(testCase, @() sphynx.preprocess.autoThreshold(L, 'foobar'), ...
        'sphynx:autoThreshold:unknownMethod');
end

function testReturnInRange(testCase)
    % Stress: random distributions should always yield thr in [0, 1]
    rng(42);
    for k = 1:20
        n = randi([50 5000]);
        L = rand(n, 1);
        for m = {'otsu', 'knee', 'quantile', 'preset'}
            param = [];
            if strcmp(m{1}, 'preset'); param = 'moderate'; end
            thr = sphynx.preprocess.autoThreshold(L, m{1}, param);
            verifyTrue(testCase, thr >= 0 && thr <= 1, ...
                sprintf('method=%s n=%d thr=%.3f out of [0,1]', m{1}, n, thr));
        end
    end
end
