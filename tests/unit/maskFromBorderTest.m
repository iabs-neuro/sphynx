function tests = maskFromBorderTest
    tests = functiontests(localfunctions);
end

function testMarksRoundedPixels(testCase)
    mask = sphynx.preset.maskFromBorder(10, 10, [3.4; 5.7], [2.1; 8.6]);
    verifyTrue(testCase, mask(2, 3));
    verifyTrue(testCase, mask(9, 6));
    verifyEqual(testCase, sum(mask(:)), 2);
end

function testSkipsOutOfBounds(testCase)
    mask = sphynx.preset.maskFromBorder(10, 10, [0; 11; 5], [5; 5; 12]);
    verifyEqual(testCase, sum(mask(:)), 0);
end
