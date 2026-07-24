function tests = replaceNaNinStructTest
    tests = functiontests(localfunctions);
end

function testReplacesNaNInScalarField(testCase)
    S = struct('x', [1 NaN 3], 'y', 'abc');
    out = sphynx.util.replaceNaNinStruct(S);
    verifyEqual(testCase, out.x, [1 0 3]);
    verifyEqual(testCase, out.y, 'abc');
end

function testRecursesIntoNestedStruct(testCase)
    S = struct('a', struct('b', [NaN 2 NaN]));
    out = sphynx.util.replaceNaNinStruct(S);
    verifyEqual(testCase, out.a.b, [0 2 0]);
end

function testHandlesStructArray(testCase)
    S(1).x = [NaN 1];
    S(2).x = [2 NaN];
    out = sphynx.util.replaceNaNinStruct(S);
    verifyEqual(testCase, out(1).x, [0 1]);
    verifyEqual(testCase, out(2).x, [2 0]);
end

function testNonStructIsReturnedAsIs(testCase)
    verifyEqual(testCase, sphynx.util.replaceNaNinStruct([1 NaN 3]), [1 NaN 3]);
end
