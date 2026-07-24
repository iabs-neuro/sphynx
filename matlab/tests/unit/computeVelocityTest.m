function tests = computeVelocityTest
    tests = functiontests(localfunctions);
end

function testStationaryYieldsZero(testCase)
    x = ones(100,1) * 50;
    y = ones(100,1) * 50;
    v = sphynx.preprocess.computeVelocity(x, y, 30, 5, 'MaxVelocityCmS', 50, 'SmoothWindow', 11);
    verifyEqual(testCase, max(v), 0, 'AbsTol', 1e-9);
end

function testUniformMotion(testCase)
    n = 200;
    pxlPerCm = 5;
    x = (1:n)' * pxlPerCm;  % 1 cm per frame in pxl
    y = ones(n,1) * 100;
    v = sphynx.preprocess.computeVelocity(x, y, 30, pxlPerCm, ...
        'MaxVelocityCmS', 50, 'SmoothWindow', 11);
    coreV = v(20:end-20);
    verifyEqual(testCase, mean(coreV), 30, 'AbsTol', 1);
end

function testOutlierIsClipped(testCase)
    n = 200;
    pxlPerCm = 5;
    x = (1:n)' * pxlPerCm * 10/30;
    y = ones(n,1) * 100;
    x(100) = x(100) + 200 * pxlPerCm;
    v = sphynx.preprocess.computeVelocity(x, y, 30, pxlPerCm, ...
        'MaxVelocityCmS', 50, 'SmoothWindow', 11);
    verifyLessThanOrEqual(testCase, max(v), 50, ...
        'Bug-4: velocity must be clipped to MaxVelocityCmS');
end

function testRequiresPositivePxlPerCm(testCase)
    verifyError(testCase, @() sphynx.preprocess.computeVelocity([1;2;3],[1;2;3],30,0), ...
        'MATLAB:expectedPositive');
end
