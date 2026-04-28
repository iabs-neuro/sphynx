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

    % canonicalName -> cell array of accepted synonyms (lowercased internally)
    synonymMap = {
        'MiniscopeUCLA',     {'miniscopeucla'};
        'Nose',              {'nose'};
        'LeftEar',           {'leftear'};
        'RightEar',          {'rightear'};
        'HeadCenter',        {'headcenter'};
        'LeftForeLimb',      {'leftforelimb'};
        'RightForeLimb',     {'righforelimb', 'rightforelimb'};
        'LeftBodyCenter',    {'leftbody'};
        'RightBodyCenter',   {'rightbody'};
        'LeftHindLimb',      {'lefthindlimb'};
        'RightHindLimb',     {'righthindlimb'};
        'Tailbase',          {'tailbase', 'tail base'};
        'Center',            {'mass centre', 'mass center', 'bodycenter', 'center'};
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
