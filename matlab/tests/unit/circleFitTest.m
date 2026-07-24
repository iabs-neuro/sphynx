function tests = circleFitTest
    tests = functiontests(localfunctions);
end

function testFitsKnownUnitCircle(testCase)
    th = linspace(0, 2*pi, 100)';
    x = cos(th); y = sin(th);
    [xc, yc, r] = sphynx.util.circleFit(x, y);
    verifyEqual(testCase, xc, 0, 'AbsTol', 1e-9);
    verifyEqual(testCase, yc, 0, 'AbsTol', 1e-9);
    verifyEqual(testCase, r, 1, 'AbsTol', 1e-9);
end

function testFitsOffsetCircle(testCase)
    th = linspace(0, 2*pi, 50)';
    x = 5 + 3*cos(th); y = -7 + 3*sin(th);
    [xc, yc, r] = sphynx.util.circleFit(x, y);
    verifyEqual(testCase, xc, 5, 'AbsTol', 1e-9);
    verifyEqual(testCase, yc, -7, 'AbsTol', 1e-9);
    verifyEqual(testCase, r, 3, 'AbsTol', 1e-9);
end

function testFitsThreeNonCollinearPoints(testCase)
    th = [0; 2*pi/3; 4*pi/3];
    x = cos(th); y = sin(th);
    [xc, yc, r] = sphynx.util.circleFit(x, y);
    verifyEqual(testCase, xc, 0, 'AbsTol', 1e-9);
    verifyEqual(testCase, yc, 0, 'AbsTol', 1e-9);
    verifyEqual(testCase, r, 1, 'AbsTol', 1e-9);
end

function testRejectsTooFewPoints(testCase)
    verifyError(testCase, @() sphynx.util.circleFit([0;1],[0;0]), ...
        'sphynx:circleFit:tooFewPoints');
end

function testRejectsCollinearPoints(testCase)
    verifyError(testCase, @() sphynx.util.circleFit([0;1;2;3],[0;0;0;0]), ...
        'sphynx:circleFit:degenerate');
end
