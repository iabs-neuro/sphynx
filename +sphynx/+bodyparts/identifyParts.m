function Point = identifyParts(bodyPartsNames)
% IDENTIFYPARTS  Find indices of well-known body parts by synonym matching.
%
%   Point = sphynx.bodyparts.identifyParts(bodyPartsNames) takes a cell
%   array of body-part labels (as parsed from a DLC csv header) and
%   returns a struct mapping canonical body-part names to the index of
%   the first matching label in bodyPartsNames (case-insensitive).
%
%   Returned struct fields (each is [] if not present in input):
%     MiniscopeUCLA, Nose, LeftEar, RightEar, HeadCenter,
%     LeftForeLimb, RightForeLimb, LeftBodyCenter, RightBodyCenter,
%     LeftHindLimb, RightHindLimb, Tailbase, Center.
%
%   Ported from legacy functions/find_bodyPart.m, with the synonym
%   map rebuilt as an explicit table for readability.

    % canonicalName -> cell array of accepted synonyms (lowercased internally).
    %
    % Covers three naming families seen in the wild:
    %   1. Lab-internal labels  (nose, tailbase, bodycenter, leftbody...)
    %   2. DLC default with spaces  (tail base, mass centre)
    %   3. DLC superanimal_topviewmouse with underscores  (tail_base,
    %      mouse_center, left_midside, right_midside, head_midpoint,
    %      left_shoulder, left_hip, left_ear, right_ear, ...).
    %
    % Add new aliases here when a new DLC schema lands -- this map is the
    % single point of truth that downstream code (analyzeSession,
    % computeCenter, renderActsVideo, freezing, rear, relativeCoords)
    % consults to resolve canonical body parts.
    synonymMap = {
        'MiniscopeUCLA',     {'miniscopeucla'};
        'Nose',              {'nose', 'snout'};
        'LeftEar',           {'leftear', 'left_ear', 'left ear', 'left_ear_tip'};
        'RightEar',          {'rightear', 'right_ear', 'right ear', 'right_ear_tip'};
        'HeadCenter',        {'headcenter', 'head_midpoint', 'head midpoint', ...
                              'head_center', 'head center', 'neck'};
        'LeftForeLimb',      {'leftforelimb', 'left_forelimb', 'left forelimb', ...
                              'left_shoulder', 'left shoulder'};
        'RightForeLimb',     {'righforelimb', 'rightforelimb', 'right_forelimb', ...
                              'right forelimb', 'right_shoulder', 'right shoulder'};
        'LeftBodyCenter',    {'leftbody', 'left_body', 'left body', ...
                              'left_midside', 'left midside'};
        'RightBodyCenter',   {'rightbody', 'right_body', 'right body', ...
                              'right_midside', 'right midside'};
        'LeftHindLimb',      {'lefthindlimb', 'left_hindlimb', 'left hindlimb', ...
                              'left_hip', 'left hip'};
        'RightHindLimb',     {'righthindlimb', 'right_hindlimb', 'right hindlimb', ...
                              'right_hip', 'right hip'};
        'Tailbase',          {'tailbase', 'tail base', 'tail_base', 'tail1'};
        'Center',            {'mass centre', 'mass center', ...
                              'bodycenter', 'body_center', 'body center', ...
                              'center', 'mouse_center', 'mouse center'};
    };

    inputLower = lower(string(bodyPartsNames(:)'));

    Point = struct();
    for k = 1:size(synonymMap, 1)
        canon = synonymMap{k, 1};
        synonyms = lower(string(synonymMap{k, 2}));
        idx = find(ismember(inputLower, synonyms), 1);
        if isempty(idx)
            Point.(canon) = [];
        else
            Point.(canon) = idx;
        end
    end
end
