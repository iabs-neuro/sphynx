function acts = actsLibraryBarnesDefaults(varargin)
% ACTSLIBRARYBARNESDEFAULTS  Paradigm-specific default acts for the
% Barnes maze. Returns a struct array compatible with
% sphynx.acts.applyAct / sphynx.acts.evalActsLibrary.
%
%   acts = sphynx.acts.actsLibraryBarnesDefaults()
%   acts = sphynx.acts.actsLibraryBarnesDefaults('NumObjects', 19)
%
%   The library covers the standard Barnes paradigm metrics:
%     - escape target visits (at_target)
%     - start platform residence (at_platform)
%     - per-hole visits (at_object1 .. at_objectN), N defaults to 19
%       so it covers the 19-mistakes layout of the Demo/BARNES_v2
%       presets. Pass 'NumObjects' to scale.
%     - any-hole and mistake compound (at_any_hole, at_mistake)
%     - arena-frame acts (at_center, at_wall, at_outside)
%
%   Conventions:
%     - Hole-related acts use 'nose' as the body part -- mice probe
%       holes with the snout, so nose-in-zone is the more sensible
%       proxy than bodycenter. Arena-frame acts use 'bodycenter'.
%     - Each per-hole act gates on the _realout (inflated) variant
%       of the object zone, matching the legacy "visit" definition
%       used by sphynx.preset.buildObjectZones.
%     - at_mistake = at_any_hole EXCLUDE at_target -- compound built
%       on top of the simple acts, evaluated by evalActsLibrary in
%       pass-2 once at_any_hole / at_target are resolved.
%
%   Does NOT include the speed/posture defaults (rest/walk/locomotion/
%   freezing/rear); use sphynx.acts.actsLibraryDefaults for those. The
%   typical Barnes session library is the concatenation of the two:
%       acts = [sphynx.acts.actsLibraryDefaults(), ...
%               sphynx.acts.actsLibraryBarnesDefaults()];

    p = inputParser;
    p.addParameter('NumObjects', 19, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    parse(p, varargin{:});
    nObj = p.Results.NumObjects;

    acts = sphynx.acts.emptyActsArray();

    % --- area acts (arena frame, bodycenter) ----------------------------
    acts(end+1) = sphynx.acts.buildSimpleAct( ...
        'Name', 'at_center', 'Zones', {'center'}, 'ZoneOp', 'OR', ...
        'BodyPart', 'bodycenter');

    acts(end+1) = sphynx.acts.buildSimpleAct( ...
        'Name', 'at_wall', 'Zones', {'wall'}, 'ZoneOp', 'OR', ...
        'BodyPart', 'bodycenter');

    acts(end+1) = sphynx.acts.buildSimpleAct( ...
        'Name', 'at_outside', 'Zones', {'arena_realout'}, 'ZoneOp', 'OR', ...
        'BodyPart', 'bodycenter');

    % --- area acts (escape target + start platform, nose) ---------------
    acts(end+1) = sphynx.acts.buildSimpleAct( ...
        'Name', 'at_target', 'Zones', {'target_realout'}, 'ZoneOp', 'OR', ...
        'BodyPart', 'nose');

    acts(end+1) = sphynx.acts.buildSimpleAct( ...
        'Name', 'at_platform', 'Zones', {'platform_realout'}, 'ZoneOp', 'OR', ...
        'BodyPart', 'bodycenter');

    acts(end+1) = sphynx.acts.buildSimpleAct( ...
        'Name', 'at_any_hole', 'Zones', {'objectall_realout'}, 'ZoneOp', 'OR', ...
        'BodyPart', 'nose');

    % --- per-hole acts (at_object1 .. at_objectN) -----------------------
    for n = 1:nObj
        acts(end+1) = sphynx.acts.buildSimpleAct( ...
            'Name', sprintf('at_object%d', n), ...
            'Zones', {sprintf('object%d_realout', n)}, ...
            'ZoneOp', 'OR', 'BodyPart', 'nose'); %#ok<AGROW>
    end

    % --- compound: errors = any-hole MINUS target -----------------------
    acts(end+1) = sphynx.acts.buildComplexAct( ...
        'Name', 'at_mistake', ...
        'Components', {'at_any_hole', 'at_target'}, ...
        'Operation', 'exclude');
end
