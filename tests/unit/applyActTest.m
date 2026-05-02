function tests = applyActTest
    tests = functiontests(localfunctions);
end

function ctx = makeCtx()
    n = 100;
    bp = {'nose', 'bodycenter', 'tailbase', 'lefthindlimb', 'righthindlimb', 'headcenter'};
    H = numel(bp);
    X = repmat((1:n) * 5, H, 1);   % move along x
    Y = ones(H, n) * 100;
    V = zeros(H, n);
    V(:, 1:30)   = 0.5;        % rest
    V(:, 31:60)  = 3;          % walk
    V(:, 61:90)  = 8;          % loc
    V(:, 91:100) = 0.3;        % rest tail
    z(1).name = 'arena';
    z(1).type = 'area';
    z(1).maskfilled = true(200, 600);
    ctx.X = X; ctx.Y = Y; ctx.velocityCmS = V;
    ctx.bodyParts = bp;
    ctx.zones = z;
    ctx.frameRate = 30;
    ctx.pixelsPerCm = 5;
    ctx.allActs = sphynx.acts.emptyActsArray();
    ctx.resultsByName = containers.Map();
end

function testSimpleSpeedAct(testCase)
    ctx = makeCtx();
    a = sphynx.acts.buildSimpleAct('Name','rest', 'BodyPart','bodycenter', ...
        'SpeedMin', 0, 'SpeedMax', 1);
    b = sphynx.acts.applyAct(a, ctx);
    verifyEqual(testCase, sum(b), 40);   % frames 1:30 + 91:100
end

function testComplexUnion(testCase)
    ctx = makeCtx();
    a1 = sphynx.acts.buildSimpleAct('Name','a1','BodyPart','bodycenter','SpeedMin',0,'SpeedMax',1);
    a2 = sphynx.acts.buildSimpleAct('Name','a2','BodyPart','bodycenter','SpeedMin',7,'SpeedMax',Inf);
    c  = sphynx.acts.buildComplexAct('Name','either','Components',{'a1','a2'},'Operation','union');
    acts = [a1, a2, c];
    res = sphynx.acts.evalActsLibrary(acts, ctx);
    verifyTrue(testCase, isKey(res, 'either'));
    verifyEqual(testCase, sum(res('either')), 40 + 30);
end

function testComplexExclude(testCase)
    ctx = makeCtx();
    a1 = sphynx.acts.buildSimpleAct('Name','low','BodyPart','bodycenter','SpeedMin',0,'SpeedMax',5);
    a2 = sphynx.acts.buildSimpleAct('Name','rest_only','BodyPart','bodycenter','SpeedMin',0,'SpeedMax',1);
    c  = sphynx.acts.buildComplexAct('Name','walking','Components',{'low','rest_only'},'Operation','exclude');
    acts = [a1, a2, c];
    res = sphynx.acts.evalActsLibrary(acts, ctx);
    verifyEqual(testCase, sum(res('walking')), 30);   % only the walk band
end

function testFreezingSpecial(testCase)
    ctx = makeCtx();
    a = sphynx.acts.emptyAct();
    a.name = 'freeze';
    a.type = 'special';
    a.specialKind = 'freezing';
    a.bodyParts = {'headcenter', 'bodycenter'};
    a.speedMax = 1;
    b = sphynx.acts.applyAct(a, ctx);
    verifyEqual(testCase, sum(b), 40);
end
