function acts = actsLibraryBarnesDefaults(varargin)
% ACTSLIBRARYBARNESDEFAULTS  Paradigm-specific default acts for the
% Barnes maze. Returns a struct array compatible with
% sphynx.acts.applyAct / sphynx.acts.evalActsLibrary.
%
%   acts = sphynx.acts.actsLibraryBarnesDefaults()
%   acts = sphynx.acts.actsLibraryBarnesDefaults('NumObjects', 19)
%
%   Two body-part variants per zone, matching how the Barnes maze is
%   actually scored in the lab:
%     - nose_at_<zone>  uses the 'nose' body part and the inflated
%       _realout halo around the hole / target / platform / object.
%       The standard nose-poke definition.
%     - body_at_<zone>  uses 'bodycenter' and the stricter _real
%       (geometric) zone -- "the animal physically sat on the spot".
%
%   Layout (NumObjects = 19 by default, matching Demo/BARNES_v2):
%       1   nose_at_target              (nose / target_realout)
%       2-20  nose_at_object1..19       (nose / objectN_realout)
%       21  body_at_target              (bodycenter / target_real)
%       22-40 body_at_object1..19       (bodycenter / objectN_real)
%       41  nose_at_platform            (nose / platform_realout)
%       42  body_at_platform            (bodycenter / platform_real)
%       43  nose_at_any_hole            (nose / objectall_realout)
%
%   No center / wall / outside / mistake compound acts -- Barnes
%   metrics derive everything from per-hole visits + the target/
%   platform/any-hole aggregates. The mistake count is reported by
%   sphynx.pipeline.barnesSessionMetrics, not as a separate act.
%
%   Does NOT include the speed/posture defaults (rest/walk/locomotion/
%   freezing/rear); use sphynx.acts.actsLibraryDefaults for those. A
%   typical Barnes session library is the concatenation of the two:
%       acts = [sphynx.acts.actsLibraryDefaults(), ...
%               sphynx.acts.actsLibraryBarnesDefaults()];

    p = inputParser;
    p.addParameter('NumObjects', 19, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    parse(p, varargin{:});
    nObj = p.Results.NumObjects;

    acts = sphynx.acts.emptyActsArray();

    % --- nose at target ---------------------------------------------------
    acts(end+1) = sphynx.acts.buildSimpleAct( ...
        'Name', 'nose_at_target', 'Zones', {'target_realout'}, ...
        'ZoneOp', 'OR', 'BodyPart', 'nose');

    % --- nose at each hole ------------------------------------------------
    for n = 1:nObj
        acts(end+1) = sphynx.acts.buildSimpleAct( ...
            'Name', sprintf('nose_at_object%d', n), ...
            'Zones', {sprintf('object%d_realout', n)}, ...
            'ZoneOp', 'OR', 'BodyPart', 'nose'); %#ok<AGROW>
    end

    % --- body at target ---------------------------------------------------
    acts(end+1) = sphynx.acts.buildSimpleAct( ...
        'Name', 'body_at_target', 'Zones', {'target_real'}, ...
        'ZoneOp', 'OR', 'BodyPart', 'bodycenter');

    % --- body at each hole ------------------------------------------------
    for n = 1:nObj
        acts(end+1) = sphynx.acts.buildSimpleAct( ...
            'Name', sprintf('body_at_object%d', n), ...
            'Zones', {sprintf('object%d_real', n)}, ...
            'ZoneOp', 'OR', 'BodyPart', 'bodycenter'); %#ok<AGROW>
    end

    % --- platform (start) -------------------------------------------------
    acts(end+1) = sphynx.acts.buildSimpleAct( ...
        'Name', 'nose_at_platform', 'Zones', {'platform_realout'}, ...
        'ZoneOp', 'OR', 'BodyPart', 'nose');
    acts(end+1) = sphynx.acts.buildSimpleAct( ...
        'Name', 'body_at_platform', 'Zones', {'platform_real'}, ...
        'ZoneOp', 'OR', 'BodyPart', 'bodycenter');

    % --- nose at any hole (aggregate) -------------------------------------
    acts(end+1) = sphynx.acts.buildSimpleAct( ...
        'Name', 'nose_at_any_hole', 'Zones', {'objectall_realout'}, ...
        'ZoneOp', 'OR', 'BodyPart', 'nose');
end
