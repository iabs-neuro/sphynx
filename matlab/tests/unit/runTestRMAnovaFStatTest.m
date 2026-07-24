function tests = runTestRMAnovaFStatTest
% RUNTESTRMANOVAFSTATTEST  R31 audit #2: doRMAnova pulls the p-value from
% the within-subject effect row but the F statistic from row 1, which
% ranova always fills with the between-subjects '(Intercept)' term. The
% reported F therefore belonged to a different effect than the reported p.
%
% We reconstruct the exact RM model doRMAnova builds and assert runTest
% surfaces the within-session-effect F, not the intercept F.
    tests = functiontests(localfunctions);
end

function testStatIsWithinEffectFNotIntercept(testCase)
    assumeTrue(testCase, exist('fitrm', 'file') > 0, ...
        'Statistics and Machine Learning Toolbox required for RM-ANOVA');

    subjects = {'s1', 's2', 's3', 's4', 's5', 's6'};
    sessions = {'A', 'B', 'C'};
    base  = [100.0, 100.2, 99.8, 100.1, 99.9, 100.05];
    resid = 0.05 * [ 1 -1  0;
                    -1  1  0;
                     0  1 -1;
                     1  0 -1;
                    -1  0  1;
                     0 -1  1];
    Y = base' + resid;   % rows = subjects (stable order), cols = sessions

    subjCol = {}; sessCol = {}; valCol = [];
    for si = 1:numel(subjects)
        for ki = 1:numel(sessions)
            subjCol{end+1, 1} = subjects{si};   %#ok<AGROW>
            sessCol{end+1, 1} = sessions{ki};   %#ok<AGROW>
            valCol(end+1, 1)  = Y(si, ki);      %#ok<AGROW>
        end
    end
    L = table(subjCol, sessCol, valCol, ...
        'VariableNames', {'subject', 'session', 'value'});

    % Reconstruct the model doRMAnova builds internally.
    wideTbl = array2table(Y, 'VariableNames', {'wA', 'wB', 'wC'});
    rm = fitrm(wideTbl, 'wA-wC ~ 1', ...
        'WithinDesign', table((1:3)', 'VariableNames', {'session'}));
    ra = ranova(rm, 'WithinModel', 'session');
    iSess = find(contains(string(ra.Properties.RowNames), 'session'), 1);
    sessionF   = ra.F(iSess);
    interceptF = ra.F(1);
    % The test is only meaningful if the two rows actually differ.
    assumeTrue(testCase, abs(sessionF - interceptF) > 1);

    R = sphynx.stats.runTest(L, {'session'}, struct('test', 'rm-anova'));

    verifyEqual(testCase, R.test, 'rm-anova');
    verifyEqual(testCase, R.stat, sessionF, 'RelTol', 1e-6, ...
        'F must come from the within-session-effect row');
    verifyNotEqual(testCase, round(R.stat), round(interceptF), ...
        'F must not be the intercept-row statistic');
end
