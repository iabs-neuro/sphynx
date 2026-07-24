function tests = detectSessionStartFrameTest
    tests = functiontests(localfunctions);
end

function testBarnesRealFile(testCase)
    csv = fullfile(projectRoot(), 'Demo', 'BARNES', '3_DLC', ...
        '2024_11_02_17_16_42_test_cr_reencoded_superanimal_topviewmouse_snapshot.csv');
    assumeTrue(testCase, isfile(csv), 'BARNES sample CSV not present');
    dlc = sphynx.io.readDLC(csv);
    [startF, info] = sphynx.preprocess.detectSessionStartFrame(dlc);
    % Animal0 first becomes populated around data row 96 in this file
    % (-> frame index 96 in 1-based DLC frame numbering).
    verifyGreaterThan(testCase, startF, 1);
    verifyLessThan(testCase, startF, 200, ...
        sprintf('Expected start near ~96, got %d (info: %s)', ...
        startF, info.message));
end

function testDetectsFromFrameOneWhenAlwaysPopulated(testCase)
    dlc = makeDlc(repmat([10; 20; 30], 1, 100), repmat([5; 8; 11], 1, 100));
    startF = sphynx.preprocess.detectSessionStartFrame(dlc);
    verifyEqual(testCase, startF, 1);
end

function testDetectsLateStart(testCase)
    % 50 NaN frames, then 100 populated frames.
    X = [NaN(3, 50), repmat([10; 20; 30], 1, 100)];
    Y = [NaN(3, 50), repmat([5; 8; 11], 1, 100)];
    dlc = makeDlc(X, Y);
    startF = sphynx.preprocess.detectSessionStartFrame(dlc, ...
        'WindowFrames', 20, 'WindowFillRatio', 0.8);
    verifyEqual(testCase, startF, 51);
end

function testFallbackWhenNeverPopulated(testCase)
    X = NaN(3, 100);
    Y = NaN(3, 100);
    dlc = makeDlc(X, Y);
    [startF, info] = sphynx.preprocess.detectSessionStartFrame(dlc);
    verifyEqual(testCase, startF, 1);
    verifyTrue(testCase, ~isempty(info.message));
end

function testNegativeCoordsCountAsMissing(testCase)
    % DLC -1.0 sentinel: detectSessionStartFrame doesn't normalize, but
    % anything < 0 is treated as missing. Half the frames are -1, then
    % populated.
    X = [-ones(3, 40), repmat([10; 20; 30], 1, 100)];
    Y = [-ones(3, 40), repmat([5; 8; 11], 1, 100)];
    dlc = makeDlc(X, Y);
    startF = sphynx.preprocess.detectSessionStartFrame(dlc, ...
        'WindowFrames', 20, 'WindowFillRatio', 0.8);
    verifyEqual(testCase, startF, 41);
end

function testSnapsToFirstPopulatedFrame(testCase)
    % Rolling threshold crosses while current frame is empty -> snap
    % to next populated frame.
    X = NaN(3, 100);
    Y = NaN(3, 100);
    % Populated frames 30 onward, but two empty gaps right after 30.
    X(:, 30:100) = repmat([10; 20; 30], 1, 71);
    Y(:, 30:100) = repmat([5; 8; 11], 1, 71);
    X(:, 32:33) = NaN;
    Y(:, 32:33) = NaN;
    dlc = makeDlc(X, Y);
    startF = sphynx.preprocess.detectSessionStartFrame(dlc, ...
        'WindowFrames', 10, 'WindowFillRatio', 0.5);
    % First populated frame is 30; algorithm should land at 30 or later
    % (depending on window arithmetic), never on an empty frame.
    verifyGreaterThanOrEqual(testCase, startF, 30);
    verifyLessThan(testCase, startF, 40);
    verifyFalse(testCase, isnan(X(1, startF)), 'Start landed on NaN');
end

function root = projectRoot()
    root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end

function dlc = makeDlc(X, Y)
    dlc.X = X;
    dlc.Y = Y;
    dlc.likelihood = ones(size(X));
    dlc.bodyPartsNames = arrayfun(@(k) sprintf('bp%d', k), 1:size(X, 1), ...
        'UniformOutput', false);
    dlc.nFrames = size(X, 2);
end
