function tests = interpolateGapsTest
    tests = functiontests(localfunctions);
end

function testNoGapsUnchanged(testCase)
    in = (1:10)';
    out = sphynx.preprocess.interpolateGaps(in);
    verifyEqual(testCase, out, in);
end

function testFillsInteriorGap(testCase)
    in = [1; 2; NaN; 4; 5];
    out = sphynx.preprocess.interpolateGaps(in);
    verifyEqual(testCase, out(3), 3, 'AbsTol', 0.5);
    verifyFalse(testCase, any(isnan(out)));
end

function testFillsLeadingAndTrailing(testCase)
    in = [NaN; NaN; 3; 4; 5; NaN; NaN];
    out = sphynx.preprocess.interpolateGaps(in);
    verifyFalse(testCase, any(isnan(out)));
end

function testAllNaNReturnsAllNaN(testCase)
    in = nan(5, 1);
    out = sphynx.preprocess.interpolateGaps(in);
    verifyTrue(testCase, all(isnan(out)));
end

function testLinearMethod(testCase)
    in = [10; NaN; NaN; 40];
    out = sphynx.preprocess.interpolateGaps(in, 'Method', 'linear');
    verifyEqual(testCase, out, [10; 20; 30; 40], 'AbsTol', 1e-9);
end
