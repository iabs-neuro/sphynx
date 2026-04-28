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
