function tests = buildSuperTableTest
    tests = functiontests(localfunctions);
end

function batch = makeBatch()
    a1.ActName = 'rest';      a1.ActPercent = 30; a1.ActDuration = 180; a1.ActNumber = 8; a1.ActMeanTime = 22.5;
    a2.ActName = 'walk';      a2.ActPercent = 50; a2.ActDuration = 300; a2.ActNumber = 12; a2.ActMeanTime = 25.0;
    a3.ActName = 'locomotion';a3.ActPercent = 20; a3.ActDuration = 120; a3.ActNumber = 4; a3.ActMeanTime = 30.0;
    s1.SessionName = 'WNOF_J01_1D'; s1.Acts = [a1 a2 a3]; s1.Distance = 1500; s1.Velocity = 2.5;
    s2.SessionName = 'WNOF_J01_2D'; s2.Acts = [a1 a2 a3]; s2.Distance = 1700; s2.Velocity = 2.8;
    s3.SessionName = 'WNOF_J05_1D'; s3.Acts = [a1 a2 a3]; s3.Distance = 1300; s3.Velocity = 2.2;
    batch = [s1 s2 s3];
end

function testTidyHasRowsForEveryActMetricSession(testCase)
    batch = makeBatch();
    ST = sphynx.pipeline.buildSuperTable(batch);
    % 2 mice * 2 sessions for J01 + 1 session for J05? No — 3 sessions total
    % 3 sessions × 3 acts × 4 metrics = 36 rows
    verifyEqual(testCase, height(ST.Tidy), 36);
end

function testWideHasMouseColumn(testCase)
    batch = makeBatch();
    ST = sphynx.pipeline.buildSuperTable(batch);
    verifyTrue(testCase, ismember('mouse', ST.Wide.Properties.VariableNames));
    verifyEqual(testCase, height(ST.Wide), 2);   % 2 unique mice
end

function testWideContainsActMetricSessionColumns(testCase)
    batch = makeBatch();
    ST = sphynx.pipeline.buildSuperTable(batch);
    cols = ST.Wide.Properties.VariableNames;
    verifyTrue(testCase, any(contains(cols, 'rest_percent_1D')));
    verifyTrue(testCase, any(contains(cols, 'walk_count_2D')));
end

function testDistanceVelocityColumnsAdded(testCase)
    batch = makeBatch();
    ST = sphynx.pipeline.buildSuperTable(batch);
    cols = ST.Wide.Properties.VariableNames;
    verifyTrue(testCase, any(contains(cols, 'distance_cm_1D')));
    verifyTrue(testCase, any(contains(cols, 'velocity_cm_per_s_1D')));
end

function testNaNZeroPolicy(testCase)
    batch = makeBatch();
    ST = sphynx.pipeline.buildSuperTable(batch, 'NaNPolicy', 'zero');
    % J05 has no 2D session so its rest_percent_2D should be 0 (was NaN)
    j05Row = ST.Wide(strcmp(ST.Wide.mouse, 'J05'), :);
    verifyEqual(testCase, j05Row.rest_percent_2D, 0);
end

function testCustomMetadata(testCase)
    batch = makeBatch();
    meta = table( ...
        {'WNOF_J01_1D'; 'WNOF_J01_2D'; 'WNOF_J05_1D'}, ...
        {'J01'; 'J01'; 'J05'}, ...
        {'1D'; '2D'; '1D'}, ...
        {'control'; 'control'; 'test'}, ...
        {'C57Bl6'; 'C57Bl6'; 'C57Bl6'}, ...
        'VariableNames', {'session_name', 'mouse', 'session', 'group', 'line'});
    ST = sphynx.pipeline.buildSuperTable(batch, 'Metadata', meta);
    verifyTrue(testCase, ismember('group', ST.Wide.Properties.VariableNames));
    verifyTrue(testCase, ismember('line',  ST.Wide.Properties.VariableNames));
end
