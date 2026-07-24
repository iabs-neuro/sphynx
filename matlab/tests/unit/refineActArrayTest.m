function tests = refineActArrayTest
    tests = functiontests(localfunctions);
end

function testZeroParamsKeepsInputUnchanged(testCase)
    in = logical([1 1 0 1 0 0 1 1 1 0 1]);
    out = sphynx.acts.refineActArray(in, 0, 0);
    verifyEqual(testCase, out, in);
end

function testDropsRunsShorterThanMin(testCase)
    in = logical([1 0 1 1 0 1 1 1 0 0 1]);   % runs of 1, 2, 3, 1
    out = sphynx.acts.refineActArray(in, 3, 0);
    expected = logical([0 0 0 0 0 1 1 1 0 0 0]);
    verifyEqual(testCase, out, expected);
end

function testKeepsRunOfExactlyMinLength(testCase)
    in = logical([0 1 1 1 0]);
    out = sphynx.acts.refineActArray(in, 3, 0);
    verifyEqual(testCase, out, in);
end

function testBridgesShortGap(testCase)
    in = logical([0 1 1 1 0 0 1 1 1 0 0 0 1 1 1 0]);
    %                       ^ gap of 2                 ^ gap of 3
    out = sphynx.acts.refineActArray(in, 0, 3);
    %                                ^^^^ bridge gaps < 3 frames
    expected = logical([0 1 1 1 1 1 1 1 1 0 0 0 1 1 1 0]);
    verifyEqual(testCase, out, expected);
end

function testLeadingZerosNotBridged(testCase)
    % Session-start zeros must stay zero — they're not "between events".
    in = logical([0 0 0 0 1 1 1 0]);
    out = sphynx.acts.refineActArray(in, 0, 100);
    verifyEqual(testCase, out, in);
end

function testRunTouchingLastFrameKept(testCase)
    in = logical([0 0 1 1 1]);
    out = sphynx.acts.refineActArray(in, 3, 0);
    verifyEqual(testCase, out, in);
end

function testEmptyInputReturnsEmpty(testCase)
    out = sphynx.acts.refineActArray(logical([]), 5, 5);
    verifyTrue(testCase, isempty(out));
    verifyClass(testCase, out, 'logical');
end

function testBridgeBeforeDropConsolidatesFragmentedAct(testCase)
    % Short fragment + small internal gap + longer fragment. With the
    % required bridge-then-drop order: the gap (2) bridges the two
    % fragments into a single 9-frame run, which then survives the
    % min-run=4 drop. With the wrong order (drop first) the 2-frame
    % fragment would die before the bridge, leaving only the 5-frame
    % survivor.
    in = logical([1 1 0 0 1 1 1 1 1 0]);
    %             ^^^ 2 ^^^^^^^^^ 5
    out = sphynx.acts.refineActArray(in, 4, 4);
    expected = logical([1 1 1 1 1 1 1 1 1 0]);
    verifyEqual(testCase, out, expected);
end
