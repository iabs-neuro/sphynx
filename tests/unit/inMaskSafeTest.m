function tests = inMaskSafeTest
    tests = functiontests(localfunctions);
end

function testInsideMask(testCase)
    mask = false(10, 10); mask(3:7, 3:7) = true;
    verifyTrue(testCase, sphynx.util.inMaskSafe(mask, 5, 5));
end

function testOutsideMask(testCase)
    mask = false(10, 10); mask(3:7, 3:7) = true;
    verifyFalse(testCase, sphynx.util.inMaskSafe(mask, 1, 1));
end

function testOutsideFrameReturnsFalse(testCase)
    mask = false(10, 10); mask(3:7, 3:7) = true;
    verifyFalse(testCase, sphynx.util.inMaskSafe(mask, -3, 5));
    verifyFalse(testCase, sphynx.util.inMaskSafe(mask, 5, -3));
    verifyFalse(testCase, sphynx.util.inMaskSafe(mask, 100, 5));
    verifyFalse(testCase, sphynx.util.inMaskSafe(mask, 5, 100));
end

function testNonIntegerCoordinates(testCase)
    mask = false(10, 10); mask(3:7, 3:7) = true;
    verifyTrue(testCase, sphynx.util.inMaskSafe(mask, 5.7, 4.3));
end

function testVectorizedInput(testCase)
    mask = false(10, 10); mask(3:7, 3:7) = true;
    xs = [5; 1; -3; 100];
    ys = [5; 1;  5; 5];
    expected = [true; false; false; false];
    verifyEqual(testCase, sphynx.util.inMaskSafe(mask, xs, ys), expected);
end
