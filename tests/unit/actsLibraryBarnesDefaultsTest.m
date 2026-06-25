function tests = actsLibraryBarnesDefaultsTest
% ACTSLIBRARYBARNESDEFAULTSTEST  Coverage for the Barnes paradigm
%   default-acts library. Locks in: count, names, types, zone wiring,
%   body-part conventions (nose for hole probes, bodycenter for arena
%   frame), and the at_mistake compound dependency graph.
    tests = functiontests(localfunctions);
end

function testDefaultsHas26Acts(testCase)
    % 6 area + 19 per-hole + 1 compound
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    verifyEqual(testCase, numel(acts), 26);
end

function testCustomNumObjectsScalesCount(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults('NumObjects', 5);
    verifyEqual(testCase, numel(acts), 6 + 5 + 1);
end

function testZeroObjectsKeepsAreaAndCompound(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults('NumObjects', 0);
    verifyEqual(testCase, numel(acts), 7);
    % at_any_hole and at_mistake survive (compound still references them)
    verifyTrue(testCase, hasAct(acts, 'at_any_hole'));
    verifyTrue(testCase, hasAct(acts, 'at_mistake'));
end

function testAllExpectedAreaActsPresent(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    expected = {'at_center', 'at_wall', 'at_outside', ...
                'at_target', 'at_platform', 'at_any_hole', ...
                'at_mistake'};
    for k = 1:numel(expected)
        verifyTrue(testCase, hasAct(acts, expected{k}), ...
            sprintf('missing act: %s', expected{k}));
    end
end

function testPerHoleActsGenerated(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    for n = [1, 5, 10, 19]
        nm = sprintf('at_object%d', n);
        verifyTrue(testCase, hasAct(acts, nm), ...
            sprintf('missing per-hole act: %s', nm));
    end
    verifyFalse(testCase, hasAct(acts, 'at_object20'));
    verifyFalse(testCase, hasAct(acts, 'at_object0'));
end

function testHoleActsUseNoseBodyPart(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    expectNose = {'at_target', 'at_any_hole', 'at_object1', 'at_object19'};
    for k = 1:numel(expectNose)
        a = getAct(acts, expectNose{k});
        verifyEqual(testCase, a.bodyPart, 'nose', ...
            sprintf('%s should probe with nose', expectNose{k}));
    end
end

function testArenaFrameActsUseBodyCenter(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    expectBody = {'at_center', 'at_wall', 'at_outside', 'at_platform'};
    for k = 1:numel(expectBody)
        a = getAct(acts, expectBody{k});
        verifyEqual(testCase, a.bodyPart, 'bodycenter', ...
            sprintf('%s should use bodycenter', expectBody{k}));
    end
end

function testHoleActsGateOnRealoutZone(testCase)
    % Hole acts must reference the inflated (_realout) variant -- visits
    % are detected when nose enters the soft halo, not only the geometric
    % hole edge.
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    a = getAct(acts, 'at_target');
    verifyEqual(testCase, a.zones, {'target_realout'});
    a = getAct(acts, 'at_any_hole');
    verifyEqual(testCase, a.zones, {'objectall_realout'});
    a = getAct(acts, 'at_object3');
    verifyEqual(testCase, a.zones, {'object3_realout'});
end

function testAreaActsGateOnExactZone(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    verifyEqual(testCase, getAct(acts, 'at_center').zones,   {'center'});
    verifyEqual(testCase, getAct(acts, 'at_wall').zones,     {'wall'});
    verifyEqual(testCase, getAct(acts, 'at_outside').zones,  {'arena_realout'});
    verifyEqual(testCase, getAct(acts, 'at_platform').zones, {'platform_realout'});
end

function testMistakeIsComplexExcludeOnAnyHoleMinusTarget(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    a = getAct(acts, 'at_mistake');
    verifyEqual(testCase, a.type, 'complex');
    verifyEqual(testCase, a.operation, 'exclude');
    verifyEqual(testCase, a.components, {'at_any_hole', 'at_target'});
end

function testMistakeComponentsExist(testCase)
    % evalActsLibrary's pass-2 needs the simple components to exist by
    % name in pass-1 -- this would otherwise crash at runtime.
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    a = getAct(acts, 'at_mistake');
    for k = 1:numel(a.components)
        verifyTrue(testCase, hasAct(acts, a.components{k}), ...
            sprintf('at_mistake references missing component: %s', a.components{k}));
    end
end

function testAllSimpleActsHaveZoneOpOR(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    for k = 1:numel(acts)
        if strcmp(acts(k).type, 'simple')
            verifyEqual(testCase, acts(k).zoneOp, 'OR', ...
                sprintf('%s should default to OR', acts(k).name));
        end
    end
end

function testAllNamesUseAtPrefixForActBucket(testCase)
    % Every Barnes default act should bucket as 'spatial' via
    % sphynx.util.actBucket (the at_* regex branch).
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    for k = 1:numel(acts)
        verifyEqual(testCase, sphynx.util.actBucket(acts(k).name), 'spatial', ...
            sprintf('%s should bucket as spatial', acts(k).name));
    end
end

function testConcatenatesWithSpeedDefaults(testCase)
    % Typical session library = speed defaults + Barnes defaults.
    speed = sphynx.acts.actsLibraryDefaults();
    barnes = sphynx.acts.actsLibraryBarnesDefaults();
    combined = [speed, barnes];
    verifyEqual(testCase, numel(combined), numel(speed) + numel(barnes));
    % Name uniqueness across the union
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
