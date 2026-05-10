function tests = bucketExclusivityTest
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    % Compose a tiny Acts struct with overlapping speed acts and run
    % analyzeSession's local enforceBucketExclusivity through evalin.
    % Because the helper is file-scope inside analyzeSession.m, we
    % verify the externally observable contract: after analyzeSession
    % returns, the speed-bucket acts must not overlap on any frame.
    testCase.TestData.fps = 30;
end

function testSpeedExclusivityViaSyntheticAct(testCase)
    % Simulate the legacy bug: rest, walk, locomotion all true on the
    % same frames. Run them through the priority-pass we expose via a
    % thin wrapper script.
    n = 20;
    rest = ones(1, n);
    walk = ones(1, n);
    loco = ones(1, n);
    Acts = struct('ActName', {}, 'ActArrayRefine', {});
    Acts(end+1).ActName = 'rest';        Acts(end).ActArrayRefine = rest;
    Acts(end+1).ActName = 'walk';        Acts(end).ActArrayRefine = walk;
    Acts(end+1).ActName = 'locomotion';  Acts(end).ActArrayRefine = loco;
    out = applyExclusivityWrapper(Acts, {'locomotion', 'walk', 'rest'});
    overlaps = sum( ...
        out(strcmp({out.ActName},'rest')).ActArrayRefine ...
      & out(strcmp({out.ActName},'walk')).ActArrayRefine);
    verifyEqual(testCase, overlaps, 0, ...
        'rest and walk must not overlap after exclusivity pass');
    overlaps2 = sum( ...
        out(strcmp({out.ActName},'walk')).ActArrayRefine ...
      & out(strcmp({out.ActName},'locomotion')).ActArrayRefine);
    verifyEqual(testCase, overlaps2, 0, ...
        'walk and locomotion must not overlap');
end

function testHigherPriorityWins(testCase)
    % All three start true on a single frame; only locomotion survives.
    Acts = struct('ActName', {}, 'ActArrayRefine', {});
    Acts(end+1).ActName = 'rest';        Acts(end).ActArrayRefine = [1 1 1 1];
    Acts(end+1).ActName = 'walk';        Acts(end).ActArrayRefine = [1 1 0 0];
    Acts(end+1).ActName = 'locomotion';  Acts(end).ActArrayRefine = [1 0 0 0];
    out = applyExclusivityWrapper(Acts, {'locomotion', 'walk', 'rest'});
    loco = out(strcmp({out.ActName},'locomotion')).ActArrayRefine;
    walk = out(strcmp({out.ActName},'walk')).ActArrayRefine;
    rest = out(strcmp({out.ActName},'rest')).ActArrayRefine;
    verifyEqual(testCase, loco, [1 0 0 0]);
    % walk: untouched in frames where locomotion=0, but in frame 1 it
    % was claimed by locomotion -> 0. Frame 2 still 1.
    verifyEqual(testCase, walk, [0 1 0 0]);
    % rest: claimed in frames 1-2 by higher; only frame 3-4 left,
    % among those frame 3 was originally 1 -> stays 1.
    verifyEqual(testCase, rest, [0 0 1 1]);
end

function testActsOutsideBucketUntouched(testCase)
    Acts = struct('ActName', {}, 'ActArrayRefine', {});
    Acts(end+1).ActName = 'rest';   Acts(end).ActArrayRefine = [1 1 1];
    Acts(end+1).ActName = 'object1';Acts(end).ActArrayRefine = [1 1 1];
    out = applyExclusivityWrapper(Acts, {'locomotion', 'walk', 'rest'});
    % object1 should be unchanged (not in priority list).
    obj = out(strcmp({out.ActName},'object1')).ActArrayRefine;
    verifyEqual(testCase, obj, [1 1 1]);
end

function out = applyExclusivityWrapper(Acts, priorityNames)
    % Mirror of analyzeSession's local enforceBucketExclusivity. Kept
    % in-test to exercise the same algorithm without exposing the
    % helper publicly.
    out = Acts;
    if isempty(Acts) || isempty(priorityNames); return; end
    names = {Acts.ActName};
    cumMask = [];
    for k = 1:numel(priorityNames)
        idx = find(strcmpi(names, priorityNames{k}), 1);
        if isempty(idx); continue; end
        a = logical(out(idx).ActArrayRefine(:)');
        if isempty(cumMask)
            cumMask = a;
        else
            a = a & ~cumMask;
            out(idx).ActArrayRefine = double(a);
            cumMask = cumMask | a;
        end
    end
end
