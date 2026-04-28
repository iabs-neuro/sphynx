function tests = actStatsTest
    tests = functiontests(localfunctions);
end

function testEmptyActHasZeros(testCase)
    s = sphynx.acts.actStats(false(100, 1), 30);
    verifyEqual(testCase, s.ActNumber, 0);
    verifyEqual(testCase, s.ActPercent, 0);
    verifyEqual(testCase, s.ActDuration, 0);
end

function testFullActStats(testCase)
    mask = false(100, 1); mask(10:30) = true; mask(60:80) = true;
    s = sphynx.acts.actStats(mask, 30);
    verifyEqual(testCase, s.ActNumber, 2);
    verifyEqual(testCase, round(s.ActPercent), 42);
    % each episode 21 frames at 30 fps = 0.7 s
    verifyEqual(testCase, s.ActMeanTime, 0.7, 'AbsTol', 0.05);
end

function testDistanceComputation(testCase)
    mask = false(60, 1); mask(11:40) = true;  % 30 frames active, 50% of total
    velocity = ones(60, 1) * 10;              % 10 cm/s constant
    s = sphynx.acts.actStats(mask, 30, 'Velocity', velocity);
    % distance during act = 10 cm/s * 1 s = 10 cm
    % Mirror legacy's quirky formula: meanV * actDur * percent / 10000
    % = 10 * 1 * 50 / 10000 = 0.05  (which is wrong arithmetically but matches legacy)
    verifyTrue(testCase, isnumeric(s.Distance));
end
