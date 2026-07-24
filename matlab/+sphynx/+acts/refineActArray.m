function out = refineActArray(bool, minRunFrames, maxBridgeFrames)
% REFINEACTARRAY  Two-pass cleanup of a 0/1 act timeseries.
%
%   out = sphynx.acts.refineActArray(bool, minRunFrames, maxBridgeFrames)
%
%   Pass 1 — fill in short holes (runs of 0s) shorter than
%            maxBridgeFrames between adjacent runs of 1s.
%            Conceptually: "if a hole inside an act is shorter than
%            this threshold, it counts as part of the act."
%   Pass 2 — drop runs of 1s shorter than minRunFrames.
%            Conceptually: "after consolidating fragments, kill any
%            run that is still too short to be a real event."
%
%   Order matters. Filling holes first lets a fragmented near-event
%   consolidate into one long run that then survives the drop pass;
%   dropping first would erase those fragments before they get the
%   chance to merge.
%
%   Both arguments are integer frame counts. 0 (or negative) disables
%   the corresponding pass.
%
%   Edge handling: leading and trailing zero-runs (those that touch
%   index 1 or index n) are NEVER filled — they're session boundaries,
%   not inter-event holes. A 1-run that touches the last frame IS
%   still eligible for the drop pass.

    bool = logical(bool(:)');
    n = numel(bool);
    if n == 0; out = bool; return; end

    if nargin < 2 || isempty(minRunFrames); minRunFrames = 0; end
    if nargin < 3 || isempty(maxBridgeFrames); maxBridgeFrames = 0; end

    % --- Pass 1: fill holes (zero-runs shorter than maxBridgeFrames) -------
    if maxBridgeFrames > 0
        [runs1, lengths1] = rle(bool);
        for k = 1:size(runs1, 1)
            isHole     = ~bool(runs1(k, 1));
            isLeading  = runs1(k, 1) == 1;
            isTrailing = runs1(k, 2) == n;
            if isHole && ~isLeading && ~isTrailing && lengths1(k) < maxBridgeFrames
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
