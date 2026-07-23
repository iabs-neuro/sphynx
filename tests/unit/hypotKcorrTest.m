function tests = hypotKcorrTest
    tests = functiontests(localfunctions);
end

function testIdentityKcorr(testCase)
    verifyEqual(testCase, sphynx.geom.hypotKcorr(3, 4, 1), 5, 'AbsTol', 1e-12);
end

function testDefaultKcorrOne(testCase)
    verifyEqual(testCase, sphynx.geom.hypotKcorr(3, 4), 5, 'AbsTol', 1e-12);
end

function testStretchesXComponent(testCase)
    verifyEqual(testCase, sphynx.geom.hypotKcorr(3, 4, 2), sqrt((6)^2 + 16), 'AbsTol', 1e-12);
end

function testPureYUnaffected(testCase)
    verifyEqual(testCase, sphynx.geom.hypotKcorr(0, 7, 3), 7, 'AbsTol', 1e-12);
end

function testVectorized(testCase)
    dx = [3; 0; 1]; dy = [4; 5; 0];
    d = sphynx.geom.hypotKcorr(dx, dy, 2);
    verifyEqual(testCase, d, sqrt((dx*2).^2 + dy.^2), 'AbsTol', 1e-12);
end
