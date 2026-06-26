function acts = actsLibraryBarnesDefaults(varargin)
% ACTSLIBRARYBARNESDEFAULTS  Paradigm-specific default acts for the
% Barnes maze (v3). Returns a struct array compatible with
% sphynx.acts.applyAct / sphynx.acts.evalActsLibrary.
%
%   acts = sphynx.acts.actsLibraryBarnesDefaults()
%   acts = sphynx.acts.actsLibraryBarnesDefaults('NumObjects', 19)
%
% Three act families per zone (target + N escape holes + platform):
%   nose_at_<zone>    nose / <zone>_real      -- nose-poke into the
%                     hole boundary itself (the strict definition of
%                     a visit).
%   body_at_<zone>    bodycenter / <zone>_realout -- body in the
%                     inflated halo around the hole (broader
%                     "near the hole" signal).
%   mouse_inside_<zone>  bodycenter + tailbase + headcenter, all
%                     three inside <zone>_real. Implemented as a
%                     special act with specialKind 'allInZone' so
%                     the framework evaluates the AND of the
%                     per-body-part zone tests in one pass.
%
% Layout (NumObjects = 19 by default, matching Demo/BARNES_v2):
%   1   nose_at_target          (nose / target_real)
%   2-20  nose_at_hole1..19     (nose / objectN_real)
%   21  body_at_target          (bodycenter / target_realout)
%   22-40 body_at_hole1..19     (bodycenter / objectN_realout)
%   41  nose_at_platform        (nose / platform_real)
%   42  body_at_platform        (bodycenter / platform_realout)
%   43  mouse_inside_target     (3 parts / target_real)
%   44-62 mouse_inside_hole1..19 (3 parts / objectN_real)
%   63  mouse_inside_platform   (3 parts / platform_real)
%   64  nose_at_any_hole        (nose / OR(object1_real..objectN_real),
%                                target NOT included; platform
%                                NOT included)
%
% Does NOT include the speed/posture defaults (rest/walk/locomotion
% /freezing/rear); use sphynx.acts.actsLibraryDefaults for those.
% Typical Barnes session library:
%   acts = [sphynx.acts.actsLibraryDefaults(), ...
%           sphynx.acts.actsLibraryBarnesDefaults()];

    p = inputParser;
    p.addParameter('NumObjects', 19, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    parse(p, varargin{:});
    nObj = p.Results.NumObjects;

    acts = sphynx.acts.emptyActsArray();

    % --- nose_at_<zone>: nose in the strict hole zone --------------------
    acts(end+1) = sphynx.acts.buildSimpleAct( ...
        'Name', 'nose_at_target', 'Zones', {'target_real'}, ...
        'ZoneOp', 'OR', 'BodyPart', 'nose');
    for n = 1:nObj
        acts(end+1) = sphynx.acts.buildSimpleAct( ...
            'Name', sprintf('nose_at_hole%d', n), ...
            'Zones', {sprintf('object%d_real', n)}, ...
            'ZoneOp', 'OR', 'BodyPart', 'nose'); %#ok<AGROW>
    end

    % --- body_at_<zone>: bodycenter in the inflated halo -----------------
    acts(end+1) = sphynx.acts.buildSimpleAct( ...
        'Name', 'body_at_target', 'Zones', {'target_realout'}, ...
        'ZoneOp', 'OR', 'BodyPart', 'bodycenter');
    for n = 1:nObj
        acts(end+1) = sphynx.acts.buildSimpleAct( ...
            'Name', sprintf('body_at_hole%d', n), ...
            'Zones', {sprintf('object%d_realout', n)}, ...
            'ZoneOp', 'OR', 'BodyPart', 'bodycenter'); %#ok<AGROW>
    end

    % --- platform (start) family ----------------------------------------
    acts(end+1) = sphynx.acts.buildSimpleAct( ...
        'Name', 'nose_at_platform', 'Zones', {'platform_real'}, ...
        'ZoneOp', 'OR', 'BodyPart', 'nose');
    acts(end+1) = sphynx.acts.buildSimpleAct( ...
        'Name', 'body_at_platform', 'Zones', {'platform_realout'}, ...
        'ZoneOp', 'OR', 'BodyPart', 'bodycenter');

    % --- mouse_inside_<zone>: all 3 parts in the strict zone ------------
    acts(end+1) = makeAllInZoneAct('mouse_inside_target',  'target_real');
    for n = 1:nObj
        acts(end+1) = makeAllInZoneAct(sprintf('mouse_inside_hole%d', n), ...
            sprintf('object%d_real', n)); %#ok<AGROW>
    end
    acts(end+1) = makeAllInZoneAct('mouse_inside_platform', 'platform_real');

    % --- nose_at_any_hole: OR over hole1..holeN, target excluded --------
    anyHoleZones = cell(1, nObj);
    for n = 1:nObj
        anyHoleZones{n} = sprintf('object%d_real', n);
    end
    acts(end+1) = sphynx.acts.buildSimpleAct( ...
        'Name', 'nose_at_any_hole', 'Zones', anyHoleZones, ...
        'ZoneOp', 'OR', 'BodyPart', 'nose');
end

function a = makeAllInZoneAct(name, zoneName)
    a = sphynx.acts.emptyAct();
    a.name        = name;
    a.type        = 'special';
    a.specialKind = 'allInZone';
    a.bodyParts   = {'bodycenter', 'tailbase', 'headcenter'};
    a.zones       = {zoneName};
end
