function tests = actsLibraryBarnesDefaultsTest
% ACTSLIBRARYBARNESDEFAULTSTEST  Coverage for the Barnes paradigm
%   default-acts library. Locks in: count, names, zone wiring, body-
%   part conventions (nose for nose pokes, body for body-center
%   visits), and the speed-defaults concat pattern.
    tests = functiontests(localfunctions);
end

function testDefaultsHas43Acts(testCase)
    % 1 nose-target + 19 nose-objectN + 1 body-target + 19 body-objectN
    %  + nose-platform + body-platform + nose-any-hole
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    verifyEqual(testCase, numel(acts), 43);
end

function testCustomNumObjectsScalesCount(testCase)
    % 1 + N + 1 + N + 2 + 1 = 2N + 5
    acts = sphynx.acts.actsLibraryBarnesDefaults('NumObjects', 5);
    verifyEqual(testCase, numel(acts), 2 * 5 + 5);
end

function testZeroObjectsKeepsTargetPlatformAnyHole(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults('NumObjects', 0);
    verifyEqual(testCase, numel(acts), 5);
    expected = {'nose_at_target', 'body_at_target', ...
                'nose_at_platform', 'body_at_platform', 'nose_at_any_hole'};
    for k = 1:numel(expected)
        verifyTrue(testCase, hasAct(acts, expected{k}), ...
            sprintf('missing act: %s', expected{k}));
    end
end

function testAllExpectedRootActsPresent(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    expected = {'nose_at_target', 'body_at_target', ...
                'nose_at_platform', 'body_at_platform', ...
                'nose_at_any_hole'};
    for k = 1:numel(expected)
        verifyTrue(testCase, hasAct(acts, expected{k}), ...
            sprintf('missing act: %s', expected{k}));
    end
end

function testPerHoleNoseActsGenerated(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    for n = [1, 5, 10, 19]
        nm = sprintf('nose_at_object%d', n);
        verifyTrue(testCase, hasAct(acts, nm), ...
            sprintf('missing per-hole nose act: %s', nm));
    end
    verifyFalse(testCase, hasAct(acts, 'nose_at_object20'));
end

function testPerHoleBodyActsGenerated(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    for n = [1, 5, 10, 19]
        nm = sprintf('body_at_object%d', n);
        verifyTrue(testCase, hasAct(acts, nm), ...
            sprintf('missing per-hole body act: %s', nm));
    end
    verifyFalse(testCase, hasAct(acts, 'body_at_object20'));
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

function testNoseActsGateOnRealoutZone(testCase)
    % Nose acts gate on the inflated _realout halo -- nose enters
    % the soft halo before the rest of the body.
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    verifyEqual(testCase, getAct(acts, 'nose_at_target').zones,    {'target_realout'});
    verifyEqual(testCase, getAct(acts, 'nose_at_platform').zones,  {'platform_realout'});
    verifyEqual(testCase, getAct(acts, 'nose_at_object1').zones,   {'object1_realout'});
    verifyEqual(testCase, getAct(acts, 'nose_at_object19').zones,  {'object19_realout'});
end

function testNoseAtAnyHoleExcludesPlatform(testCase)
    % "Any hole" = the escape target + every wrong hole. Platform is
    % the start, not a hole -- it must NOT show up in the zone list.
    % We also avoid the preset's objectall_realout aggregate because
    % that zone is built from ALL objects including the platform.
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    zns = getAct(acts, 'nose_at_any_hole').zones;
    verifyEqual(testCase, numel(zns), 20);   % 1 target + 19 holes
    verifyTrue(testCase, any(strcmp(zns, 'target_realout')));
    verifyFalse(testCase, any(strcmp(zns, 'platform_realout')));
    verifyFalse(testCase, any(strcmp(zns, 'platform_real')));
    verifyFalse(testCase, any(strcmp(zns, 'objectall_realout')));
    for n = 1:19
        nm = sprintf('object%d_realout', n);
        verifyTrue(testCase, any(strcmp(zns, nm)), ...
            sprintf('any_hole zone list missing %s', nm));
    end
end

function testNoseAtAnyHoleScalesWithNumObjects(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults('NumObjects', 5);
    zns = getAct(acts, 'nose_at_any_hole').zones;
    verifyEqual(testCase, numel(zns), 6);   % 1 target + 5 holes
end

function testBodyActsGateOnRealZone(testCase)
    % Body-center acts gate on the strict geometric _real zone --
    % "the animal physically sat in the hole / platform".
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    verifyEqual(testCase, getAct(acts, 'body_at_target').zones,   {'target_real'});
    verifyEqual(testCase, getAct(acts, 'body_at_platform').zones, {'platform_real'});
    verifyEqual(testCase, getAct(acts, 'body_at_object1').zones,  {'object1_real'});
    verifyEqual(testCase, getAct(acts, 'body_at_object19').zones, {'object19_real'});
end

function testAllSimpleAndZoneOpOR(testCase)
    acts = sphynx.acts.actsLibraryBarnesDefaults();
    for k = 1:numel(acts)
        verifyEqual(testCase, acts(k).type, 'simple', ...
            sprintf('%s should be simple (Barnes defaults are flat)', acts(k).name));
        verifyEqual(testCase, acts(k).zoneOp, 'OR', ...
            sprintf('%s should default to OR', acts(k).name));
    end
end

function testAllNamesBucketAsSpatial(testCase)
    % Every Barnes default act should bucket as 'spatial' via
    % sphynx.util.actBucket (the <bp>_at_<zone> regex branch).
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
