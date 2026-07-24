function tests = computeCenterTest
% COMPUTECENTERTEST  Locks in the three resolution paths for
%   sphynx.bodyparts.computeCenter:
%     1) Point.Center wins outright
%     2) Otherwise mean of LeftBodyCenter + RightBodyCenter
%     3) Otherwise synthetic mean of every body part (with warning,
%        no error) -- so unknown DLC schemas don't kill Make-video.
    tests = functiontests(localfunctions);
end

function testCenterTakesPrecedence(testCase)
    BPX = [1 2 3; 10 20 30; 100 200 300];  % 3 parts, 3 frames
    BPY = [4 5 6; 40 50 60; 400 500 600];
    Point = makePoint('Center', 2, 'LeftBodyCenter', 1, 'RightBodyCenter', 3);
    [xc, yc] = sphynx.bodyparts.computeCenter(BPX, BPY, Point);
    verifyEqual(testCase, xc, [10 20 30]);
    verifyEqual(testCase, yc, [40 50 60]);
end

function testFallsBackToLeftRightMean(testCase)
    BPX = [10 20 30; 30 40 50];   % 2 parts: Left then Right
    BPY = [5 6 7; 15 16 17];
    Point = makePoint('Center', [], 'LeftBodyCenter', 1, 'RightBodyCenter', 2);
    [xc, yc] = sphynx.bodyparts.computeCenter(BPX, BPY, Point);
    verifyEqual(testCase, xc, [20 30 40]);
    verifyEqual(testCase, yc, [10 11 12]);
end

function testSyntheticMeanWhenNoneFound(testCase)
    % No Center, no Left/Right -- we should not throw. Synthetic mean
    % across rows (with NaN ignored) replaces the previous error path.
    BPX = [1 2 3; 3 4 5; 5 6 7];
    BPY = [10 20 30; 30 40 50; 50 60 70];
    Point = makePoint('Center', [], 'LeftBodyCenter', [], 'RightBodyCenter', []);
    [xc, yc] = sphynx.bodyparts.computeCenter(BPX, BPY, Point);
    verifyEqual(testCase, xc, [3 4 5]);
    verifyEqual(testCase, yc, [30 40 50]);
end

function testNanIgnoredInSyntheticMean(testCase)
    % NaN entries are skipped column-wise -- prevents a single missing
    % body-part from dragging the synthetic center to NaN.
    BPX = [NaN 2 3; 3 4 5; 5 6 NaN];
    BPY = [10 20 30; 30 40 50; 50 60 70];
    Point = makePoint('Center', [], 'LeftBodyCenter', [], 'RightBodyCenter', []);
    [xc, yc] = sphynx.bodyparts.computeCenter(BPX, BPY, Point);
    verifyEqual(testCase, xc, [4 4 4]);
    verifyEqual(testCase, yc, [30 40 50]);
end

function testEmptyMatricesReturnEmpty(testCase)
    Point = makePoint('Center', [], 'LeftBodyCenter', [], 'RightBodyCenter', []);
    [xc, yc] = sphynx.bodyparts.computeCenter([], [], Point);
    verifyEqual(testCase, numel(xc), 0);
    verifyEqual(testCase, numel(yc), 0);
end

function testOnlyOneOfLeftRightFallsThroughToSynthetic(testCase)
    % LeftBodyCenter set but RightBodyCenter empty -- the (Left+Right)/2
    % branch requires BOTH, so we should fall through to the synthetic
    % mean rather than crash.
    BPX = [2 4 6; 8 10 12];
    BPY = [1 3 5; 7 9 11];
    Point = makePoint('Center', [], 'LeftBodyCenter', 1, 'RightBodyCenter', []);
    [xc, yc] = sphynx.bodyparts.computeCenter(BPX, BPY, Point);
    verifyEqual(testCase, xc, [5 7 9]);
    verifyEqual(testCase, yc, [4 6 8]);
end

% --- helpers -------------------------------------------------------------
function Point = makePoint(varargin)
    canon = {'MiniscopeUCLA', 'Nose', 'LeftEar', 'RightEar', 'HeadCenter', ...
             'LeftForeLimb', 'RightForeLimb', 'LeftBodyCenter', ...
             'RightBodyCenter', 'LeftHindLimb', 'RightHindLimb', ...
             'Tailbase', 'Center'};
    Point = struct();
    for k = 1:numel(canon); Point.(canon{k}) = []; end
    for k = 1:2:numel(varargin)
        Point.(varargin{k}) = varargin{k + 1};
    end
end
