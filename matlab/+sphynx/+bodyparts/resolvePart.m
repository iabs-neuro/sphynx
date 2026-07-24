function idx = resolvePart(bodyParts, queryName)
% RESOLVEPART  Find a body-part index by alias-tolerant name match.
%
%   idx = sphynx.bodyparts.resolvePart(bodyParts, queryName)
%
%   Resolution order:
%     1. Exact case-insensitive match against `bodyParts`.
%     2. Otherwise treat `queryName` as a synonym for a canonical body
%        part (see sphynx.bodyparts.identifyParts) and return the index
%        of whatever entry in `bodyParts` resolves to the same canonical.
%
%   Use this in act / freezing / rear code instead of `find(strcmpi(...))`
%   so a library written against the legacy "bodycenter" / "tailbase" /
%   "lefthindlimb" naming still finds the body parts on a DLC schema
%   that uses superanimal_topviewmouse names ("mouse_center" /
%   "tail_base" / "left_hip" ...).
%
%   Returns [] if nothing matches.

    idx = [];
    if isempty(bodyParts) || isempty(queryName); return; end

    queryName = char(queryName);

    % Step 1: exact match.
    idx = find(strcmpi(bodyParts, queryName), 1);
    if ~isempty(idx); return; end

    % Step 2: resolve query -> canonical body-part name(s) via
    % identifyParts. A query like 'bodycenter' resolves to canonical
    % 'Center'; 'tailbase' to 'Tailbase'; 'mouse_center' likewise to
    % 'Center'. We then look up which entry in bodyParts owns that
    % canonical.
    qPoint = sphynx.bodyparts.identifyParts({queryName});
    fns = fieldnames(qPoint);
    canons = {};
    for k = 1:numel(fns)
        if ~isempty(qPoint.(fns{k}))
            canons{end+1} = fns{k}; %#ok<AGROW>
        end
    end
    if isempty(canons); idx = []; return; end

    bpPoint = sphynx.bodyparts.identifyParts(bodyParts);
    for k = 1:numel(canons)
        if isfield(bpPoint, canons{k}) && ~isempty(bpPoint.(canons{k}))
            idx = bpPoint.(canons{k}); return;
        end
    end
    idx = [];
end
