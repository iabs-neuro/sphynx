function tests = velocityJumpFilterTest
% VELOCITYJUMPFILTERTEST  Unit tests for sphynx.preprocess.velocityJumpFilter.
    tests = functiontests(localfunctions);
end

function testFlagsObviousJump(testCase)
    % Linear walk with one teleport at frame 50.
    % Note: a single-frame teleport produces TWO bad frames — one going
    % out (bad(50)) and one coming back (bad(51)).
    n = 200;
    X = (1:n)';
    Y = ones(n, 1) * 100;
    X(50) = 5000;  % giant jump
    [Xo, Yo, bad] = sphynx.preprocess.velocityJumpFilter(X, Y, 30, 5, 50);
    verifyTrue(testCase, bad(50));
    verifyTrue(testCase, bad(51));
    verifyTrue(testCase, isnan(Xo(50)));
    verifyTrue(testCase, isnan(Yo(50)));
    verifyEqual(testCase, sum(bad), 2);
end

function testNoJumpsLeavesIntact(testCase)
    n = 100;
    X = (1:n)';  % 1 px/frame -> 30 px/s -> 6 cm/s with pxlPerCm=5
    Y = ones(n, 1) * 100;
    [Xo, Yo, bad] = sphynx.preprocess.velocityJumpFilter(X, Y, 30, 5, 50);
    verifyFalse(testCase, any(bad));
    verifyEqual(testCase, Xo, X);
    verifyEqual(testCase, Yo, Y);
end

function testNanSafe(testCase)
    n = 50;
    X = (1:n)';
    Y = ones(n, 1) * 100;
    X(20) = NaN;
    [~, ~, bad] = sphynx.preprocess.velocityJumpFilter(X, Y, 30, 5, 50);
    verifyFalse(testCase, any(bad));  % NaN doesn't propagate to a flag
end

function testTooShortInputReturnsUnchanged(testCase)
    % 2 frames moving 1 px = 1/5 cm at 30 fps -> 6 cm/s, well below 50.
    [Xo, Yo, bad] = sphynx.preprocess.velocityJumpFilter([10; 11], [10; 11], 30, 5, 50);
    verifyEqual(testCase, Xo, [10; 11]);
    verifyEqual(testCase, Yo, [10; 11]);
    verifyFalse(testCase, any(bad));
end

function testFlagsIndexAfterJump(testCase)
    % Documents the convention: flag is on the post-jump frame, not pre.
    n = 100;
    X = (1:n)';
    Y = ones(n, 1) * 100;
    X(60) = 9000;
    [~, ~, bad] = sphynx.preprocess.velocityJumpFilter(X, Y, 30, 5, 50);
    verifyTrue(testCase, bad(60));
    verifyFalse(testCase, bad(59));
end
