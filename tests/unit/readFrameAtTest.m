function tests = readFrameAtTest
    tests = functiontests(localfunctions);
end

function testReadsFirstFrame(testCase)
    vid = 'Demo/BARNES/2_Video/VIDEO_20260411_130747271.mp4';
    if ~isfile(vid)
        assumeTrue(testCase, false, 'BARNES video not present -- skip');
    end
    frame = sphynx.preset.readFrameAt(vid, 1, 19.67);
    verifyEqual(testCase, ndims(frame), 3);
    verifyEqual(testCase, size(frame, 3), 3);
end

function testReadsMidFrameOnVFR(testCase)
    % Regression for A1 follow-up: read(v, 1400) fails on VFR h264
    % in R2020a; CurrentTime-based seek works.
    vid = 'Demo/BARNES/2_Video/VIDEO_20260411_130747271.mp4';
    if ~isfile(vid)
        assumeTrue(testCase, false, 'BARNES video not present -- skip');
    end
    frame = sphynx.preset.readFrameAt(vid, 1400, 19.67);
    verifyEqual(testCase, size(frame, 3), 3);
end

function testFallbackOnPastEndSeek(testCase)
    vid = 'Demo/BARNES/2_Video/VIDEO_20260411_130747271.mp4';
    if ~isfile(vid)
        assumeTrue(testCase, false, 'BARNES video not present -- skip');
    end
    % t = 9999/19.67 = ~508s, far past 135s duration -> fallback to frame 1
    frame = sphynx.preset.readFrameAt(vid, 9999, 19.67);
    verifyEqual(testCase, size(frame, 3), 3);
end
