function tests = computeVelocityKcorrTest
% COMPUTEVELOCITYKCORRTEST  Velocity must apply the x_kcorr anisotropy
% correction to the X displacement component.
    tests = functiontests(localfunctions);
end

function testXKcorrScalesXMotion(testCase)
    n = 60; x = (1:n)'; y = ones(n, 1) * 100; fr = 10; ppc = 1;
    v1 = sphynx.preprocess.computeVelocity(x, y, fr, ppc, ...
        'MaxVelocityCmS', 1000, 'SmoothWindow', 3);
    v2 = sphynx.preprocess.computeVelocity(x, y, fr, ppc, ...
        'MaxVelocityCmS', 1000, 'SmoothWindow', 3, 'XKcorr', 2);
    verifyEqual(testCase, median(v2(10:end-10)), 2 * median(v1(10:end-10)), ...
        'RelTol', 0.02);
end

function testXKcorrLeavesYMotionUnchanged(testCase)
    n = 60; x = ones(n, 1) * 100; y = (1:n)'; fr = 10; ppc = 1;
    v1 = sphynx.preprocess.computeVelocity(x, y, fr, ppc, ...
        'MaxVelocityCmS', 1000, 'SmoothWindow', 3);
    v2 = sphynx.preprocess.computeVelocity(x, y, fr, ppc, ...
        'MaxVelocityCmS', 1000, 'SmoothWindow', 3, 'XKcorr', 3);
    verifyEqual(testCase, v2, v1, 'AbsTol', 1e-9);
end

function testDefaultUnchanged(testCase)
    n = 40; x = cumsum(randn(n, 1)); y = cumsum(randn(n, 1)); fr = 30; ppc = 5;
    v1 = sphynx.preprocess.computeVelocity(x, y, fr, ppc);
    v2 = sphynx.preprocess.computeVelocity(x, y, fr, ppc, 'XKcorr', 1);
    verifyEqual(testCase, v2, v1, 'AbsTol', 1e-9);
end
