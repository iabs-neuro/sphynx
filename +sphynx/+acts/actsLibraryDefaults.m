function acts = actsLibraryDefaults()
% ACTSLIBRARYDEFAULTS  Default behavioral acts mirroring legacy
% BehaviorAnalyzer thresholds (rest / walk / locomotion / freezing /
% rears), plus the linear-track acts backing and turnaround. Returned as
% a struct array compatible with sphynx.acts.applyAct.

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

    % Backing: the body centre moves opposite to where the head points.
    % Thresholds are first guesses, to be calibrated on hand-scored
    % linear-track data. Fields reused: speedMin = backward speed along
    % the body axis, thresholdCm = minimum centre-to-head distance.
    a = sphynx.acts.emptyAct();
    a.name = 'backing';
    a.type = 'special';
    a.specialKind = 'backing';
    a.bodyParts = {'headcenter', 'bodycenter'};
    a.speedMin = rest;
    a.thresholdCm = 1;
    a.minDurationSec = 0.3;
    a.maxGapSec = 0.2;
    acts(end+1) = a;

    % Turnaround on a linear track: the nose-to-tail direction flips
    % relative to the track axis. thresholdCm = minimum tail-to-nose
    % distance for a frame to count as facing one way. No gap bridging:
    % it would merge two turns separated by a short straight run.
    a = sphynx.acts.emptyAct();
    a.name = 'turnaround';
    a.type = 'special';
    a.specialKind = 'turnaround';
    a.bodyParts = {'nose', 'tailbase'};
    a.thresholdCm = 2;
    a.minDurationSec = 0.2;
    a.maxGapSec = 0;
    acts(end+1) = a;
end
