function tests = wrapTest
    tests = functiontests(localfunctions);
end

function testZeroStaysZero(testCase)
    verifyEqual(testCase, sphynx.angles.wrap(0), 0);
end

function testWrapsPositive(testCase)
    verifyEqual(testCase, sphynx.angles.wrap(3*pi), pi, 'AbsTol', 1e-12);
    verifyEqual(testCase, sphynx.angles.wrap(2*pi), 0, 'AbsTol', 1e-12);
end

function testWrapsNegative(testCase)
    verifyEqual(testCase, sphynx.angles.wrap(-3*pi), pi, 'AbsTol', 1e-12);
    verifyEqual(testCase, sphynx.angles.wrap(-2*pi), 0, 'AbsTol', 1e-12);
end

function testInRangeUnchanged(testCase)
    angles = [-pi+0.01; -pi/2; 0; pi/2; pi-0.01];
    verifyEqual(testCase, sphynx.angles.wrap(angles), angles, 'AbsTol', 1e-12);
end

function testVectorized(testCase)
    in  = [3*pi; -3*pi; 0; pi/4];
    out = sphynx.angles.wrap(in);
    verifyEqual(testCase, out, [pi; pi; 0; pi/4], 'AbsTol', 1e-12);
end

function testEdgeCases(testCase)
    verifyEqual(testCase, sphynx.angles.wrap(pi), pi, 'AbsTol', 1e-12);
    verifyEqual(testCase, sphynx.angles.wrap(1000*pi), 0, 'AbsTol', 1e-9);
end
