function tests = resolvePartTest
% RESOLVEPARTTEST  Coverage for sphynx.bodyparts.resolvePart -- the
%   alias-tolerant body-part name lookup used by applyAct, freezing,
%   and rear.
    tests = functiontests(localfunctions);
end

function testExactMatchWins(testCase)
    parts = {'nose', 'tailbase', 'bodycenter'};
    verifyEqual(testCase, sphynx.bodyparts.resolvePart(parts, 'bodycenter'), 3);
end

function testExactMatchCaseInsensitive(testCase)
    parts = {'Nose', 'TailBase', 'BodyCenter'};
    verifyEqual(testCase, sphynx.bodyparts.resolvePart(parts, 'bodycenter'), 3);
end

function testSuperanimalToLegacyBodyCenter(testCase)
    % Library writes 'bodycenter'; DLC has 'mouse_center' instead.
    parts = {'nose', 'tail_base', 'mouse_center', 'left_midside'};
    verifyEqual(testCase, sphynx.bodyparts.resolvePart(parts, 'bodycenter'), 3);
end

function testSuperanimalToLegacyTailbase(testCase)
    parts = {'nose', 'mouse_center', 'tail_base'};
    verifyEqual(testCase, sphynx.bodyparts.resolvePart(parts, 'tailbase'), 3);
end

function testSuperanimalToLegacyHindLimbs(testCase)
    parts = {'nose', 'mouse_center', 'left_hip', 'right_hip'};
    verifyEqual(testCase, sphynx.bodyparts.resolvePart(parts, 'lefthindlimb'), 3);
    verifyEqual(testCase, sphynx.bodyparts.resolvePart(parts, 'righthindlimb'), 4);
end

function testSuperanimalToLegacyHeadCenter(testCase)
    parts = {'nose', 'head_midpoint', 'mouse_center'};
    verifyEqual(testCase, sphynx.bodyparts.resolvePart(parts, 'headcenter'), 2);
end

function testReverseDirectionAliasResolves(testCase)
    % Library writes 'mouse_center' (canonical-by-alias), DLC has the
    % legacy 'bodycenter' -- should still resolve via the canonical.
    parts = {'nose', 'tailbase', 'bodycenter'};
    verifyEqual(testCase, sphynx.bodyparts.resolvePart(parts, 'mouse_center'), 3);
end

function testReturnsEmptyForUnknown(testCase)
    parts = {'nose', 'tailbase'};
    verifyEqual(testCase, sphynx.bodyparts.resolvePart(parts, 'wholly_unknown_part'), []);
end

function testEmptyInputsReturnEmpty(testCase)
    verifyEqual(testCase, sphynx.bodyparts.resolvePart({}, 'bodycenter'), []);
    verifyEqual(testCase, sphynx.bodyparts.resolvePart({'nose'}, ''), []);
end

function testPrefersExactOverSynonym(testCase)
    % If 'bodycenter' literally exists in the list AND a synonym
    % ('mouse_center') is also there, the exact match wins -- never
    % surprises a user who explicitly named a part.
    parts = {'mouse_center', 'bodycenter'};
    verifyEqual(testCase, sphynx.bodyparts.resolvePart(parts, 'bodycenter'), 2);
end
