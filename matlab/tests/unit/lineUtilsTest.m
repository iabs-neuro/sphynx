function tests = lineUtilsTest
    tests = functiontests(localfunctions);
end

function testLineFromTwoPoints(testCase)
    eq = sphynx.util.getLineEquation([0 0], [1 2]);  % y = 2x
    verifyEqual(testCase, eq(1), 2, 'AbsTol', 1e-12);
    verifyEqual(testCase, eq(2), 0, 'AbsTol', 1e-12);
    verifyTrue(testCase, isnan(eq(3)));
end

function testVerticalLine(testCase)
    eq = sphynx.util.getLineEquation([5 0], [5 7]);
    verifyTrue(testCase, isnan(eq(1)));
    verifyTrue(testCase, isnan(eq(2)));
    verifyEqual(testCase, eq(3), 5);
end

function testDegeneratePoints(testCase)
    eq = sphynx.util.getLineEquation([3 4], [3 4]);
    verifyTrue(testCase, all(isnan(eq)));
end

function testIntersection(testCase)
    [x, y] = sphynx.util.linesIntersection(1, 0, -1, 4);  % y=x and y=-x+4 -> (2,2)
    verifyEqual(testCase, x, 2, 'AbsTol', 1e-12);
    verifyEqual(testCase, y, 2, 'AbsTol', 1e-12);
end

function testParallelReturnsNaN(testCase)
    [x, y] = sphynx.util.linesIntersection(2, 1, 2, 3);
    verifyTrue(testCase, isnan(x));
    verifyTrue(testCase, isnan(y));
end
