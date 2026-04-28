function stats = actStats(actMask, frameRate, varargin)
% ACTSTATS  Numeric statistics for a binary act trace.
%
%   stats = sphynx.acts.actStats(actMask, frameRate, ...)
%
%   Inputs:
%     actMask    - Nx1 logical (refined act trace)
%     frameRate  - Hz
%
%   Optional name-value:
%     'Velocity' - Nx1 cm/s, used to compute Distance and ActVelocity
%
%   Output struct fields (all numeric scalars):
%     ActNumber       - number of act episodes
%     ActPercent      - percent of frames inside the act (0..100, rounded to 2 decimals)
%     ActDuration     - total in seconds
%     ActMeanTime     - mean episode duration in seconds
%     ActMedianTime   - median episode duration in seconds
%     ActMeanSTDTime  - std of episode duration in seconds
%     ActMedianMADTime- mad (mean absolute deviation) of episode duration
%     Distance        - cm covered while acting (if Velocity given), 0 otherwise
%     ActMeanDistance - Distance / ActNumber (0 if no episodes)
%     ActVelocity     - mean velocity during act (cm/s)
%
%   Decomposition of legacy BehaviorAnalyzer.m:583-598.

    p = inputParser;
    addRequired(p, 'actMask');
    addRequired(p, 'frameRate', @(v) isnumeric(v) && v > 0);
    addParameter(p, 'Velocity', [], @(v) isempty(v) || isnumeric(v));
    parse(p, actMask, frameRate, varargin{:});

    actMask = logical(actMask(:));
    n = numel(actMask);

    [~, runs] = sphynx.acts.refineAct(actMask, 0, 0);
    durations = arrayfun(@(r) r.duration, runs);

    stats.ActNumber = numel(durations);
    stats.ActPercent = round(100 * sum(actMask) / max(n,1), 2);
    stats.ActDuration = round(sum(actMask) / frameRate, 2);
    if isempty(durations)
        stats.ActMeanTime = 0;
        stats.ActMedianTime = 0;
        stats.ActMeanSTDTime = 0;
        stats.ActMedianMADTime = 0;
    else
        stats.ActMeanTime = round(mean(durations), 2) / frameRate;
        stats.ActMedianTime = round(median(durations), 2) / frameRate;
        stats.ActMeanSTDTime = round(std(durations), 2) / frameRate;
        stats.ActMedianMADTime = round(mad(durations), 2) / frameRate;
    end

    velocity = p.Results.Velocity;
    if isempty(velocity)
        stats.Distance = 0;
        stats.ActVelocity = 0;
        stats.ActMeanDistance = 0;
    else
        velocity = velocity(:);
        if any(actMask)
            meanV = mean(velocity(actMask));
            timeAct = stats.ActDuration;  % seconds
            stats.Distance = round(meanV * timeAct / 100, 2);  % cm? No — meanV in cm/s, time in s -> cm. /100 from legacy
            % Note: legacy computes Distance via percent and time, leading
            % to /100. We mirror the legacy formula for golden compatibility.
            stats.Distance = round(meanV * timeAct * stats.ActPercent / 10000, 2);
            if stats.ActNumber > 0
                stats.ActMeanDistance = stats.Distance / stats.ActNumber;
            else
                stats.ActMeanDistance = 0;
            end
            if stats.ActMeanTime > 0 && stats.ActNumber > 0
                stats.ActVelocity = stats.Distance / (stats.ActMeanTime * stats.ActNumber) * 100;
            else
                stats.ActVelocity = 0;
            end
        else
            stats.Distance = 0;
            stats.ActMeanDistance = 0;
            stats.ActVelocity = 0;
        end
    end
end
