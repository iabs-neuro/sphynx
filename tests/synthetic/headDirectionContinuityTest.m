function tests = headDirectionContinuityTest
% HEADDIRECTIONCONTINUITYTEST  Mouse rotates 720 deg; HD must be smooth.
    tests = functiontests(localfunctions);
end

function testNoLargeJumpsAfterSmoothing(testCase)
    f = sphynx.testing.makeRotatingMouseDLC(720, 4);
    hd = sphynx.angles.headDirection(f.headTipX, f.headTipY, ...
                                      f.headCenterX, f.headCenterY, 11);
    diffs = sphynx.angles.wrap(diff(hd));
    verifyLessThan(testCase, max(abs(diffs)), 0.5, ...
        'Bug-2: HD has > 0.5 rad jump between consecutive samples');
end

function testHDinValidRange(testCase)
    f = sphynx.testing.makeRotatingMouseDLC(720, 4);
    hd = sphynx.angles.headDirection(f.headTipX, f.headTipY, ...
                                      f.headCenterX, f.headCenterY, 11);
    verifyTrue(testCase, all(hd >= -pi & hd <= pi));
end

function testTotalRotationApproximatelyCorrect(testCase)
    f = sphynx.testing.makeRotatingMouseDLC(720, 4);
    hd = sphynx.angles.headDirection(f.headTipX, f.headTipY, ...
                                      f.headCenterX, f.headCenterY, 11);
    unwrapped = unwrap(hd);
    actualRotation = unwrapped(end) - unwrapped(1);
    verifyEqual(testCase, actualRotation, f.expectedTotalRotationRad, ...
        'AbsTol', 0.1);
end
