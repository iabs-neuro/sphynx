function tests = readObjectsFieldSetTest
% READOBJECTSFIELDSETTEST  R31 audit #5: readObjects preallocates its
% output struct without the 'class' field that readArenaGeometry always
% sets, so `objects(k) = a` throws "dissimilar structures" on every real
% call. This test drives one object through headlessly via PointsPerObject.
    tests = functiontests(localfunctions);
end

function testReadObjectsBuildsWithoutFieldMismatch(testCase)
    frame = zeros(40, 40, 3, 'uint8');
    pts = [5 5; 30 5; 30 30; 5 30];  % a square polygon

    objects = sphynx.preset.readObjects(frame, {'Polygon'}, ...
        'PointsPerObject', {pts});

    verifyEqual(testCase, numel(objects), 1);
    verifyEqual(testCase, objects(1).type, 'object1');
    verifyTrue(testCase, isfield(objects, 'class'));
    verifyTrue(testCase, isfield(objects, 'mask'));
end

function testReadObjectsTwoObjects(testCase)
    frame = zeros(60, 60, 3, 'uint8');
    p1 = [5 5; 25 5; 25 25; 5 25];
    p2 = [35 35; 55 35; 55 55; 35 55];

    objects = sphynx.preset.readObjects(frame, {'Polygon', 'Polygon'}, ...
        'PointsPerObject', {p1, p2});

    verifyEqual(testCase, numel(objects), 2);
    verifyEqual(testCase, objects(2).type, 'object2');
end
