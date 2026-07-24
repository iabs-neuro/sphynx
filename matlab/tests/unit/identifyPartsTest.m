function tests = identifyPartsTest
    tests = functiontests(localfunctions);
end

function testFindsCommonParts(testCase)
    names = {'nose', 'tailbase', 'bodycenter', 'leftear'};
    Point = sphynx.bodyparts.identifyParts(names);
    verifyEqual(testCase, Point.Nose, 1);
    verifyEqual(testCase, Point.Tailbase, 2);
    verifyEqual(testCase, Point.Center, 3);
    verifyEqual(testCase, Point.LeftEar, 4);
end

function testCaseInsensitive(testCase)
    names = {'Nose', 'TAILBASE', 'BodyCenter'};
    Point = sphynx.bodyparts.identifyParts(names);
    verifyEqual(testCase, Point.Nose, 1);
    verifyEqual(testCase, Point.Tailbase, 2);
    verifyEqual(testCase, Point.Center, 3);
end

function testCenterSynonyms(testCase)
    names = {'mass center'};
    Point = sphynx.bodyparts.identifyParts(names);
    verifyEqual(testCase, Point.Center, 1);
end

function testTailbaseSynonyms(testCase)
    names = {'tail base'};
    Point = sphynx.bodyparts.identifyParts(names);
    verifyEqual(testCase, Point.Tailbase, 1);
end

function testReturnsEmptyForMissing(testCase)
    names = {'nose'};
    Point = sphynx.bodyparts.identifyParts(names);
    verifyEqual(testCase, Point.Tailbase, []);
    verifyEqual(testCase, Point.Center, []);
end

function testSuperanimalTopviewmouseSchema(testCase)
    % DLC superanimal_topviewmouse layout (BARNES_v2 / 3_DLC) -- locks
    % in that we map underscored long-form labels onto the canonical
    % Center / Tailbase / ear / limb fields. Without these aliases
    % computeCenter would fall back to the synthetic mean.
    names = {'nose', 'left_ear', 'right_ear', 'head_midpoint', ...
             'left_shoulder', 'right_shoulder', ...
             'left_midside', 'right_midside', ...
             'left_hip', 'right_hip', ...
             'mouse_center', 'tail_base'};
    Point = sphynx.bodyparts.identifyParts(names);
    verifyEqual(testCase, Point.Nose,             1);
    verifyEqual(testCase, Point.LeftEar,          2);
    verifyEqual(testCase, Point.RightEar,         3);
    verifyEqual(testCase, Point.HeadCenter,       4);
    verifyEqual(testCase, Point.LeftForeLimb,     5);
    verifyEqual(testCase, Point.RightForeLimb,    6);
    verifyEqual(testCase, Point.LeftBodyCenter,   7);
    verifyEqual(testCase, Point.RightBodyCenter,  8);
    verifyEqual(testCase, Point.LeftHindLimb,     9);
    verifyEqual(testCase, Point.RightHindLimb,    10);
    verifyEqual(testCase, Point.Center,           11);
    verifyEqual(testCase, Point.Tailbase,         12);
end

function testCenterPrefersDirectOverMidside(testCase)
    % When mouse_center IS present we use it; the left/right midside
    % only matter as fallback in computeCenter, but identifyParts
    % records both -- we should still see Center pointing at the
    % explicit center marker.
    names = {'left_midside', 'right_midside', 'mouse_center'};
    Point = sphynx.bodyparts.identifyParts(names);
    verifyEqual(testCase, Point.Center, 3);
    verifyEqual(testCase, Point.LeftBodyCenter, 1);
    verifyEqual(testCase, Point.RightBodyCenter, 2);
end
