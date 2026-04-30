function tests = applyPerPartSettingsTest
% APPLYPERPARTSETTINGSTEST  Unit tests for the per-part orchestrator.
    tests = functiontests(localfunctions);
end

function testCleanInterpSmoothPipeline(testCase)
    % Synthetic input: clean parabolic motion + a few NaN gaps + low-likelihood frames
    n = 600;
    t = (1:n)';
    X = 100 + 0.05 * t.^1.5;
    Y = 200 - 0.02 * t;
    L = ones(n, 1) * 0.99;

    % Inject low-likelihood (drop frames)
    bad = [50 51 52 200 201];
    L(bad) = 0.1;
    X(bad) = X(bad) + 50;  % outlier values that should be discarded
    Y(bad) = Y(bad) - 50;

    settings = sphynx.preprocess.perPartDefault('nose');
    ctx = struct('frameWidth', 800, 'frameHeight', 600, 'frameRate', 30);

    out = sphynx.preprocess.applyPerPartSettings(X, Y, L, settings, ctx);

    verifyEqual(testCase, out.status, 'Good');
    verifyEqual(testCase, numel(out.X_smooth), n);
    verifyEqual(testCase, numel(out.Y_smooth), n);
    verifyTrue(testCase, ~any(isnan(out.X_smooth)));
    verifyTrue(testCase, ~any(isnan(out.Y_smooth)));
    % Smoothed values at injected outlier indices must be close to neighbors,
    % NOT to the outlier value
    verifyLessThan(testCase, abs(out.X_smooth(50) - X(45)), 30);
    verifyLessThan(testCase, abs(out.Y_smooth(50) - Y(45)), 30);
end

function testNotFoundWhenAllBad(testCase)
    n = 200;
    X = randn(n, 1) * 10 + 100;
    Y = randn(n, 1) * 10 + 100;
    L = zeros(n, 1);  % all below threshold

    settings = sphynx.preprocess.perPartDefault('nose');
    settings.notFoundThresholdPct = 50;
    ctx = struct('frameWidth', 800, 'frameHeight', 600, 'frameRate', 30);

    out = sphynx.preprocess.applyPerPartSettings(X, Y, L, settings, ctx);
    verifyEqual(testCase, out.status, 'NotFound');
    verifyTrue(testCase, all(isnan(out.X_smooth)));
end

function testBigVsSmallWindow(testCase)
    cfg = sphynx.pipeline.defaultConfig();
    sBig = sphynx.preprocess.perPartDefault('bodycenter', cfg);
    sSmall = sphynx.preprocess.perPartDefault('nose', cfg);
    verifyEqual(testCase, sBig.smoothWindowSec, cfg.preprocess.smoothWindowBigSec);
    verifyEqual(testCase, sSmall.smoothWindowSec, cfg.preprocess.smoothWindowSmallSec);
end

function testAllSmoothingMethodsReturnValidTrace(testCase)
    n = 300;
    X = sin((1:n)'/20) * 50 + 200;
    Y = cos((1:n)'/20) * 50 + 200;
    L = ones(n, 1);
    methods = {'sgolay', 'movmean', 'movmedian', 'gaussian', 'kalman'};
    ctx = struct('frameWidth', 800, 'frameHeight', 600, 'frameRate', 30);
    for k = 1:numel(methods)
        s = sphynx.preprocess.perPartDefault('nose');
        s.smoothingMethod = methods{k};
        out = sphynx.preprocess.applyPerPartSettings(X, Y, L, s, ctx);
        verifyEqual(testCase, numel(out.X_smooth), n, ...
            sprintf('method %s wrong length', methods{k}));
        verifyTrue(testCase, ~any(isnan(out.X_smooth)), ...
            sprintf('method %s leaks NaN', methods{k}));
    end
end

function testFrameBoundsClamping(testCase)
    n = 100;
    X = ones(n, 1) * 1500;  % far beyond frame width
    Y = ones(n, 1) * 100;
    L = ones(n, 1);
    settings = sphynx.preprocess.perPartDefault('nose');
    settings.likelihoodThreshold = 0.5;  % allow all frames through
    ctx = struct('frameWidth', 800, 'frameHeight', 600, 'frameRate', 30);
    out = sphynx.preprocess.applyPerPartSettings(X, Y, L, settings, ctx);
    % All X out of bounds -> all flagged -> NotFound (default 90% threshold)
    verifyEqual(testCase, out.status, 'NotFound');
end
