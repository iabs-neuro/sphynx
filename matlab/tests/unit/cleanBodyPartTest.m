function tests = cleanBodyPartTest
    tests = functiontests(localfunctions);
end

function testCleanInputUnchanged(testCase)
    n = 100;
    x = 1 + rand(n,1) * 100;   % keep all >= 1 to pass the bounds filter
    y = 1 + rand(n,1) * 100;
    lk = ones(n,1);
    out = sphynx.preprocess.cleanBodyPart(x, y, lk);
    verifyEqual(testCase, out.X, x);
    verifyEqual(testCase, out.Y, y);
    verifyEqual(testCase, out.Status, 'Good');
    verifyEqual(testCase, out.PercentBadCombined, 0);
end

function testNaNInputBecomesNaNOutput(testCase)
    x = [10; NaN; 30]; y = [10; 20; 30]; lk = ones(3,1);
    out = sphynx.preprocess.cleanBodyPart(x, y, lk);
    verifyTrue(testCase, isnan(out.X(2)));
    verifyTrue(testCase, isnan(out.Y(2)));
end

function testLowLikelihoodMasked(testCase)
    x = [10; 20; 30]; y = [10; 20; 30];
    lk = [0.99; 0.5; 0.99];
    out = sphynx.preprocess.cleanBodyPart(x, y, lk, 'LikelihoodThreshold', 0.95);
    verifyTrue(testCase, isnan(out.X(2)));
    verifyEqual(testCase, out.PercentLowLikelihood, round(100/3, 2));
end

function testOutOfBoundsMasked(testCase)
    x = [10; 200; 30]; y = [10; 20; 30]; lk = ones(3,1);
    out = sphynx.preprocess.cleanBodyPart(x, y, lk, 'FrameWidth', 100, 'FrameHeight', 100);
    verifyTrue(testCase, isnan(out.X(2)));
end

function testStatusNotFoundWhenMostlyBad(testCase)
    n = 100;
    x = rand(n,1) * 100; y = rand(n,1) * 100;
    lk = zeros(n,1);  % all below threshold
    out = sphynx.preprocess.cleanBodyPart(x, y, lk);
    verifyEqual(testCase, out.Status, 'NotFound');
end
