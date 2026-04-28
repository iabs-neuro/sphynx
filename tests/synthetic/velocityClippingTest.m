function tests = velocityClippingTest
% VELOCITYCLIPPINGTEST  DLC outlier must be clipped to <= 50 cm/s.
    tests = functiontests(localfunctions);
end

function testSingleSpikeIsClipped(testCase)
    f = sphynx.testing.makeJumpyDLC(100, 1000); % 200 cm jump in 1 frame
    v = sphynx.preprocess.computeVelocity(f.x, f.y, f.frameRate, f.pxlPerCm, ...
        'MaxVelocityCmS', 50, 'SmoothWindow', 11);
    verifyLessThanOrEqual(testCase, max(v), 50, ...
        'Bug-4: spike survived clipping');
end

function testWalkingSpeedRecovered(testCase)
    f = sphynx.testing.makeJumpyDLC(100, 1000);
    v = sphynx.preprocess.computeVelocity(f.x, f.y, f.frameRate, f.pxlPerCm, ...
        'MaxVelocityCmS', 50, 'SmoothWindow', 11);
    coreV = v(20:end-20);
    verifyEqual(testCase, mean(coreV), 10, 'AbsTol', 2);
end
