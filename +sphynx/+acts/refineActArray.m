function out = refineActArray(bool, minRunFrames, minGapFrames)
% REFINEACTARRAY  Two-pass cleanup of a 0/1 act timeseries.
%
%   out = sphynx.acts.refineActArray(bool, minRunFrames, minGapFrames)
%
%   Pass 1 — drop runs of 1s shorter than minRunFrames.
%   Pass 2 — bridge gaps of 0s shorter than minGapFrames between
%            the runs that survived pass 1 (gaps from index 1 to the
%            first run are NOT bridged — those are session-start zeros,
%            not real inter-event gaps).
%
%   Both arguments are integer frame counts. 0 (or negative) disables
%   the corresponding pass.
%
%   Port of legacy functions/RefineLine.m, with the same edge-case
%   handling (a run that touches the last frame is kept; a leading-edge
%   gap is not bridged so the act doesn't bleed into the start of a
%   recording where DLC isn't reliable yet).

    bool = logical(bool(:)');
    n = numel(bool);
    if n == 0; out = bool; return; end

    if nargin < 2 || isempty(minRunFrames); minRunFrames = 0; end
    if nargin < 3 || isempty(minGapFrames); minGapFrames = 0; end

    % --- Run-length encode --------------------------------------------------
    [runs, lengths] = rle(bool);

    % --- Pass 1: drop short runs of 1s --------------------------------------
    if minRunFrames > 0
        for k = 1:size(runs, 1)
            if bool(runs(k, 1)) && lengths(k) < minRunFrames
                bool(runs(k, 1):runs(k, 2)) = false;
            end
        end
    end

    % --- Pass 2: bridge short gaps of 0s ------------------------------------
    if minGapFrames > 0
        [runs2, lengths2] = rle(bool);
        for k = 1:size(runs2, 1)
            isGap = ~bool(runs2(k, 1));
            % Skip the leading-edge gap (it touches index 1) and the
            % trailing one (touches index n) — these aren't between
            % real act events.
            isLeading  = runs2(k, 1) == 1;
            isTrailing = runs2(k, 2) == n;
            if isGap && ~isLeading && ~isTrailing && lengths2(k) < minGapFrames
                bool(runs2(k, 1):runs2(k, 2)) = true;
            end
        end
    end

    out = bool;
end

function [runs, lengths] = rle(bool)
    if isempty(bool); runs = zeros(0, 2); lengths = zeros(0, 1); return; end
    d = [true, diff(bool) ~= 0];
    starts = find(d);
    ends = [starts(2:end) - 1, numel(bool)];
    runs = [starts(:), ends(:)];
    lengths = ends(:) - starts(:) + 1;
end
