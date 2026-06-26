function metrics = barnesSessionMetrics(result, varargin)
% BARNESSESSIONMETRICS  Session-level Barnes-maze metrics derived from
% an analyzeSession result struct.
%
%   metrics = sphynx.pipeline.barnesSessionMetrics(result)
%   metrics = sphynx.pipeline.barnesSessionMetrics(result, 'NumObjects', 19)
%
%   `result` must come from sphynx.pipeline.analyzeSession (or be shaped
%   like one) and is expected to contain a struct array result.Acts with
%   the canonical Barnes default-act names (see
%   sphynx.acts.actsLibraryBarnesDefaults):
%     nose_at_target
%     nose_at_object1 .. nose_at_holeN
%     body_at_target
%     body_at_object1 .. body_at_holeN
%     nose_at_platform / body_at_platform / nose_at_any_hole
%
%   Hole geometry assumption: the N escape holes plus the target form a
%   ring of NumObjects+1 evenly-spaced holes. object1 sits one slot
%   clockwise (or counter-clockwise -- direction is symmetric for the
%   angular error metric) from the target, objectN sits the farthest
%   from the target along the ring. Angle step = 360 / (NumObjects+1).
%
%   Returned struct:
%     TotalNoseHoleVisits      sum of ActNumber across nose_at_holeN
%     TotalBodyHoleVisits      sum of ActNumber across body_at_holeN
%     FirstCheckedHoleNumber   N for the earliest nose_at_holeN
%                              episode start. NaN if no per-hole act
%                              fired.
%     FirstCheckedHoleErrorDeg angular distance |first checked| ->
%                              target, in degrees (0 means "checked
%                              the target first", 180 the opposite
%                              hole). NaN if no hole was checked.
%     MeanCheckedHoleErrorDeg  mean of angular distances across the
%                              set of nose_at_holeN acts that fired
%                              at least once. NaN if none did.
%     TargetHoleVisitOrder     ordinal position of the first
%                              nose_at_target episode in the time-
%                              ordered sequence of (nose_at_holeN
%                              episodes + nose_at_target's own first
%                              episode). 1 means target was the very
%                              first hole sniffed. NaN if target was
%                              never reached.
%     NumCheckedHoles          count of distinct objectN holes that
%                              were sniffed at least once.
%
%   Name-value:
%     'NumObjects'  default 19 -- matches the Demo/BARNES_v2 layout.

    p = inputParser;
    p.addParameter('NumObjects', 19, @(v) isnumeric(v) && isscalar(v) && v >= 1);
    parse(p, varargin{:});
    nObj = p.Results.NumObjects;

    metrics = makeEmptyMetrics();

    if ~isstruct(result) || ~isfield(result, 'Acts') || isempty(result.Acts)
        return;
    end
    Acts = result.Acts;
    frameRate = NaN;
    if isfield(result, 'Options') && isstruct(result.Options) ...
            && isfield(result.Options, 'FrameRate')
        frameRate = result.Options.FrameRate;
    end

    % Angle step around the hole ring. Total slots = nObj + 1 (the +1
    % is the target slot itself).
    angleStep = 360 / (nObj + 1);

    % Helpers to look up an act by name.
    actNames = {Acts.ActName};

    % --- TotalNoseHoleVisits / TotalBodyHoleVisits ----------------------
    metrics.TotalNoseHoleVisits = 0;
    metrics.TotalBodyHoleVisits = 0;
    for n = 1:nObj
        kN = findActIdx(actNames, sprintf('nose_at_hole%d', n));
        if ~isempty(kN) && isfield(Acts(kN), 'ActNumber') && ~isempty(Acts(kN).ActNumber)
            metrics.TotalNoseHoleVisits = metrics.TotalNoseHoleVisits + Acts(kN).ActNumber;
        end
        kB = findActIdx(actNames, sprintf('body_at_hole%d', n));
        if ~isempty(kB) && isfield(Acts(kB), 'ActNumber') && ~isempty(Acts(kB).ActNumber)
            metrics.TotalBodyHoleVisits = metrics.TotalBodyHoleVisits + Acts(kB).ActNumber;
        end
    end

    % --- FirstCheckedHole / NumCheckedHoles / MeanCheckedHoleErrorDeg ---
    % "Checked" = nose_at_holeN fired at least once.
    checkedHoles = [];                 % vector of N values
    checkedFirstStartSec = [];         % vector of FirstStartSec values
    for n = 1:nObj
        kN = findActIdx(actNames, sprintf('nose_at_hole%d', n));
        if isempty(kN); continue; end
        cnt = getField(Acts(kN), 'ActNumber', 0);
        if cnt < 1; continue; end
        checkedHoles(end + 1) = n; %#ok<AGROW>
        checkedFirstStartSec(end + 1) = getField(Acts(kN), 'FirstStartSec', NaN); %#ok<AGROW>
    end
    metrics.NumCheckedHoles = numel(checkedHoles);

    if isempty(checkedHoles)
        metrics.FirstCheckedHoleNumber   = NaN;
        metrics.FirstCheckedHoleErrorDeg = NaN;
        metrics.MeanCheckedHoleErrorDeg  = NaN;
    else
        % Earliest nose-at-object* episode wins. Ties broken by lowest N.
        [tMin, idxMin] = min(checkedFirstStartSec);
        if isnan(tMin)
            metrics.FirstCheckedHoleNumber   = NaN;
            metrics.FirstCheckedHoleErrorDeg = NaN;
        else
            firstN = checkedHoles(idxMin);
            metrics.FirstCheckedHoleNumber   = firstN;
            metrics.FirstCheckedHoleErrorDeg = holeAngle(firstN, nObj, angleStep);
        end
        angles = arrayfun(@(N) holeAngle(N, nObj, angleStep), checkedHoles);
        metrics.MeanCheckedHoleErrorDeg = round(mean(angles), 2);
    end

    % --- TargetHoleVisitOrder ------------------------------------------
    % Ordinal position of the first nose_at_target episode in the union
    % of (nose_at_holeN episodes) + (nose_at_target's first episode),
    % sorted by episode start frame.
    targetIdx = findActIdx(actNames, 'nose_at_target');
    if isempty(targetIdx) || getField(Acts(targetIdx), 'ActNumber', 0) < 1
        metrics.TargetHoleVisitOrder = NaN;
    else
        targetT = getField(Acts(targetIdx), 'FirstStartSec', NaN);
        if isnan(targetT) || isnan(frameRate) || frameRate <= 0
            metrics.TargetHoleVisitOrder = NaN;
        else
            % Count nose_at_holeN episodes that started STRICTLY before
            % the first nose_at_target episode. Each episode counted
            % individually (a hole revisited twice = 2 entries).
            earlier = 0;
            for n = 1:nObj
                kN = findActIdx(actNames, sprintf('nose_at_hole%d', n));
                if isempty(kN); continue; end
                if ~isfield(Acts(kN), 'ActArrayRefine') ...
                        || isempty(Acts(kN).ActArrayRefine)
                    continue;
                end
                runs = runStarts(Acts(kN).ActArrayRefine);
                tStarts = (runs - 1) / frameRate;
                earlier = earlier + sum(tStarts < targetT);
            end
            metrics.TargetHoleVisitOrder = earlier + 1;
        end
    end
end

% --- locals ---------------------------------------------------------------

function metrics = makeEmptyMetrics()
    metrics = struct( ...
        'TotalNoseHoleVisits',      0, ...
        'TotalBodyHoleVisits',      0, ...
        'NumCheckedHoles',          0, ...
        'FirstCheckedHoleNumber',   NaN, ...
        'FirstCheckedHoleErrorDeg', NaN, ...
        'MeanCheckedHoleErrorDeg',  NaN, ...
        'TargetHoleVisitOrder',     NaN);
end

function idx = findActIdx(names, target)
    idx = find(strcmpi(names, target), 1);
end

function v = getField(s, name, default)
    if isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = default;
    end
end

function deg = holeAngle(N, nObj, angleStep)
    % Angular distance from objectN to the target, measured on the
    % hole ring. The ring is symmetric, so the angular error is the
    % shorter of the two paths around.
    full = 360;
    forward = N * angleStep;
    backward = full - forward;
    deg = round(min(forward, backward), 2);
end

function starts = runStarts(mask)
    % Frame indices (1-based) where the binary `mask` transitions from
    % 0 to 1. Mirrors how sphynx.acts.refineAct walks runs, but cheaper
    % when we only need the start frames.
    m = logical(mask(:))';
    if isempty(m); starts = []; return; end
    edges = diff([false, m]) == 1;
    starts = find(edges);
end
