function stats = actStats(actMask, frameRate, varargin)
% ACTSTATS  Numeric statistics for a binary act trace.
%
%   stats = sphynx.acts.actStats(actMask, frameRate, ...)
%
%   Inputs:
%     actMask    - Nx1 logical / 0-1 (refined act trace)
%     frameRate  - Hz
%
%   Optional name-value:
%     'Velocity' - Nx1 cm/s. analyzeSession passes the bodycenter
%                  velocity for every act, so the velocity-derived
%                  metrics here are always "speed of the body center
%                  while the act is firing".
%
%   Output struct fields (numeric scalars):
%     ActNumber          number of separate episodes
%     ActPercent         % of frames inside the act (0..100)
%     ActDuration        total time in seconds
%     ActMeanTime        mean episode duration in seconds
%     ActMedianTime      median episode duration in seconds
%     ActMeanSTDTime     std of episode durations in seconds
%     ActMedianMADTime   mean abs deviation of episode durations in s
%     FirstStartSec      time (s) of the first episode start (NaN
%                        if no episodes). 0 means "the first frame".
%     FirstEndSec        time (s) of the first episode end
%     LastStartSec       time (s) of the last episode start
%     LastEndSec         time (s) of the last episode end
%     FirstDurationSec   length (s) of the first episode (NaN if none)
%     RestDurationSec    total time (s) of every episode AFTER the
%                        first one. Useful for Barnes "did the animal
%                        keep coming back to the target after the
%                        first visit?" questions. 0 if only one
%                        episode; NaN if no episodes.
%     Distance           cm covered while acting (= sum of per-frame
%                        velocity / frameRate). 0 if no Velocity given.
%     ActMeanDistance    Distance / ActNumber
%     ActMeanVelocity    mean velocity over active frames (cm/s)
%     ActMaxVelocity     max velocity over active frames (cm/s)
%     ActMinVelocity     min velocity over active frames (cm/s)
%     ActVelocity        legacy alias for ActMeanVelocity (kept for
%                        downstream code that still reads the old
%                        name).

    p = inputParser;
    addRequired(p, 'actMask');
    addRequired(p, 'frameRate', @(v) isnumeric(v) && v > 0);
    addParameter(p, 'Velocity', [], @(v) isempty(v) || isnumeric(v));
    parse(p, actMask, frameRate, varargin{:});

    actMask = logical(actMask(:));
    n = numel(actMask);

    [~, runs] = sphynx.acts.refineAct(actMask, 0, 0);
    durations = arrayfun(@(r) r.duration, runs);

    stats.ActNumber   = numel(durations);
    stats.ActPercent  = round(100 * sum(actMask) / max(n, 1), 2);
    stats.ActDuration = round(sum(actMask) / frameRate, 2);

    if isempty(durations)
        stats.ActMeanTime      = 0;
        stats.ActMedianTime    = 0;
        stats.ActMeanSTDTime   = 0;
        stats.ActMedianMADTime = 0;
    else
        durSec = durations(:) / frameRate;
        stats.ActMeanTime      = round(mean(durSec), 2);
        stats.ActMedianTime    = round(median(durSec), 2);
        stats.ActMeanSTDTime   = round(std(durSec), 2);
        stats.ActMedianMADTime = round(mad(durSec), 2);
    end

    % First / last episode boundaries — handy for Barnes-maze-style
    % metrics (latency, time-to-completion). 0-based start so frame 1
    % maps to t = 0.
    if isempty(runs)
        stats.FirstStartSec    = NaN;
        stats.FirstEndSec      = NaN;
        stats.LastStartSec     = NaN;
        stats.LastEndSec       = NaN;
        stats.FirstDurationSec = NaN;
        stats.RestDurationSec  = NaN;
    else
        stats.FirstStartSec = round((runs(1).frameIn   - 1) / frameRate, 2);
        stats.FirstEndSec   = round((runs(1).frameOut  - 1) / frameRate, 2);
        stats.LastStartSec  = round((runs(end).frameIn  - 1) / frameRate, 2);
        stats.LastEndSec    = round((runs(end).frameOut - 1) / frameRate, 2);
        % Episode durations are inclusive frame counts -- one frame
        % run = 1 frame = 1/fps seconds. The first-run duration is
        % its own; the rest is the total minus the first.
        firstDur = runs(1).duration / frameRate;
        stats.FirstDurationSec = round(firstDur, 2);
        stats.RestDurationSec  = round(max(0, stats.ActDuration - firstDur), 2);
    end

    % Velocity-derived metrics. analyzeSession passes the bodycenter
    % velocity here, so these are always relative to bodycenter — which
    % is what the GUI / etogram expect.
    velocity = p.Results.Velocity;
    if isempty(velocity) || ~any(actMask)
        stats.Distance        = 0;
        stats.ActMeanDistance = 0;
        stats.ActMeanVelocity = 0;
        stats.ActMaxVelocity  = 0;
        stats.ActMinVelocity  = 0;
        stats.ActVelocity     = 0;
        return;
    end
    velocity = velocity(:);
    vIn = velocity(actMask);
    stats.ActMeanVelocity = round(mean(vIn, 'omitnan'), 2);
    stats.ActMaxVelocity  = round(max(vIn,  [], 'omitnan'), 2);
    stats.ActMinVelocity  = round(min(vIn,  [], 'omitnan'), 2);
    % Distance = sum of per-frame displacements. v [cm/s] * (1/fps) [s]
    % per frame -> sum gives cm.
    stats.Distance = round(sum(vIn, 'omitnan') / frameRate, 2);
    if stats.ActNumber > 0
        stats.ActMeanDistance = round(stats.Distance / stats.ActNumber, 2);
    else
        stats.ActMeanDistance = 0;
    end
    % Legacy alias.
    stats.ActVelocity = stats.ActMeanVelocity;
end
