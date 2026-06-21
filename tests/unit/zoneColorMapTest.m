function tests = zoneColorMapTest
% ZONECOLORMAPTEST  R15 -- semantic per-zone color map for combined-layout
%   renders. Validates the rules from the user's reference Barnes image:
%
%     - walls and walls_realout share the same red
%     - corners and corners_realout share the same green
%     - arena_realout matches walls red ONLY when no per-region _realout
%       zone exists; otherwise skipped (NaN) so it doesn't overpaint
%       corners/strips_realout
%     - walls_and_corners* composites are skipped (NaN)
%     - unknown names get a fallback rotating palette (non-NaN)
    tests = functiontests(localfunctions);
end

% --- group: same-color rules ---------------------------------------------
function testWallAndWallsRealoutSameColor(testCase)
    cmap = sphynx.app.CreatePresetApp.zoneColorMap({'walls', 'walls_realout'});
    verifyFalse(testCase, any(isnan(cmap(:))));
    verifyEqual(testCase, cmap(1, :), cmap(2, :));
end

function testCornersAndCornersRealoutSameColor(testCase)
    cmap = sphynx.app.CreatePresetApp.zoneColorMap({'corners', 'corners_realout'});
    verifyFalse(testCase, any(isnan(cmap(:))));
    verifyEqual(testCase, cmap(1, :), cmap(2, :));
end

function testCircleWallAndArenaRealoutSameColor(testCase)
    % circle strategy: [wall, center, arena_realout] -- no per-region
    % _realout, so arena_realout takes wall color so outside-arena band
    % continues the wall ring visually.
    cmap = sphynx.app.CreatePresetApp.zoneColorMap({'wall', 'center', 'arena_realout'});
    verifyFalse(testCase, any(isnan(cmap(:))));
    verifyEqual(testCase, cmap(1, :), cmap(3, :));   % wall == arena_realout
    verifyFalse(testCase, isequal(cmap(1, :), cmap(2, :)));   % != center
end

% --- group: composite & arena_realout skipping ---------------------------
function testCompositeWallsAndCornersSkipped(testCase)
    cmap = sphynx.app.CreatePresetApp.zoneColorMap({'walls_and_corners', ...
        'walls_and_corners_realout'});
    verifyTrue(testCase, all(isnan(cmap(:))));
end

function testArenaRealoutSkippedWhenWallsRealoutPresent(testCase)
    % corners-walls-center: arena_realout would overpaint corners with
    % red -- skip when walls_realout/corners_realout cover the outer ring.
    names = {'corners', 'walls', 'walls_and_corners', 'center', ...
             'arena_realout', 'corners_realout', 'walls_realout', ...
             'walls_and_corners_realout'};
    cmap = sphynx.app.CreatePresetApp.zoneColorMap(names);
    % arena_realout (index 5) -> NaN
    verifyTrue(testCase, all(isnan(cmap(5, :))));
    % corners_realout still green, == corners
    verifyEqual(testCase, cmap(1, :), cmap(6, :));
    % walls_realout still red, == walls
    verifyEqual(testCase, cmap(2, :), cmap(7, :));
    % composites NaN
    verifyTrue(testCase, all(isnan(cmap(3, :))));
    verifyTrue(testCase, all(isnan(cmap(8, :))));
end

function testArenaRealoutKeptInCircleRings(testCase)
    % circle-rings: [wall, middle1, middle2, center, arena_realout] --
    % no per-region _realout, so arena_realout keeps red.
    cmap = sphynx.app.CreatePresetApp.zoneColorMap( ...
        {'wall', 'middle1', 'middle2', 'center', 'arena_realout'});
    verifyFalse(testCase, any(isnan(cmap(5, :))));
    verifyEqual(testCase, cmap(1, :), cmap(5, :));   % wall color
end

function testArenaRealoutSkippedInStrips(testCase)
    % strips emits strip*_realout, so arena_realout is per-region-covered
    % and must skip.
    names = {'strip1', 'strip2', 'strip3', 'strip1_realout', ...
             'strip2_realout', 'strip3_realout', 'arena_realout'};
    cmap = sphynx.app.CreatePresetApp.zoneColorMap(names);
    verifyTrue(testCase, all(isnan(cmap(7, :))));
end

% --- group: fallback palette ---------------------------------------------
function testUnknownNamesGetFallback(testCase)
    cmap = sphynx.app.CreatePresetApp.zoneColorMap({'mystery_zone_a', 'mystery_zone_b'});
    verifyFalse(testCase, any(isnan(cmap(:))));
    % distinct fallback colors
    verifyFalse(testCase, isequal(cmap(1, :), cmap(2, :)));
end

function testCenterIsBlue(testCase)
    cmap = sphynx.app.CreatePresetApp.zoneColorMap({'center'});
    verifyEqual(testCase, cmap(1, :), [0.10 0.45 0.95]);
end

% --- group: shape/edge cases ---------------------------------------------
function testEmptyInputReturnsEmpty(testCase)
    cmap = sphynx.app.CreatePresetApp.zoneColorMap({});
    verifyEqual(testCase, size(cmap), [0, 3]);
end

function testAcceptsStringInput(testCase)
    cmap = sphynx.app.CreatePresetApp.zoneColorMap("walls");
    verifyEqual(testCase, cmap(1, :), [0.95 0.30 0.20]);
end
