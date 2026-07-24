function tests = actStatsTest
    tests = functiontests(localfunctions);
end

function testEmptyActHasZeros(testCase)
    s = sphynx.acts.actStats(false(100, 1), 30);
    verifyEqual(testCase, s.ActNumber, 0);
    verifyEqual(testCase, s.ActPercent, 0);
    verifyEqual(testCase, s.ActDuration, 0);
    verifyTrue(testCase, isnan(s.FirstStartSec));
    verifyTrue(testCase, isnan(s.LastEndSec));
end

function testFullActStats(testCase)
    mask = false(100, 1); mask(10:30) = true; mask(60:80) = true;
    s = sphynx.acts.actStats(mask, 30);
    verifyEqual(testCase, s.ActNumber, 2);
    verifyEqual(testCase, round(s.ActPercent), 42);
    % each episode 21 frames at 30 fps = 0.7 s
    verifyEqual(testCase, s.ActMeanTime, 0.7, 'AbsTol', 0.05);
end

function testMeanVelocityIsActualMean(testCase)
    % Active frames have v = linspace(10, 20). Mean MUST be ~15,
    % not the legacy ActPercent-based estimate.
    n = 100; fps = 30;
    mask = false(n, 1); mask(11:60) = true;
    velocity = zeros(n, 1);
    velocity(11:60) = linspace(10, 20, 50);
    s = sphynx.acts.actStats(mask, fps, 'Velocity', velocity);
    expected = mean(linspace(10, 20, 50));
    verifyEqual(testCase, s.ActMeanVelocity, expected, 'AbsTol', 0.05);
    verifyEqual(testCase, s.ActVelocity, s.ActMeanVelocity);
end

function testLocomotionMeanAboveThreshold(testCase)
    % Regression for the user-reported bug: mean velocity over the
    % "locomotion" frames (v >= 5 cm/s) must itself be >= 5.
    n = 200; fps = 30;
    velocity = zeros(n, 1);
    velocity(50:150) = 5 + rand(101, 1) * 10;   % uniform in [5, 15]
    mask = velocity >= 5;
    s = sphynx.acts.actStats(mask, fps, 'Velocity', velocity);
    verifyGreaterThanOrEqual(testCase, s.ActMeanVelocity, 5);
end

function testDistanceIsSumOverFps(testCase)
    n = 60; fps = 30;
    mask = false(n, 1); mask(1:30) = true;
    velocity = ones(n, 1) * 6;       % 6 cm/s for 1 second
    s = sphynx.acts.actStats(mask, fps, 'Velocity', velocity);
    % 30 frames * 6 cm/s / 30 fps = 6 cm
    verifyEqual(testCase, s.Distance, 6, 'AbsTol', 0.05);
end

function testEpisodeBoundaries(testCase)
    n = 100; fps = 30;
    mask = false(n, 1);
    mask(31:40) = true;          % first run: frames 31..40
    mask(81:90) = true;          % second run: frames 81..90
    s = sphynx.acts.actStats(mask, fps, 'Velocity', ones(n,1));
    verifyEqual(testCase, s.ActNumber, 2);
    verifyEqual(testCase, s.FirstStartSec, (31-1)/fps, 'AbsTol', 0.01);
    verifyEqual(testCase, s.FirstEndSec,   (40-1)/fps, 'AbsTol', 0.01);
    verifyEqual(testCase, s.LastStartSec,  (81-1)/fps, 'AbsTol', 0.01);
    verifyEqual(testCase, s.LastEndSec,    (90-1)/fps, 'AbsTol', 0.01);
end

function testFirstAndRestDurationSplit(testCase)
    % First episode = frames 11..20 = 10 frames @ fps=10 -> 1.0 s.
    % Second episode = frames 31..50 = 20 frames @ fps=10 -> 2.0 s.
    % Third episode  = frames 71..80 = 10 frames @ fps=10 -> 1.0 s.
    % ActDuration = 4.0; FirstDurationSec = 1.0; RestDurationSec = 3.0.
    n = 100; fps = 10;
    mask = false(n, 1);
    mask(11:20) = true;
    mask(31:50) = true;
    mask(71:80) = true;
    s = sphynx.acts.actStats(mask, fps);
    verifyEqual(testCase, s.ActNumber, 3);
    verifyEqual(testCase, s.ActDuration, 4.0, 'AbsTol', 0.05);
    verifyEqual(testCase, s.FirstDurationSec, 1.0, 'AbsTol', 0.05);
    verifyEqual(testCase, s.RestDurationSec, 3.0, 'AbsTol', 0.05);
end

function testSingleEpisodeRestIsZero(testCase)
    n = 50; fps = 10;
    mask = false(n, 1); mask(5:14) = true;       % 10 frames -> 1.0 s
    s = sphynx.acts.actStats(mask, fps);
    verifyEqual(testCase, s.ActNumber, 1);
    verifyEqual(testCase, s.FirstDurationSec, 1.0, 'AbsTol', 0.05);
    verifyEqual(testCase, s.RestDurationSec, 0);
end

function testEmptyActFirstRestAreNaN(testCase)
    s = sphynx.acts.actStats(false(50, 1), 10);
    verifyTrue(testCase, isnan(s.FirstDurationSec));
    verifyTrue(testCase, isnan(s.RestDurationSec));
end

function testMaxMinVelocity(testCase)
    n = 50;
    mask = false(n, 1); mask(11:30) = true;
    velocity = zeros(n, 1);
    velocity(11:30) = [3 7 9 5 6 8 12 4 10 7 5 6 9 8 7 6 5 4 3 11];
    s = sphynx.acts.actStats(mask, 30, 'Velocity', velocity);
    verifyEqual(testCase, s.ActMaxVelocity, 12);
    verifyEqual(testCase, s.ActMinVelocity, 3);
end
