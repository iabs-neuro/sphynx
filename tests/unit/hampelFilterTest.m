function tests = hampelFilterTest
% HAMPELFILTERTEST  Unit tests for sphynx.preprocess.hampelFilter.
    tests = functiontests(localfunctions);
end

function testFlagsIsolatedSpike(testCase)
    n = 200;
    X = sin((1:n)'/10) * 50 + 100;
    Y = cos((1:n)'/10) * 50 + 100;
    X(80) = 9999;  % giant spike
    [Xo, ~, bad] = sphynx.preprocess.hampelFilter(X, Y, 7, 3);
    verifyTrue(testCase, bad(80));
    verifyTrue(testCase, isnan(Xo(80)));
end

function testCleanInputNothingFlagged(testCase)
    n = 200;
    X = sin((1:n)'/10) * 50 + 100;
    Y = cos((1:n)'/10) * 50 + 100;
    [Xo, Yo, bad] = sphynx.preprocess.hampelFilter(X, Y, 7, 3);
    verifyEqual(testCase, sum(bad), 0);
    verifyEqual(testCase, Xo, X);
    verifyEqual(testCase, Yo, Y);
end

function testNanInputPassthrough(testCase)
    n = 50;
    X = (1:n)' + 100;
    Y = (1:n)' + 100;
    X(10) = NaN; Y(10) = NaN;
    [Xo, Yo, bad] = sphynx.preprocess.hampelFilter(X, Y, 5, 3);
    verifyTrue(testCase, isnan(Xo(10)));
    verifyTrue(testCase, isnan(Yo(10)));
    verifyFalse(testCase, bad(10));
end

function testTooShortInputReturnsUnchanged(testCase)
    [Xo, Yo, bad] = sphynx.preprocess.hampelFilter([1; 2], [1; 2]);
    verifyEqual(testCase, Xo, [1; 2]);
    verifyEqual(testCase, sum(bad), 0);
end
