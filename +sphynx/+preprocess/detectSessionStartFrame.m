function [startFrame, info] = detectSessionStartFrame(dlc, varargin)
% DETECTSESSIONSTARTFRAME  First frame where the animal is consistently
% detected in the DLC trace -- a proxy for "session start" when the
% recording begins before the animal enters the arena.
%
%   startFrame = sphynx.preprocess.detectSessionStartFrame(dlc, ...)
%
%   The algorithm: slide a window of `WindowFrames` frames forward
%   through the DLC. For each frame, the "population score" is the
%   fraction of body parts with both x and y populated (not NaN, not
%   negative -- DLC sentinel -1.0 is already mapped to NaN by readDLC).
%   The first frame at which the mean score within the look-ahead window
%   meets WindowFillRatio is reported as the session start.
%
%   When the animal is detected from the very first frame, returns 1.
%   When detection never reaches the threshold, returns 1 with a warning
%   in `info.message` so the caller can decide what to do.
%
%   Required input:
%     dlc - struct from sphynx.io.readDLC (uses dlc.X, dlc.Y).
%
%   Optional name-value:
%     'WindowFrames'    sliding window size, default 30 (~1 s at 30 fps)
%     'PopulationRatio' min per-frame populated fraction to count the
%                       frame as "in", default 0.5
%     'WindowFillRatio' min fraction of "in" frames inside the window,
%                       default 0.5
%
%   Output:
%     startFrame - 1-based frame index.
%     info       - struct with fields:
%                    .firstPopulatedFrame  first frame ever populated
%                    .totalPopulatedRatio  overall populated ratio
%                    .windowFrames         window size used
%                    .threshold            WindowFillRatio used
%                    .message              non-empty when fell back to 1

    p = inputParser;
    addRequired(p, 'dlc', @(s) isstruct(s) && isfield(s, 'X') && isfield(s, 'Y'));
    addParameter(p, 'WindowFrames', 30, @(v) isnumeric(v) && v >= 1);
    addParameter(p, 'PopulationRatio', 0.5, @(v) isnumeric(v) && v >= 0 && v <= 1);
    addParameter(p, 'WindowFillRatio', 0.5, @(v) isnumeric(v) && v >= 0 && v <= 1);
    parse(p, dlc, varargin{:});

    X = dlc.X;
    Y = dlc.Y;
    [nParts, nFrames] = size(X);

    info = struct('firstPopulatedFrame', NaN, 'totalPopulatedRatio', 0, ...
        'windowFrames', p.Results.WindowFrames, ...
        'threshold', p.Results.WindowFillRatio, 'message', '');

    if nFrames == 0
        startFrame = 1;
        info.message = 'No frames in DLC trace';
        return;
    end

    populatedPerPart = ~isnan(X) & ~isnan(Y) & X >= 0 & Y >= 0;
    perFrameScore = sum(populatedPerPart, 1) / nParts;
    frameIsIn = perFrameScore >= p.Results.PopulationRatio;

    firstHit = find(frameIsIn, 1, 'first');
    if isempty(firstHit)
        startFrame = 1;
        info.message = 'Animal never reaches PopulationRatio in any frame';
        return;
    end
    info.firstPopulatedFrame = firstHit;
    info.totalPopulatedRatio = sum(frameIsIn) / nFrames;

    W = round(p.Results.WindowFrames);
    threshold = p.Results.WindowFillRatio;

    % Rolling mean of frameIsIn over a forward window of W frames.
    % movmean with [0 W-1] is "centered to the right" -> window starts
    % at the current frame.
    rolling = movmean(double(frameIsIn), [0 W - 1], 'Endpoints', 'shrink');

    candidate = find(rolling >= threshold, 1, 'first');
    if isempty(candidate)
        startFrame = 1;
        info.message = sprintf( ...
            'No %d-frame window reaches fill ratio %.2f (peak rolling = %.2f)', ...
            W, threshold, max(rolling));
        return;
    end
    % Snap candidate to the first actually-populated frame at or after
    % it -- avoid starting on a NaN gap if rolling crossed the threshold
    % while the current frame happened to be NaN.
    snap = find(frameIsIn(candidate:end), 1, 'first');
    if isempty(snap)
        startFrame = candidate;
    else
        startFrame = candidate + snap - 1;
    end
end
