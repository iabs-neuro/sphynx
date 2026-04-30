function tests = kalmanFilter2DTest
% KALMANFILTER2DTEST  Unit tests for sphynx.preprocess.kalmanFilter2D.
    tests = functiontests(localfunctions);
end

function testSmoothesNoisyTrack(testCase)
    n = 500;
    rng(123);
    truthX = (1:n)' * 0.5;
    truthY = sin((1:n)'/30) * 50 + 100;
    obsX = truthX + randn(n, 1) * 5;
    obsY = truthY + randn(n, 1) * 5;
    L = ones(n, 1);
    [Xs, Ys] = sphynx.preprocess.kalmanFilter2D(obsX, obsY, L, 1e-2, 1);
    % Smoothed RMSE to truth should be lower than raw RMSE
    rmseRawX = sqrt(mean((obsX - truthX).^2));
    rmseSmX = sqrt(mean((Xs - truthX).^2));
    verifyLessThan(testCase, rmseSmX, rmseRawX);

    rmseRawY = sqrt(mean((obsY - truthY).^2));
    rmseSmY = sqrt(mean((Ys - truthY).^2));
    verifyLessThan(testCase, rmseSmY, rmseRawY);
end

function testLowLikelihoodIsDiscounted(testCase)
    % With low likelihood, the filter should largely ignore the bad samples
    n = 200;
    truthX = (1:n)' * 0.5;
    truthY = ones(n, 1) * 100;
    L = ones(n, 1);
    obsX = truthX;
    obsY = truthY;
    % Inject 3 garbage samples with very low likelihood
    obsX(100:102) = 1000;
    L(100:102) = 0.05;
    [Xs, ~] = sphynx.preprocess.kalmanFilter2D(obsX, obsY, L, 1e-2, 1);
    % Smoothed value at frame 101 should stay close to neighborhood
    verifyLessThan(testCase, abs(Xs(101) - truthX(101)), 50);
end

function testReturnsCorrectShape(testCase)
    n = 50;
    X = randn(n, 1) * 10 + 100;
    Y = randn(n, 1) * 10 + 100;
    [Xs, Ys] = sphynx.preprocess.kalmanFilter2D(X, Y);
    verifyEqual(testCase, numel(Xs), n);
    verifyEqual(testCase, numel(Ys), n);
end

function testTooShortInputUnchanged(testCase)
    [Xs, Ys] = sphynx.preprocess.kalmanFilter2D([1; 2], [3; 4]);
    verifyEqual(testCase, Xs, [1; 2]);
    verifyEqual(testCase, Ys, [3; 4]);
end
