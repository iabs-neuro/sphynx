function tests = filterZoneListForActsTest
% FILTERZONELISTFORACTSTEST  Coverage for +sphynx/+util/filterZoneListForActs.
%   Locks in the composite-drop rule and the preservation of ordering
%   for the (non-composite) names of every CreatePreset strategy and
%   Barnes-style object naming.
    tests = functiontests(localfunctions);
end

function testDropsBothCompositesPreservesOrder(testCase)
    Z = mkZones({'corners', 'walls', 'walls_and_corners', 'center', ...
                 'arena_realout', 'corners_realout', 'walls_realout', ...
                 'walls_and_corners_realout'});
    out = sphynx.util.filterZoneListForActs(Z);
    verifyEqual(testCase, out, {'corners', 'walls', 'center', ...
                                'arena_realout', 'corners_realout', ...
                                'walls_realout'});
end

function testNoCompositesUnchanged(testCase)
    in = {'wall', 'middle', 'center', 'arena_realout'};
    Z = mkZones(in);
    verifyEqual(testCase, sphynx.util.filterZoneListForActs(Z), in);
end

function testBarnesPresetShape(testCase)
    % Trimmed Barnes layout: circle-with-center base + per-object zones
    % for target / object1..3 / start (real/realout/out + center).
    in = {'wall', 'middle', 'center', 'arena_realout', ...
          'target_real', 'target_realout', 'target_out', ...
          'object1_real', 'object1_realout', 'object1_out', ...
          'object2_real', 'object2_realout', 'object2_out', ...
          'object3_real', 'object3_realout', 'object3_out', ...
          'start_real', 'start_realout', 'start_out', ...
          'objectall_real', 'objectall_realout', 'objectall_out', ...
          'target_center', 'object1_center', 'object2_center', ...
          'object3_center', 'start_center'};
    Z = mkZones(in);
    out = sphynx.util.filterZoneListForActs(Z);
    % No composites in this preset -- nothing dropped.
    verifyEqual(testCase, out, in);
end

function testStripsPresetUntouched(testCase)
    in = {'strip1', 'strip2', 'strip3', ...
          'strip1_realout', 'strip2_realout', 'strip3_realout', ...
          'arena_realout'};
    Z = mkZones(in);
    verifyEqual(testCase, sphynx.util.filterZoneListForActs(Z), in);
end

function testEmptyReturnsEmptyCell(testCase)
    verifyEqual(testCase, sphynx.util.filterZoneListForActs([]), {});
    verifyEqual(testCase, sphynx.util.filterZoneListForActs(struct([])), {});
end

function testNonStructReturnsEmpty(testCase)
    verifyEqual(testCase, sphynx.util.filterZoneListForActs('walls'), {});
    verifyEqual(testCase, sphynx.util.filterZoneListForActs(42), {});
end

function testAllCompositesEmpty(testCase)
    Z = mkZones({'walls_and_corners', 'walls_and_corners_realout'});
    verifyEqual(testCase, sphynx.util.filterZoneListForActs(Z), {});
end

% --- helpers -------------------------------------------------------------
function Z = mkZones(names)
    Z = struct('name', {}, 'type', {}, 'maskfilled', {});
    for i = 1:numel(names)
        Z(i).name = names{i};
        Z(i).type = 'area';
        Z(i).maskfilled = [];
    end
end
