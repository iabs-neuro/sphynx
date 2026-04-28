function tests = ellipseFitTest
    tests = functiontests(localfunctions);
end

function testFitsKnownAxisAlignedEllipse(testCase)
    % Ellipse: center (10, 20), a = 5, b = 3, no tilt.
    th = linspace(0, 2*pi, 50)';
    x = 10 + 5 * cos(th);
    y = 20 + 3 * sin(th);
    e = sphynx.util.ellipseFit(x, y);
    verifyEqual(testCase, e.status, '');
    verifyEqual(testCase, e.X0_in, 10, 'AbsTol', 1e-6);
    verifyEqual(testCase, e.Y0_in, 20, 'AbsTol', 1e-6);
    verifyEqual(testCase, sort([e.a, e.b]), [3 5], 'AbsTol', 1e-6);
end

function testFitsCircleAsEllipse(testCase)
    th = linspace(0, 2*pi, 50)';
    x = 0 + 4*cos(th);  y = 0 + 4*sin(th);
    e = sphynx.util.ellipseFit(x, y);
    verifyEqual(testCase, e.status, '');
    verifyEqual(testCase, e.a, 4, 'AbsTol', 1e-6);
    verifyEqual(testCase, e.b, 4, 'AbsTol', 1e-6);
end

function testRejectsTooFewPoints(testCase)
    verifyError(testCase, @() sphynx.util.ellipseFit([1;2;3;4], [1;2;3;4]), ...
        'sphynx:ellipseFit:tooFewPoints');
end
