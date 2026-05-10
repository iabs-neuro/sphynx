function out = refineActArray(bool, minRunFrames, minGapFrames)
% REFINEACTARRAY  Two-pass cleanup of a 0/1 act timeseries.
%
%   out = sphynx.acts.refineActArray(bool, minRunFrames, minGapFrames)
%
%   Pass 1 — bridge gaps of 0s shorter than minGapFrames between
%            adjacent runs. Conceptually: "if a hole inside an act is
%            short, that hole is still part of the act."
%   Pass 2 — drop runs of 1s shorter than minRunFrames. Conceptually:
%            "after consolidating fragments, kill anything that is
%            still too short to be a real event."
%
%   Order matters. Bridging first lets a fragmented near-event
%   consolidate into a single long run that then survives the drop
%   pass; dropping first would erase those fragments before they get a
%   chance to merge.
%
%   Both arguments are integer frame counts. 0 (or negative) disables
%   the corresponding pass.
%
%   Edge handling: leading and trailing gaps (those that touch index 1
%   or index n) are NOT bridged — they're session boundaries, not
%   inter-event gaps. A run that touches the last frame IS still
%   eligible for the drop pass.

    bool = logical(bool(:)');
    n = numel(bool);
    if n == 0; out = bool; return; end

    if nargin < 2 || isempty(minRunFrames); minRunFrames = 0; end
    if nargin < 3 || isempty(minGapFrames); minGapFrames = 0; end

    % --- Pass 1: bridge short gaps of 0s ------------------------------------
    if minGapFrames > 0
        [runs1, lengths1] = rle(bool);
        for k = 1:size(runs1, 1)
            isGap      = ~bool(runs1(k, 1));
            isLeading  = runs1(k, 1) == 1;
            isTrailing = runs1(k, 2) == n;
            if isGap && ~isLeading && ~isTrailing && lengths1(k) < minGapFrames
                bool(runs1(k, 1):runs1(k, 2)) = true;
            end
        end
    end

    % --- Pass 2: drop short runs of 1s --------------------------------------
    if minRunFrames > 0
        [runs2, lengths2] = rle(bool);
        for k = 1:size(runs2, 1)
            if bool(runs2(k, 1)) && lengths2(k) < minRunFrames
                bool(runs2(k, 1):runs2(k, 2)) = false;
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
