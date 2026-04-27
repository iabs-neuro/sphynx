function tests = unwrapForSmoothTest
    tests = functiontests(localfunctions);
end

function testConstantInputUnchanged(testCase)
    in = ones(100, 1) * (pi/3);
    out = sphynx.angles.unwrapForSmooth(in, 11);
    verifyEqual(testCase, out, in, 'AbsTol', 1e-9);
end

function testNoArtifactAcrossDiscontinuity(testCase)
    % Build a signal that smoothly crosses pi from above to below.
    n = 200;
    t = (1:n)';
    raw = pi - 0.1 * (t - n/2) / (n/2);  % linearly through pi
    raw = sphynx.angles.wrap(raw);
    out = sphynx.angles.unwrapForSmooth(raw, 11);
    diffs = diff(out);
    diffs = sphynx.angles.wrap(diffs);
    verifyLessThan(testCase, max(abs(diffs)), 0.05);
end

function testOutputInRange(testCase)
    in = (rand(100,1) - 0.5) * 4*pi;
    out = sphynx.angles.unwrapForSmooth(in, 11);
    verifyTrue(testCase, all(out >= -pi & out <= pi));
end

function testRespectsWindowSize(testCase)
    rng(42);
    in = randn(50, 1) * 0.1;
    out11 = sphynx.angles.unwrapForSmooth(in, 11);
    out3  = sphynx.angles.unwrapForSmooth(in, 3);
    verifyLessThan(testCase, std(out11), std(out3));
end
