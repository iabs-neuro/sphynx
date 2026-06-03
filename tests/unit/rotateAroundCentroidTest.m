function tests = rotateAroundCentroidTest
    tests = functiontests(localfunctions);
end

function testIdentityRotation(testCase)
    bx = [1 2 3]'; by = [10 20 30]';
    [bxR, byR] = sphynx.preset.rotateAroundCentroid(bx, by, [2 20], 0);
    verifyEqual(testCase, bxR, bx, 'AbsTol', 1e-9);
    verifyEqual(testCase, byR, by, 'AbsTol', 1e-9);
end

function test90Rotation(testCase)
    bx = 3; by = 0;
    [bxR, byR] = sphynx.preset.rotateAroundCentroid(bx, by, [0 0], pi/2);
    verifyEqual(testCase, bxR, 0, 'AbsTol', 1e-9);
    verifyEqual(testCase, byR, 3, 'AbsTol', 1e-9);
end

function testCentroidIsFixedPoint(testCase)
    bx = [0]; by = [0];
    [bxR, byR] = sphynx.preset.rotateAroundCentroid(bx, by, [0 0], pi);
    verifyEqual(testCase, bxR, 0, 'AbsTol', 1e-9);
    verifyEqual(testCase, byR, 0, 'AbsTol', 1e-9);
end
