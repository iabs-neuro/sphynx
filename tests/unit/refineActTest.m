function tests = refineActTest
    tests = functiontests(localfunctions);
end

function testNoOpWhenAllRunsLongEnough(testCase)
    in = [0 0 1 1 1 1 0 0 1 1 1 1 0];
    [out, runs] = sphynx.acts.refineAct(in, 2, 2);
    verifyEqual(testCase, out, logical(in));
    verifyEqual(testCase, numel(runs), 2);
end

function testDropsShortOneRun(testCase)
    in = [0 0 1 0 0 1 1 1 1 0];
    [out, runs] = sphynx.acts.refineAct(in, 2, 0);
    verifyEqual(testCase, out, logical([0 0 0 0 0 1 1 1 1 0]));
    verifyEqual(testCase, numel(runs), 1);
end

function testClosesShortGap(testCase)
    in = [1 1 1 0 1 1 1];
    [out, ~] = sphynx.acts.refineAct(in, 1, 2);
    verifyEqual(testCase, out, logical([1 1 1 1 1 1 1]));
end

function testDoesNotCloseLeadingZeros(testCase)
    in = [0 1 1 1];
    [out, ~] = sphynx.acts.refineAct(in, 1, 2);
    verifyEqual(testCase, out, logical([0 1 1 1]));
end

function testRunsHaveCorrectFrameIndices(testCase)
    in = [0 1 1 0 0 1 1 1];
    [~, runs] = sphynx.acts.refineAct(in, 1, 0);
    verifyEqual(testCase, [runs(1).frameIn runs(1).frameOut runs(1).duration], [2 3 2]);
    verifyEqual(testCase, [runs(2).frameIn runs(2).frameOut runs(2).duration], [6 8 3]);
end

function testEmptyInput(testCase)
    [out, runs] = sphynx.acts.refineAct([], 1, 1);
    verifyEqual(testCase, out, logical([]));
    verifyEqual(testCase, numel(runs), 0);
end
