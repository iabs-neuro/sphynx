function tests = readArenaGeometryOverlayTest
    tests = functiontests(localfunctions);
end

function testExistingObjectsParamDoesNotChangeOutput(testCase)
    frame = uint8(zeros(100, 100, 3));
    pts = [10 10; 30 10; 30 30; 10 30];
    existing = struct('border_x', {[5;15;15;5]}, 'border_y', {[5;5;15;15]});
    obj = sphynx.preset.readArenaGeometry(frame, 'Polygon', ...
        'Points', pts, 'ExistingObjects', existing);
    verifyEqual(testCase, obj.type, 'Arena');
    verifyEqual(testCase, obj.geometry, 'Polygon');
end

function testEmptyExistingObjectsParamWorks(testCase)
    frame = uint8(zeros(100, 100, 3));
    pts = [10 10; 30 10; 30 30; 10 30];
    obj = sphynx.preset.readArenaGeometry(frame, 'Polygon', ...
        'Points', pts, 'ExistingObjects', []);
    verifyEqual(testCase, obj.type, 'Arena');
end
