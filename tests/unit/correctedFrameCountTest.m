function tests = correctedFrameCountTest
    tests = functiontests(localfunctions);
end

function testGoodCountPassThrough(testCase)
    % NumFrames matches duration*fps - return it as-is
    n = sphynx.preset.correctedFrameCount(2702, 137.4, 19.67);
    verifyEqual(testCase, n, 2702);
end

function testUnreliableLowReturnsFallback(testCase)
    % R2020a VideoReader bug: NumFrames=2 for VFR h264, real ~2702
    n = sphynx.preset.correctedFrameCount(2, 137.4, 19.67);
    expected = round(137.4 * 19.67);   % 2703
    verifyEqual(testCase, n, expected);
end

function testNanReturnsFallback(testCase)
    n = sphynx.preset.correctedFrameCount(NaN, 100, 30);
    verifyEqual(testCase, n, 3000);
end

function testZeroOrNegativeReturnsFallback(testCase)
    verifyEqual(testCase, sphynx.preset.correctedFrameCount(0, 60, 30), 1800);
    verifyEqual(testCase, sphynx.preset.correctedFrameCount(-5, 60, 30), 1800);
end

function testFallbackOnlyWhenSignificantlyOff(testCase)
    % If NumFrames is within 5% of duration*fps, trust it (avoids
    % rejecting accurate counts that differ by a few frames from rounding).
    n = sphynx.preset.correctedFrameCount(2700, 137.4, 19.67);
    verifyEqual(testCase, n, 2700);   % within ~0.1%, kept
end

function testBadFallbackInputReturnsOriginal(testCase)
    % If we can't compute fallback (no duration or no fps), return
    % whatever count we got (caller's responsibility).
    verifyEqual(testCase, sphynx.preset.correctedFrameCount(2, 0, 30), 2);
    verifyEqual(testCase, sphynx.preset.correctedFrameCount(2, 100, 0), 2);
    verifyEqual(testCase, sphynx.preset.correctedFrameCount(2, NaN, 30), 2);
end
