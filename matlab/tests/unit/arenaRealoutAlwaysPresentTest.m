function tests = arenaRealoutAlwaysPresentTest
% ARENAREALOUTALWAYSPRESENTTEST  R14.8 -- every zone strategy in the
%   CreatePresetApp dropdown must contribute an 'arena_realout' zone so
%   downstream code has a consistent "barely outside the arena" band.
%
%   corners-walls-center and strips already emit it from classifySquare;
%   circle / circle-rings / circle-with-center / none did not before R14.8.
    tests = functiontests(localfunctions);
end

function testCornersWallsCenterHasArenaRealout(testCase)
    Z = computeZonesForStrategy('corners-walls-center');
    verifyTrue(testCase, ismember('arena_realout', {Z.name}));
end

function testStripsHasArenaRealout(testCase)
    Z = computeZonesForStrategy('strips');
    % strips emits *_realout per strip; arena_realout is appended by R14.8.
    verifyTrue(testCase, ismember('arena_realout', {Z.name}));
end

function testCircleHasArenaRealout(testCase)
    Z = computeZonesForStrategy('circle');
    verifyTrue(testCase, ismember('arena_realout', {Z.name}));
    z = Z(strcmp({Z.name}, 'arena_realout'));
    verifyTrue(testCase, sum(z.maskfilled(:)) > 0);
end

function testCircleRingsHasArenaRealout(testCase)
    Z = computeZonesForStrategy('circle-rings');
    verifyTrue(testCase, ismember('arena_realout', {Z.name}));
end

function testCircleWithCenterHasArenaRealout(testCase)
    Z = computeZonesForStrategy('circle-with-center');
    verifyTrue(testCase, ismember('arena_realout', {Z.name}));
end

function testNoneHasArenaRealout(testCase)
    Z = computeZonesForStrategy('none');
    verifyTrue(testCase, ismember('arena_realout', {Z.name}));
end

function testArenaRealoutContainsArena(testCase)
    Z = computeZonesForStrategy('circle');
    arenaRealout = Z(strcmp({Z.name}, 'arena_realout')).maskfilled;
    % Reconstruct the arena mask the test fixture used.
    arenaMask = makeDiscMask(120, 60);
    % every arena pixel must be inside arena_realout
    verifyTrue(testCase, all(arenaRealout(arenaMask)));
    % arena_realout must be strictly bigger (at least one extra px ring).
    verifyTrue(testCase, sum(arenaRealout(:)) > sum(arenaMask(:)));
end

% ------------------------------------------------------------------
function Z = computeZonesForStrategy(strategy)
    app = sphynx.app.CreatePresetApp();
    cleaner = onCleanup(@() delete(app)); %#ok<NASGU>
    H = 120; W = 120;
    app.State.frame = uint8(zeros(H, W, 3));
    app.State.height = H;
    app.State.width = W;
    arenaMask = makeDiscMask(H, 60);
    arena.type = 'Arena';
    arena.geometry = 'Ellipse';   % round arena works for every strategy
    arena.border_x = [];
    arena.border_y = [];
    arena.border_separate_x = {};
    arena.border_separate_y = {};
    arena.mask = arenaMask;
    app.State.arena = arena;
    app.setPixelsPerCm(2.0);
    if strcmp(strategy, 'corners-walls-center')
        % CWC needs corner points + a Polygon arena -- swap the arena for
        % a square Polygon variant just for this call.
        sq = arena;
        sq.geometry = 'Polygon';
        sq.border_x = [10 110 110 10]';
        sq.border_y = [10 10 110 110]';
        sq.border_separate_x = {[10; 110], [110; 110], [110; 10], [10; 10]};
        sq.border_separate_y = {[10; 10], [10; 110], [110; 110], [110; 10]};
        sq.mask = false(H, W);
        sq.mask(10:110, 10:110) = true;
        app.State.arena = sq;
    elseif strcmp(strategy, 'strips')
        sq = arena;
        sq.geometry = 'Polygon';
        sq.border_x = [10 110 110 10]';
        sq.border_y = [10 10 110 110]';
        sq.mask = false(H, W);
        sq.mask(10:110, 10:110) = true;
        app.State.arena = sq;
    end
    app.ZonesStrategyDropDown.Value = strategy;
    app.WallWidthField.Value = 10;
    app.MiddleWidthField.Value = 15;
    app.CenterDiameterCmField.Value = 15;
    Z = invokeComputeZonesFromUI(app);
end

function Z = invokeComputeZonesFromUI(app)
    % computeZonesFromUI is a local function in CreatePresetApp.m, not a
    % method -- we exercise it through the public previewZones API,
    % which calls it internally and stashes the result in State.previewZones.
    app.previewZones();
    Z = app.State.previewZones;
end

function m = makeDiscMask(H, r)
    W = H;
    [Y, X] = ndgrid(1:H, 1:W);
    cy = H/2; cx = W/2;
    m = (X - cx).^2 + (Y - cy).^2 <= r^2;
end
