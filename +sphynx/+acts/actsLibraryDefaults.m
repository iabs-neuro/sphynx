function acts = actsLibraryDefaults()
% ACTSLIBRARYDEFAULTS  Default behavioral acts mirroring legacy
% BehaviorAnalyzer thresholds (rest / walk / locomotion / freezing /
% rears). Returned as a struct array compatible with sphynx.acts.applyAct.

    cfg = sphynx.pipeline.defaultConfig();
    rest = cfg.acts.restThresholdCmS;       % default 1
    loc  = cfg.acts.locThresholdCmS;        % default 5
    rearTBC = cfg.acts.rearThresholdTailbasePawsCm;   % 3.6 cm
    rearABP = cfg.acts.rearThresholdAllBodyPartsPxl;   % 170 px

    acts = sphynx.acts.emptyActsArray();

    acts(end+1) = sphynx.acts.buildSimpleAct( ...
        'Name', 'rest', 'Zones', {}, 'ZoneOp', 'OR', ...
        'BodyPart', 'bodycenter', 'SpeedMin', 0, 'SpeedMax', rest);

    acts(end+1) = sphynx.acts.buildSimpleAct( ...
        'Name', 'walk', 'Zones', {}, 'ZoneOp', 'OR', ...
        'BodyPart', 'bodycenter', 'SpeedMin', rest, 'SpeedMax', loc);

    acts(end+1) = sphynx.acts.buildSimpleAct( ...
        'Name', 'locomotion', 'Zones', {}, 'ZoneOp', 'OR', ...
        'BodyPart', 'bodycenter', 'SpeedMin', loc, 'SpeedMax', Inf);

    % Freezing — head + center both below rest threshold
    a = sphynx.acts.emptyAct();
    a.name = 'freezing';
    a.type = 'special';
    a.specialKind = 'freezing';
    a.bodyParts = {'headcenter', 'bodycenter'};
    a.speedMax = rest;
    acts(end+1) = a;

    % Rear (tailbase-paws mode by default). Singular to match the
    % built-in act name produced by analyzeSession; the case-insensitive
    % dedup then collapses both into one row in the etogram.
    a = sphynx.acts.emptyAct();
    a.name = 'rear';
    a.type = 'special';
    a.specialKind = 'rears';
    a.rearMode = 'TailbasePaws';
    a.thresholdCm = rearTBC;
    a.thresholdPxl = rearABP;
    a.rearAutoThreshold = true;  % adapt per session
    acts(end+1) = a;
end
