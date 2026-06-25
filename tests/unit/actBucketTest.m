function tests = actBucketTest
% ACTBUCKETTEST  +sphynx/+util/actBucket regression + extended-shape
%   coverage. Locks in the four buckets (speed/spatial/posture/composite)
%   for every zone-name shape emitted by current CreatePreset strategies,
%   plus the Barnes-style object/target/start naming.
    tests = functiontests(localfunctions);
end

% --- speed bucket --------------------------------------------------------
function testRestWalkLocomotion(testCase)
    verifyEqual(testCase, sphynx.util.actBucket('rest'),       'speed');
    verifyEqual(testCase, sphynx.util.actBucket('walk'),       'speed');
    verifyEqual(testCase, sphynx.util.actBucket('locomotion'), 'speed');
end

function testSpeedCaseInsensitive(testCase)
    verifyEqual(testCase, sphynx.util.actBucket('Rest'),       'speed');
    verifyEqual(testCase, sphynx.util.actBucket('LOCOMOTION'), 'speed');
end

% --- posture bucket ------------------------------------------------------
function testFreezingRear(testCase)
    verifyEqual(testCase, sphynx.util.actBucket('freezing'), 'posture');
    verifyEqual(testCase, sphynx.util.actBucket('rear'),     'posture');
end

% --- spatial: legacy fixed names ----------------------------------------
function testLegacyZoneNamesSpatial(testCase)
    legacy = {'corners', 'walls', 'walls_and_corners', 'center', ...
              'middle_zone', 'wall', 'middle', 'arena'};
    for k = 1:numel(legacy)
        verifyEqual(testCase, sphynx.util.actBucket(legacy{k}), 'spatial', ...
            sprintf('expected "%s" -> spatial', legacy{k}));
    end
end

% --- spatial: per-region realout ----------------------------------------
function testPerRegionRealoutSpatial(testCase)
    names = {'walls_realout', 'corners_realout', 'arena_realout', ...
             'walls_and_corners_realout'};
    for k = 1:numel(names)
        verifyEqual(testCase, sphynx.util.actBucket(names{k}), 'spatial', ...
            sprintf('expected "%s" -> spatial', names{k}));
    end
end

% --- spatial: numbered (circle-rings, strips, polygon corners) ----------
function testCircleRingsMiddleNumbered(testCase)
    verifyEqual(testCase, sphynx.util.actBucket('middle1'), 'spatial');
    verifyEqual(testCase, sphynx.util.actBucket('middle2'), 'spatial');
    verifyEqual(testCase, sphynx.util.actBucket('middle9'), 'spatial');
end

function testStripsSpatial(testCase)
    verifyEqual(testCase, sphynx.util.actBucket('strip1'),         'spatial');
    verifyEqual(testCase, sphynx.util.actBucket('strip3'),         'spatial');
    verifyEqual(testCase, sphynx.util.actBucket('strip2_realout'), 'spatial');
end

function testArenaCornersSpatial(testCase)
    verifyEqual(testCase, sphynx.util.actBucket('arenacorner1'), 'spatial');
    verifyEqual(testCase, sphynx.util.actBucket('arenacorner4'), 'spatial');
end

% --- spatial: per-object (Barnes-style: object1, target, start) ---------
function testObjectZonesSpatial(testCase)
    names = {'object1_real', 'object1_realout', 'object1_out', ...
             'object19_real', 'object19_realout', ...
             'objectall_real', 'objectall_realout', 'objectall_out'};
    for k = 1:numel(names)
        verifyEqual(testCase, sphynx.util.actBucket(names{k}), 'spatial', ...
            sprintf('expected "%s" -> spatial', names{k}));
    end
end

function testCenterPointZonesSpatial(testCase)
    % Barnes: target_center, object1_center, ..., start_center
    names = {'target_center', 'object1_center', 'object19_center', ...
             'start_center', 'objectall_center'};
    for k = 1:numel(names)
        verifyEqual(testCase, sphynx.util.actBucket(names{k}), 'spatial', ...
            sprintf('expected "%s" -> spatial', names{k}));
    end
end

function testAtPrefixActsSpatial(testCase)
    % Readable Barnes default-act naming: at_target, at_platform,
    % at_object3, at_mistake, at_any_hole, at_center, at_wall, at_outside.
    names = {'at_target', 'at_platform', 'at_center', 'at_wall', ...
             'at_outside', 'at_any_hole', 'at_mistake', ...
             'at_object1', 'at_object19', 'at_objectall'};
    for k = 1:numel(names)
        verifyEqual(testCase, sphynx.util.actBucket(names{k}), 'spatial', ...
            sprintf('expected "%s" -> spatial', names{k}));
    end
end

function testBpAtZoneActsSpatial(testCase)
    % Per-body-part Barnes naming: nose_at_target, body_at_object3,
    % head_at_platform. Any alphabetic body-part prefix counts.
    names = {'nose_at_target', 'nose_at_platform', 'nose_at_any_hole', ...
             'nose_at_object1', 'nose_at_object19', ...
             'body_at_target', 'body_at_platform', ...
             'body_at_object1', 'body_at_object19'};
    for k = 1:numel(names)
        verifyEqual(testCase, sphynx.util.actBucket(names{k}), 'spatial', ...
            sprintf('expected "%s" -> spatial', names{k}));
    end
end

function testBarnesNamedObjectZonesSpatial(testCase)
    % Barnes preset uses object types like 'target' / 'start' that emit
    % zones target_real, target_realout, target_out, target_center,
    % start_real, start_realout, start_out, start_center.
    names = {'target_real', 'target_realout', 'target_out', ...
             'start_real',  'start_realout',  'start_out'};
    for k = 1:numel(names)
        verifyEqual(testCase, sphynx.util.actBucket(names{k}), 'spatial', ...
            sprintf('expected "%s" -> spatial', names{k}));
    end
end

% --- composite: fallback for unknown / user-defined --------------------
function testUnknownIsComposite(testCase)
    verifyEqual(testCase, sphynx.util.actBucket('chase'),         'composite');
    verifyEqual(testCase, sphynx.util.actBucket('groom'),         'composite');
    verifyEqual(testCase, sphynx.util.actBucket('exploration'),   'composite');
end

function testTokenWithoutZoneSuffixIsComposite(testCase)
    % "object1" alone is NOT a zone name -- zones always carry the
    % _real/_realout/_out/_center suffix.
    verifyEqual(testCase, sphynx.util.actBucket('object1'), 'composite');
    verifyEqual(testCase, sphynx.util.actBucket('target'),  'composite');
    verifyEqual(testCase, sphynx.util.actBucket('start'),   'composite');
end

% --- robustness ---------------------------------------------------------
function testEmptyStringIsComposite(testCase)
    verifyEqual(testCase, sphynx.util.actBucket(''), 'composite');
end

function testNumericInputIsComposite(testCase)
    verifyEqual(testCase, sphynx.util.actBucket(42), 'composite');
end

function testStringInput(testCase)
    verifyEqual(testCase, sphynx.util.actBucket("walks_realout"), 'spatial');
    verifyEqual(testCase, sphynx.util.actBucket("rest"),          'speed');
end
