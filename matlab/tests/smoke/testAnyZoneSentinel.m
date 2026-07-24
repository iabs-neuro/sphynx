% Smoke-test: '<any zone>' sentinel becomes empty zones in act,
% and applyAct treats empty zones as "any zone" (no zone gate).
addpath(pwd);
clear functions;

zones = {'<any zone>'};
zones = zones(~strcmp(zones, '<any zone>'));
act = sphynx.acts.buildSimpleAct( ...
    'Name', 'test_any', 'Zones', zones, 'ZoneOp', 'OR', ...
    'BodyPart', 'bodycenter', 'SpeedMin', 0, 'SpeedMax', Inf);
assert(strcmp(act.name, 'test_any'), 'name');
assert(isempty(act.zones), 'zones should be empty');
assert(isinf(act.speedMax), 'speedMax Inf');
fprintf('PASS: any-zone sentinel becomes empty zones list\n');

zones2 = {'<any zone>', 'corner1', 'corner2'};
zones2 = zones2(~strcmp(zones2, '<any zone>'));
assert(numel(zones2) == 2, 'sentinel filter');
fprintf('PASS: sentinel filtered alongside real zones\n');

ctx.X = rand(1, 100); ctx.Y = rand(1, 100);
ctx.bodyParts = {'bodycenter'};
ctx.velocityCmS = ones(1, 100);
ctx.zones = struct('name', {}, 'maskfilled', {});
ctx.frameRate = 30;
ctx.allActs = sphynx.acts.emptyActsArray();
ctx.resultsByName = containers.Map();
ctx.pixelsPerCm = 10;

bool = sphynx.acts.applyAct(act, ctx);
assert(all(bool), 'all frames should be active when no zone gate and speed in range');
fprintf('PASS: applyAct treats empty zones as "any zone"\n');

fprintf('ALL_TESTS_PASS\n');
