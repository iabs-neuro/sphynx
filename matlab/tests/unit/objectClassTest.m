function tests = objectClassTest
    tests = functiontests(localfunctions);
end

function testDefaultClassEmpty(testCase)
    frame = uint8(zeros(100, 100, 3));
    pts = [10 10; 30 10; 30 30; 10 30];
    obj = sphynx.preset.readArenaGeometry(frame, 'Polygon', 'Points', pts);
    verifyTrue(testCase, isfield(obj, 'class'));
    verifyEqual(testCase, obj.class, '');
end

function testClassPersistsThroughStructAssign(testCase)
    frame = uint8(zeros(100, 100, 3));
    pts = [10 10; 30 10; 30 30; 10 30];
    obj = sphynx.preset.readArenaGeometry(frame, 'Polygon', 'Points', pts);
    obj.class = 'neutral';
    objects = obj;
    obj2 = sphynx.preset.readArenaGeometry(frame, 'Polygon', 'Points', pts);
    obj2.class = 'target';
    objects(end+1) = obj2;
    verifyEqual(testCase, objects(1).class, 'neutral');
    verifyEqual(testCase, objects(2).class, 'target');
end
