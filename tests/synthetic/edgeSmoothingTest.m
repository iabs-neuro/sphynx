function tests = edgeSmoothingTest
% EDGESMOOTHINGTEST  Constant signal must remain constant at edges.
%   Also: a flat trace (no motion) must produce zero velocity.
    tests = functiontests(localfunctions);
end

function testConstantSpeedAtEdges(testCase)
    f = sphynx.testing.makeWalkingDLC(15, 5); % 15 cm/s for 5 s
    v = sphynx.preprocess.computeVelocity(f.x, f.y, f.frameRate, f.pxlPerCm, ...
        'MaxVelocityCmS', 50, 'SmoothWindow', 11);
    verifyEqual(testCase, mean(v(end-10:end)), 15, 'AbsTol', 1, ...
        'Bug-3: speed at trace end deviates due to edge smoothing artifact');
end

function testFlatTraceStaysFlat(testCase)
    n = 200;
    x = ones(n,1) * 100;
    y = ones(n,1) * 100;
    v = sphynx.preprocess.computeVelocity(x, y, 30, 5, ...
        'MaxVelocityCmS', 50, 'SmoothWindow', 11);
    verifyEqual(testCase, max(v), 0, 'AbsTol', 1e-6);
end
