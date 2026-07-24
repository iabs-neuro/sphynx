function tests = computeVelocitySingleSampleTest
% COMPUTEVELOCITYSINGLESAMPLETEST  R31 audit #6: when outlier clipping
% leaves only ONE finite velocity sample, computeVelocity must not crash
% inside interp1 (which needs >= 2 sample points).
    tests = functiontests(localfunctions);
end

function testOneSurvivingSampleDoesNotCrash(testCase)
    % Frame 1 velocity is always 0 (dx(1)=0); every later displacement
    % here is huge and gets clipped to NaN, leaving exactly one good
    % sample. Pre-fix this threw "grid vectors must contain >= 2 points".
    x = [0; 1000; 2000; 3000];
    y = zeros(4, 1);
    v = sphynx.preprocess.computeVelocity(x, y, 30, 1, 'MaxVelocityCmS', 50);
    verifyEqual(testCase, numel(v), 4);
    verifyTrue(testCase, all(isfinite(v)));
    verifyLessThanOrEqual(testCase, max(v), 50 + 1e-6);
end

function testNoGoodSampleStillZero(testCase)
    % Sanity: the pre-existing zero-good-sample branch keeps working.
    x = [0; 5000];
    y = [0; 0];
    v = sphynx.preprocess.computeVelocity(x, y, 30, 1, 'MaxVelocityCmS', 50);
    verifyEqual(testCase, numel(v), 2);
    verifyTrue(testCase, all(isfinite(v)));
end
