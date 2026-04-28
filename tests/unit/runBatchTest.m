function tests = runBatchTest
    tests = functiontests(localfunctions);
end

function testTwoMockedSessions(testCase)
    % Build two fake "results" so we don't have to call analyzeSession.
    r1.Acts(1).ActName = 'rest';   r1.Acts(1).ActPercent = 10;  r1.Acts(1).ActNumber = 2;
    r1.Acts(2).ActName = 'walk';   r1.Acts(2).ActPercent = 80;  r1.Acts(2).ActNumber = 5;
    r2.Acts(1).ActName = 'rest';   r2.Acts(1).ActPercent = 30;  r2.Acts(1).ActNumber = 4;
    r2.Acts(2).ActName = 'walk';   r2.Acts(2).ActPercent = 60;  r2.Acts(2).ActNumber = 7;
    % Pad missing metric fields with [] so getfield doesn't error
    metricFields = {'ActMeanTime','ActMedianTime','ActDuration','ActVelocity','Distance','ActMeanDistance'};
    for k = 1:numel(metricFields)
        for line = 1:numel(r1.Acts)
            r1.Acts(line).(metricFields{k}) = NaN;
            r2.Acts(line).(metricFields{k}) = NaN;
        end
    end

    specs = struct( ...
        'sessionName', {'J01_1D', 'J01_2D'}, ...
        'mouse', {'J01', 'J01'}, ...
        'trial', {'1D', '2D'}, ...
        'dlcPath', {'', ''}, ...
        'presetPath', {'', ''});

    out = sphynx.pipeline.runBatch(specs, 'PreLoaded', [r1; r2]);

    verifyEqual(testCase, numel(out.results), 2);
    verifyTrue(testCase, ~isempty(out.tidy));
    verifyTrue(testCase, height(out.tidy) > 0);
    verifyEqual(testCase, height(out.wide), 1);  % 1 mouse

    % Check a specific cell: J01 rest ActPercent in 1D should be 10
    restPercent1D = out.tidy(...
        out.tidy.mouse == "J01" & ...
        out.tidy.actName == "rest" & ...
        out.tidy.metric == "ActPercent" & ...
        out.tidy.trial == "1D", :);
    verifyEqual(testCase, height(restPercent1D), 1);
    verifyEqual(testCase, restPercent1D.value, 10);
end

function testWidePivot(testCase)
    r1.Acts(1).ActName = 'rest'; r1.Acts(1).ActPercent = 10;
    r2.Acts(1).ActName = 'rest'; r2.Acts(1).ActPercent = 20;
    metricFields = {'ActNumber','ActMeanTime','ActMedianTime','ActDuration', ...
                    'ActVelocity','Distance','ActMeanDistance'};
    for k = 1:numel(metricFields)
        r1.Acts(1).(metricFields{k}) = NaN;
        r2.Acts(1).(metricFields{k}) = NaN;
    end

    specs = struct('sessionName', {'A_1D', 'B_1D'}, ...
                   'mouse', {'A', 'B'}, 'trial', {'1D', '1D'}, ...
                   'dlcPath', {'',''}, 'presetPath', {'',''});

    out = sphynx.pipeline.runBatch(specs, 'PreLoaded', [r1; r2]);
    verifyEqual(testCase, height(out.wide), 2);  % 2 mice
end
