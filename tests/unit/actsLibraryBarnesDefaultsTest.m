function tests = actsLibraryBarnesDefaultsTest
% ACTSLIBRARYBARNESDEFAULTSTEST  Coverage for the Barnes paradigm
%   default-acts library v3. Locks in: count, name conventions, zone
%   wiring (per-act _real vs _realout), body-part conventions, the
%   new mouse_inside_* special act, and the speed-defaults concat.
    tests = functiontests(localfunctions);
end

function testDefaultsHas64Acts(testCase)
    % v3: 1+19 nose + 1+19 body + 2 platform + 1+19+1 mouse_inside +
    %     1 nose_at_any_hole = 64
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    verifyEqual(testCase, numel(acts), 64);
end

function testCustomNumObjectsScalesCount(testCase)
    % 1+N nose + 1+N body + 2 platform + 1+N+1 mouse_inside + 1 any = 3N+7
    acts = sphynx.acts.actsLibraryBarnesDefaults('NumObjects', 5);
    verifyEqual(testCase, numel(acts), 3 * 5 + 7);
end

function testZeroObjectsKeepsTargetPlatformAnyHole(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults('NumObjects', 0);
    verifyEqual(testCase, numel(acts), 7);
    expected = {'nose_at_target', 'body_at_target', ...
                'nose_at_platform', 'body_at_platform', ...
                'mouse_inside_target', 'mouse_inside_platform', ...
                'nose_at_any_hole'};
    for k = 1:numel(expected)
        verifyTrue(testCase, hasAct(acts, expected{k}), ...
            sprintf('missing act: %s', expected{k}));
    end
end

function testHoleNamingIsHoleNotObject(testCase)
    % v3 rename: per-hole acts use the "_holeN" suffix instead of
    % the old "_objectN" so the user-facing list stays paradigm-
    % consistent ("hole" reads better than "object" in Barnes).
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    verifyTrue(testCase,  hasAct(acts, 'nose_at_hole1'));
    verifyTrue(testCase,  hasAct(acts, 'body_at_hole19'));
    verifyTrue(testCase,  hasAct(acts, 'mouse_inside_hole10'));
    verifyFalse(testCase, hasAct(acts, 'nose_at_object1'));
    verifyFalse(testCase, hasAct(acts, 'body_at_object1'));
end

function testNoseActsGateOnRealZone(testCase)
    % v3 switch: nose acts now use the strict _real zone (the hole
    % polygon itself) instead of the inflated _realout halo.
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    verifyEqual(testCase, getAct(acts, 'nose_at_target').zones,    {'target_real'});
    verifyEqual(testCase, getAct(acts, 'nose_at_platform').zones,  {'platform_real'});
    verifyEqual(testCase, getAct(acts, 'nose_at_hole1').zones,     {'object1_real'});
    verifyEqual(testCase, getAct(acts, 'nose_at_hole19').zones,    {'object19_real'});
end

function testBodyActsGateOnRealoutZone(testCase)
    % v3 switch: body acts now use the inflated _realout halo
    % (was _real). Captures "body near hole" broader presence.
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    verifyEqual(testCase, getAct(acts, 'body_at_target').zones,    {'target_realout'});
    verifyEqual(testCase, getAct(acts, 'body_at_platform').zones,  {'platform_realout'});
    verifyEqual(testCase, getAct(acts, 'body_at_hole1').zones,     {'object1_realout'});
    verifyEqual(testCase, getAct(acts, 'body_at_hole19').zones,    {'object19_realout'});
end

function testNoseActsUseNoseBodyPart(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    for k = 1:numel(acts)
        if startsWith(acts(k).name, 'nose_at_')
            verifyEqual(testCase, acts(k).bodyPart, 'nose', ...
                sprintf('%s should probe with nose', acts(k).name));
        end
    end
end

function testBodyActsUseBodyCenter(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    for k = 1:numel(acts)
        if startsWith(acts(k).name, 'body_at_')
            verifyEqual(testCase, acts(k).bodyPart, 'bodycenter', ...
                sprintf('%s should use bodycenter', acts(k).name));
        end
    end
end

function testMouseInsideIsAllInZoneSpecial(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    a = getAct(acts, 'mouse_inside_target');
    verifyEqual(testCase, a.type, 'special');
    verifyEqual(testCase, a.specialKind, 'allInZone');
    verifyEqual(testCase, a.zones, {'target_real'});
    verifyEqual(testCase, sort(a.bodyParts), ...
        sort({'bodycenter', 'tailbase', 'headcenter'}));
end

function testMouseInsideHoleNCoversAllN(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    for n = [1, 10, 19]
        a = getAct(acts, sprintf('mouse_inside_hole%d', n));
        verifyEqual(testCase, a.type, 'special');
        verifyEqual(testCase, a.specialKind, 'allInZone');
        verifyEqual(testCase, a.zones, {sprintf('object%d_real', n)});
    end
end

function testMouseInsidePlatformPresent(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    a = getAct(acts, 'mouse_inside_platform');
    verifyEqual(testCase, a.type, 'special');
    verifyEqual(testCase, a.zones, {'platform_real'});
end

function testNoseAtAnyHoleListsHolesOnly(testCase)
    % v3: any_hole gates on the strict _real zones AND excludes
    % BOTH platform AND target. So we get exactly N zones, one per
    % hole, listed by object<N>_real (zone naming preserved).
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    zns = getAct(acts, 'nose_at_any_hole').zones;
    verifyEqual(testCase, numel(zns), 19);
    verifyFalse(testCase, any(strcmp(zns, 'target_real')));
    verifyFalse(testCase, any(strcmp(zns, 'target_realout')));
    verifyFalse(testCase, any(strcmp(zns, 'platform_real')));
    verifyFalse(testCase, any(strcmp(zns, 'objectall_real')));
    for n = 1:19
        verifyTrue(testCase, any(strcmp(zns, sprintf('object%d_real', n))), ...
            sprintf('missing object%d_real', n));
    end
end

function testNoseAtAnyHoleBodyPartIsNose(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    verifyEqual(testCase, getAct(acts, 'nose_at_any_hole').bodyPart, 'nose');
end

function testAllNoseAndBodyActsZoneOpOR(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    for k = 1:numel(acts)
        if strcmp(acts(k).type, 'simple')
            verifyEqual(testCase, acts(k).zoneOp, 'OR', ...
                sprintf('%s should default to OR', acts(k).name));
        end
    end
end

function testAllNamesBucketAsSpatial(testCase)
    % Every Barnes default act should bucket as 'spatial'.
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    for k = 1:numel(acts)
        verifyEqual(testCase, sphynx.util.actBucket(acts(k).name), 'spatial', ...
            sprintf('%s should bucket as spatial', acts(k).name));
    end
end

function testConcatenatesWithSpeedDefaults(testCase)
    speed = sphynx.acts.actsLibraryDefaults();
    barnes = sphynx.acts.actsLibraryBarnesDefaults();
    combined = [speed, barnes];
    verifyEqual(testCase, numel(combined), numel(speed) + numel(barnes));
    names = {combined.name};
    verifyEqual(testCase, numel(unique(names)), numel(names), ...
        'combined library has duplicate act names');
end

% --- helpers -------------------------------------------------------------
function tf = hasAct(acts, name)
    tf = any(strcmp({acts.name}, name));
end

function a = getAct(acts, name)
    idx = find(strcmp({acts.name}, name), 1);
    if isempty(idx)
        error('act not found: %s', name);
    end
    a = acts(idx);
end
