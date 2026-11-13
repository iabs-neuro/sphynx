function tests = backingTurnaroundTest
% Synthetic trajectories with a known answer for the linear-track acts.
    tests = functiontests(localfunctions);
end

% --- backing ---------------------------------------------------------------

function testBackingDetectsTailFirstMotion(testCase)
    [hx, hy, cx, cy] = straightRun(-3, +1);   % moves -x, head on the +x side
    b = sphynx.acts.backing(hx, hy, cx, cy, 30, 10);
    verifyGreaterThan(testCase, mean(b(10:end-10)), 0.99);
end

function testBackingIgnoresForwardMotion(testCase)
    [hx, hy, cx, cy] = straightRun(-3, -1);   % moves -x, head leads
    b = sphynx.acts.backing(hx, hy, cx, cy, 30, 10);
    verifyFalse(testCase, any(b));
end

function testBackingIgnoresSidewaysMotion(testCase)
    n = 90; fr = 30; ppc = 10;
    cy = 100 + (0:n-1) * 3 * ppc / fr;        % moves +y at 3 cm/s
    cx = 300 * ones(1, n);
    hx = cx + 2.5 * ppc; hy = cy;             % head points +x
    b = sphynx.acts.backing(hx, hy, cx, cy, fr, ppc);
    verifyFalse(testCase, any(b));
end

function testBackingIgnoresSlowDrift(testCase)
    [hx, hy, cx, cy] = straightRun(-0.5, +1); % below 1 cm/s
    b = sphynx.acts.backing(hx, hy, cx, cy, 30, 10);
    verifyFalse(testCase, any(b));
end

% --- turnaround ------------------------------------------------------------

function testTurnaroundFindsOneTurn(testCase)
    fr = 30;
    ang = [zeros(1, 30), linspace(0, pi, 30), pi * ones(1, 30)];  % 1 s rotation
    [hx, hy, tx, ty] = bodyAtAngles(ang);
    b = sphynx.acts.turnaround(hx, hy, tx, ty, fr, 10, [1 0]);
    [nRuns, lens] = runs(b);
    verifyEqual(testCase, nRuns, 1);
    % The rotation off ~18 deg takes ~0.8 s here, then the turn is widened to 1 s.
    verifyEqual(testCase, lens, fr);
    verifyTrue(testCase, all(find(b) > 25 & find(b) <= 65));  % around the rotation
end

function testTurnaroundCoversWholeRotation(testCase)
    % 3 s rotation: the turn runs from ~18 deg off the old direction to
    % ~18 deg off the new one, i.e. ~80% of the rotation, not only its middle.
    fr = 30;
    ang = [zeros(1, 30), linspace(0, pi, 90), pi * ones(1, 30)];
    [hx, hy, tx, ty] = bodyAtAngles(ang);
    b = sphynx.acts.turnaround(hx, hy, tx, ty, fr, 10, [1 0]);
    [nRuns, lens] = runs(b);
    verifyEqual(testCase, nRuns, 1);
    verifyGreaterThanOrEqual(testCase, lens, 66);
    verifyLessThanOrEqual(testCase, lens, 78);
    verifyTrue(testCase, all(find(b) > 30 & find(b) <= 120));
end

function testTurnaroundShortDetectionWidenedToMinTurn(testCase)
    ang = [zeros(1, 40), linspace(0, pi, 9), pi * ones(1, 40)];   % 0.3 s
    [hx, hy, tx, ty] = bodyAtAngles(ang);
    b = sphynx.acts.turnaround(hx, hy, tx, ty, 30, 10, [1 0]);
    [nRuns, lens] = runs(b);
    verifyEqual(testCase, nRuns, 1);
    verifyEqual(testCase, lens, 30);
    b = sphynx.acts.turnaround(hx, hy, tx, ty, 30, 10, [1 0], 'MinTurnSec', 2);
    [~, lens] = runs(b);
    verifyEqual(testCase, lens, 60);
end

function testTurnaroundBackToBackTurnsStaySeparate(testCase)
    % Turn, face the other way for 0.4 s, turn back. With facing runs
    % allowed from 0.2 s, widening to 1 s makes the two turns overlap;
    % they must still come out as two turns.
    ang = [zeros(1, 40), linspace(0, pi, 9), pi * ones(1, 12), linspace(pi, 2*pi, 9), 2*pi * ones(1, 40)];
    [hx, hy, tx, ty] = bodyAtAngles(ang);
    b = sphynx.acts.turnaround(hx, hy, tx, ty, 30, 10, [1 0], 'MinFacingSec', 0.2);
    [nRuns, lens] = runs(b);
    verifyEqual(testCase, nRuns, 2);
    verifyGreaterThanOrEqual(testCase, lens, 30);   % each keeps 1 s
end

function testTurnaroundIgnoresHeldLookBack(testCase)
    % Head points back for 0.4 s and returns: with the default minimum
    % facing run (0.75 s) this is a look back, not two turns.
    ang = [zeros(1, 40), linspace(0, pi, 9), pi * ones(1, 12), linspace(pi, 2*pi, 9), 2*pi * ones(1, 40)];
    [hx, hy, tx, ty] = bodyAtAngles(ang);
    b = sphynx.acts.turnaround(hx, hy, tx, ty, 30, 10, [1 0]);
    verifyFalse(testCase, any(b));
end

function testTurnaroundIgnoresLookBack(testCase)
    ang = [zeros(1, 30), linspace(0, pi/2, 15), linspace(pi/2, 0, 15), zeros(1, 30)];
    [hx, hy, tx, ty] = bodyAtAngles(ang);
    b = sphynx.acts.turnaround(hx, hy, tx, ty, 30, 10, [1 0]);
    verifyFalse(testCase, any(b));
end

function testTurnaroundIgnoresTrackerSwap(testCase)
    ang = [zeros(1, 40), pi * ones(1, 40)];   % head and tail swap in one frame
    [hx, hy, tx, ty] = bodyAtAngles(ang);
    b = sphynx.acts.turnaround(hx, hy, tx, ty, 30, 10, [1 0]);
    verifyFalse(testCase, any(b));
end

function testTurnaroundIgnoresShortFacingBlip(testCase)
    % A 2-frame opposite-facing blip between two same-direction runs.
    ang = [zeros(1, 30), pi/2 * ones(1, 3), pi * ones(1, 2), pi/2 * ones(1, 3), zeros(1, 30)];
    [hx, hy, tx, ty] = bodyAtAngles(ang);
    b = sphynx.acts.turnaround(hx, hy, tx, ty, 30, 10, [1 0]);
    verifyFalse(testCase, any(b));
end

function testTurnaroundRespectsMaxDuration(testCase)
    % 24 s rotation; the in-between stretch (45-135 deg) is about 12 s.
    ang = [zeros(1, 30), linspace(0, pi, 30 * 24), pi * ones(1, 30)];
    [hx, hy, tx, ty] = bodyAtAngles(ang);
    b = sphynx.acts.turnaround(hx, hy, tx, ty, 30, 10, [1 0], 'MaxTurnSec', 10);
    verifyFalse(testCase, any(b));
    b = sphynx.acts.turnaround(hx, hy, tx, ty, 30, 10, [1 0], 'MaxTurnSec', 20);
    verifyEqual(testCase, runs(b), 1);
end

function testTurnaroundOnSlantedTrack(testCase)
    % Track tilted by 10 deg; the animal faces along it, then against it.
    tilt = deg2rad(10);
    ang = tilt + [zeros(1, 30), linspace(0, pi, 30), pi * ones(1, 30)];
    [hx, hy, tx, ty] = bodyAtAngles(ang);
    b = sphynx.acts.turnaround(hx, hy, tx, ty, 30, 10, [cos(tilt) sin(tilt)]);
    verifyEqual(testCase, runs(b), 1);
end

% --- through applyAct / the default library -------------------------------

function testDefaultsContainLinearTrackActs(testCase)
    acts = sphynx.acts.actsLibraryDefaults();
    names = {acts.name};
    verifyTrue(testCase, all(ismember({'backing', 'turnaround'}, names)));
    a = acts(strcmp(names, 'turnaround'));
    verifyEqual(testCase, a.type, 'special');
    verifyEqual(testCase, a.specialKind, 'turnaround');
    verifyEqual(testCase, a.bodyParts, {'headcenter', 'bodycenter'});
end

function testApplyActUsesFallbackHeadAndCorners(testCase)
    % No head centre in the tracking: turnaround falls back to the
    % miniscope, ahead of the nose. The track axis comes from arena corner
    % zones, not from the trajectory (here a single spot, no direction).
    ang = [zeros(1, 30), linspace(0, pi, 30), pi * ones(1, 30)];
    [hx, hy, tx, ty] = bodyAtAngles(ang);
    n = numel(ang);
    % The nose track sits on the body centre (no direction, as when the
    % miniscope hides it), so a turn is found only if the miniscope is
    % picked before the nose.
    cx = (hx + tx) / 2; cy = (hy + ty) / 2;
    ctx = baseCtx({'nose', 'miniscopeUCLA', 'bodycenter', 'tailbase'}, ...
        [cx; hx; cx; tx], [cy; hy; cy; ty], n);
    ctx.zones = cornerZones([10 100; 1200 100; 1200 150; 10 150]);
    acts = sphynx.acts.actsLibraryDefaults();
    a = acts(strcmp({acts.name}, 'turnaround'));
    b = sphynx.acts.applyAct(a, ctx);
    verifyEqual(testCase, runs(b), 1);
end

function testApplyActBackingThroughLibrary(testCase)
    [hx, hy, cx, cy] = straightRun(-3, +1);
    n = numel(cx);
    ctx = baseCtx({'headcenter', 'bodycenter'}, [hx; cx], [hy; cy], n);
    res = sphynx.acts.evalActsLibrary(sphynx.acts.actsLibraryDefaults(), ctx);
    bk = res('backing');
    verifyGreaterThan(testCase, mean(bk(10:end-10)), 0.99);
    verifyFalse(testCase, any(res('turnaround')));
end

% --- helpers ---------------------------------------------------------------

function [hx, hy, cx, cy] = straightRun(speedCmS, headSide)
    % 3 s along x at speedCmS; head 2.5 cm from the centre on headSide (+1/-1).
    n = 90; fr = 30; ppc = 10;
    cx = 600 + (0:n-1) * speedCmS * ppc / fr;
    cy = 120 * ones(1, n);
    hx = cx + headSide * 2.5 * ppc;
    hy = cy;
end

function [hx, hy, tx, ty] = bodyAtAngles(ang)
    % 6 cm body centred at (600, 120) px with 10 px/cm, pointing along ang.
    half = 3 * 10;
    hx = 600 + half * cos(ang); hy = 120 + half * sin(ang);
    tx = 600 - half * cos(ang); ty = 120 - half * sin(ang);
end

function [n, lens] = runs(b)
    d = diff([0, b(:)', 0]);
    s = find(d == 1); e = find(d == -1) - 1;
    n = numel(s); lens = e - s + 1;
end

function ctx = baseCtx(parts, X, Y, n)
    ctx.X = X; ctx.Y = Y;
    ctx.velocityCmS = zeros(numel(parts), n);
    ctx.bodyParts = parts;
    z.name = 'arena'; z.type = 'area'; z.maskfilled = true(320, 1280);
    ctx.zones = z;
    ctx.frameRate = 30;
    ctx.pixelsPerCm = 10;
    ctx.xKcorr = 1;
    ctx.allActs = sphynx.acts.emptyActsArray();
    ctx.resultsByName = containers.Map();
end

function z = cornerZones(P)
    z = struct('name', {}, 'type', {}, 'maskfilled', {});
    z(1).name = 'arena'; z(1).type = 'area'; z(1).maskfilled = true(320, 1280);
    for k = 1:size(P, 1)
        z(end + 1).name = sprintf('arenacorner%d', k); %#ok<AGROW>
        z(end).type = 'point';
        z(end).maskfilled = P(k, :);
    end
end
