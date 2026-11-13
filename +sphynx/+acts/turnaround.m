function b = turnaround(headX, headY, tailX, tailY, frameRate, pixelsPerCm, axisVec, varargin)
% TURNAROUND  Frames of a turn to the opposite direction on a linear track.
%
%   b = sphynx.acts.turnaround(headX, headY, tailX, tailY, frameRate, pixelsPerCm, axisVec, ...)
%
%   The body axis is rear point -> head (the library act uses body centre
%   -> head centre). Each frame is classified by the cosine between the
%   body axis and the track axis `axisVec` ([ux uy], pixel space, any length):
%     +1  facing along the axis      (cos >= FacingCos)
%     -1  facing against the axis    (cos <= -FacingCos)
%      0  in between, or body too short to tell (curled, rearing)
%   Facing runs shorter than MinFacingSec are discarded, so a one-frame
%   head/tail swap of the tracker never counts as facing. A turn is found
%   between a facing run and the next facing run of the opposite sign, when
%   that in-between stretch lasts at most MaxTurnSec. Two runs of the same
%   sign around a gap (the animal looked back and returned) are not a turn.
%   A direct flip with no frames in between is a tracker swap, not a turn.
%
%   The reported turn covers the whole rotation, not only its middle: it
%   starts after the last frame still aligned with the old direction
%   (|cos| >= ExtendCos) and ends before the first frame aligned with the
%   new one. A turn still shorter than MinTurnSec is widened to MinTurnSec
%   around its centre: mice do not turn round in under a second, so a
%   shorter detection means the tracker lost part of the turn, not that
%   the turn was fast. Neighbouring turns are kept at least one frame apart.
%
%   Name-value:
%     'FacingCos'      cosine threshold for a facing frame (default 0.7, ~45 deg)
%     'ExtendCos'      cosine of "still aligned" used to find where the turn
%                      starts and ends (default 0.95, ~18 deg)
%     'MinBodyCm'      rear-to-head distance for a facing frame, cm (default 2).
%                      A curled animal has no clear facing direction.
%     'MinFacingSec'   minimum facing run, s (default 0.75). Shorter runs
%                      are a look back over the shoulder, not a new
%                      direction: with head centre -> body centre such
%                      look-backs otherwise come out as turn pairs
%                      (there and straight back).
%   Defaults chosen on six LT1 sessions against the number of end-to-end
%   runs (each run ends in a turn); to be refitted on hand-scored turns.
%     'MaxTurnSec'     longest in-between stretch (|cos| < FacingCos), s (default 10)
%     'MinTurnSec'     shortest reported turn, s (default 1)
%     'XKcorr'         x scale correction (default 1)
%
%   Output: 1xN logical, true inside turns.

    p = inputParser;
    addParameter(p, 'FacingCos', 0.7, @(v) isnumeric(v) && isscalar(v) && v > 0 && v < 1);
    addParameter(p, 'ExtendCos', 0.95, @(v) isnumeric(v) && isscalar(v) && v > 0 && v <= 1);
    addParameter(p, 'MinBodyCm', 2, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'MinFacingSec', 0.75, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'MaxTurnSec', 10, @(v) isnumeric(v) && isscalar(v) && v > 0);
    addParameter(p, 'MinTurnSec', 1, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'XKcorr', 1, @(v) isnumeric(v) && isscalar(v) && v > 0);
    parse(p, varargin{:});
    o = p.Results;

    headX = headX(:)'; headY = headY(:)'; tailX = tailX(:)'; tailY = tailY(:)';
    n = numel(headX);
    b = false(1, n);

    ax = axisVec(1) * o.XKcorr; ay = axisVec(2);
    aLen = hypot(ax, ay);
    if ~(aLen > 0); return; end
    ax = ax / aLen; ay = ay / aLen;

    hx = (headX - tailX) * o.XKcorr / pixelsPerCm;
    hy = (headY - tailY) / pixelsPerCm;
    hLen = hypot(hx, hy);
    c = (hx * ax + hy * ay) ./ hLen;

    ok = isfinite(c) & hLen >= o.MinBodyCm;
    state = zeros(1, n);
    state(ok & c >= o.FacingCos) = 1;
    state(ok & c <= -o.FacingCos) = -1;

    % Facing runs: [start end sign], short ones dropped.
    minRun = max(1, round(o.MinFacingSec * frameRate));
    runs = zeros(0, 3);
    k = 1;
    while k <= n
        if state(k) == 0; k = k + 1; continue; end
        e = k;
        while e < n && state(e + 1) == state(k); e = e + 1; end
        if e - k + 1 >= minRun
            runs(end + 1, :) = [k e state(k)]; %#ok<AGROW>
        end
        k = e + 1;
    end

    maxTurn = round(o.MaxTurnSec * frameRate);
    minTurn = round(o.MinTurnSec * frameRate);
    turns = zeros(0, 4);   % [start end lowest-allowed highest-allowed]
    for r = 1:size(runs, 1) - 1
        if runs(r, 3) == runs(r + 1, 3); continue; end
        s = runs(r, 2) + 1;
        e = runs(r + 1, 1) - 1;
        if e < s; continue; end              % instant flip: tracker swap
        if e - s + 1 > maxTurn; continue; end

        % Start: after the last frame of the old run still aligned within ExtendCos.
        lo = runs(r, 1); hi = runs(r + 1, 2);
        before = lo:runs(r, 2);
        aligned = before(ok(before) & runs(r, 3) * c(before) >= o.ExtendCos);
        if isempty(aligned); s = lo; else; s = aligned(end) + 1; end
        % End: before the first frame of the new run aligned within ExtendCos.
        after = runs(r + 1, 1):hi;
        aligned = after(ok(after) & runs(r + 1, 3) * c(after) >= o.ExtendCos);
        if isempty(aligned); e = hi; else; e = aligned(1) - 1; end

        if e - s + 1 < minTurn
            mid = (s + e) / 2;
            s = round(mid - (minTurn - 1) / 2);
            e = s + minTurn - 1;
            % keep inside the two facing runs and the recording
            if s < max(1, lo); e = e + (max(1, lo) - s); s = max(1, lo); end
            if e > min(n, hi); s = max(max(1, lo), s - (e - min(n, hi))); e = min(n, hi); end
        end
        turns(end + 1, :) = [s e max(1, lo) min(n, hi)]; %#ok<AGROW>
    end

    % Neighbouring turns share a facing run; if widening made them touch,
    % split at the midpoint, leave one frame between them, and move each
    % outwards (into its own facing run) so it keeps MinTurnSec.
    for t = 2:size(turns, 1)
        if turns(t, 1) <= turns(t - 1, 2) + 1
            mid = floor((turns(t - 1, 2) + turns(t, 1)) / 2);
            turns(t - 1, 2) = mid - 1;
            turns(t - 1, 1) = max(turns(t - 1, 3), min(turns(t - 1, 1), mid - minTurn));
            turns(t, 1) = mid + 1;
            turns(t, 2) = min(turns(t, 4), max(turns(t, 2), mid + minTurn));
        end
    end
    for t = 1:size(turns, 1)
        if turns(t, 2) >= turns(t, 1); b(turns(t, 1):turns(t, 2)) = true; end
    end
end
