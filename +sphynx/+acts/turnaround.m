function b = turnaround(headX, headY, tailX, tailY, frameRate, pixelsPerCm, axisVec, varargin)
% TURNAROUND  Frames of a turn to the opposite direction on a linear track.
%
%   b = sphynx.acts.turnaround(headX, headY, tailX, tailY, frameRate, pixelsPerCm, axisVec, ...)
%
%   The body axis is tail -> head. Each frame is classified by the cosine
%   between the body axis and the track axis `axisVec` ([ux uy], pixel
%   space, any length):
%     +1  facing along the axis      (cos >= FacingCos)
%     -1  facing against the axis    (cos <= -FacingCos)
%      0  in between, or body too short to tell (curled, rearing)
%   Facing runs shorter than MinFacingSec are discarded, so a one-frame
%   head/tail swap of the tracker never counts as facing. A turn is the
%   stretch between a facing run and the next facing run of the opposite
%   sign, when that stretch lasts at most MaxTurnSec. Two runs of the same
%   sign around a gap (the animal looked back and returned) are not a turn.
%   A direct flip with no frames in between is a tracker swap, not a turn.
%
%   Name-value:
%     'FacingCos'      cosine threshold for a facing frame (default 0.7, ~45 deg)
%     'MinBodyCm'      tail-to-head distance for a facing frame, cm (default 2)
%     'MinFacingSec'   minimum facing run, s (default 0.2)
%     'MaxTurnSec'     longest turn, s (default 10)
%     'XKcorr'         x scale correction (default 1)
%
%   Output: 1xN logical, true inside turns.

    p = inputParser;
    addParameter(p, 'FacingCos', 0.7, @(v) isnumeric(v) && isscalar(v) && v > 0 && v < 1);
    addParameter(p, 'MinBodyCm', 2, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'MinFacingSec', 0.2, @(v) isnumeric(v) && isscalar(v) && v >= 0);
    addParameter(p, 'MaxTurnSec', 10, @(v) isnumeric(v) && isscalar(v) && v > 0);
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

    state = zeros(1, n);
    ok = isfinite(c) & hLen >= o.MinBodyCm;
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
    for r = 1:size(runs, 1) - 1
        if runs(r, 3) == runs(r + 1, 3); continue; end
        s = runs(r, 2) + 1;
        e = runs(r + 1, 1) - 1;
        if e < s; continue; end              % instant flip: tracker swap
        if e - s + 1 > maxTurn; continue; end
        b(s:e) = true;
    end
end
