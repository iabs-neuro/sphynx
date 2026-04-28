function out = cleanBodyPart(rawX, rawY, likelihood, varargin)
% CLEANBODYPART  Clean a raw DLC trace: NaN/clip/likelihood-mask.
%
%   out = sphynx.preprocess.cleanBodyPart(rawX, rawY, likelihood, ...)
%
%   Inputs:
%     rawX, rawY  - Nx1 raw position (pixels)
%     likelihood  - Nx1 DLC confidence in [0, 1]
%
%   Name-value parameters:
%     'FrameWidth'           default Inf
%     'FrameHeight'          default Inf
%     'LikelihoodThreshold'  default 0.95 — frames below get NaN
%     'MissingThresholdPct'  default 90  — if more than this percent
%                            of frames are bad, status is 'NotFound'
%
%   Output struct:
%     X, Y                       Nx1 cleaned traces (NaN where bad)
%     PercentNaN                 percent of frames originally NaN
%     PercentLowLikelihood       percent below threshold
%     PercentBadCombined         percent flagged as bad in output
%     Status                     'Good' | 'NotFound'
%
%   "Bad" means: NaN in raw, likelihood < threshold, or out of frame
%   bounds. Bad frames are set to NaN in the output (so the next
%   stage — interpolateGaps — can fill them).
%
%   Decomposition of legacy BehaviorAnalyzer.m:163-200.

    % TODO(polish): expose all magic numbers (FrameWidth/FrameHeight
    %   defaults, MissingThresholdPct=90) to a single config-driven place.

    p = inputParser;
    addRequired(p, 'rawX');
    addRequired(p, 'rawY');
    addRequired(p, 'likelihood');
    addParameter(p, 'FrameWidth', Inf, @(v) isnumeric(v) && v > 0);
    addParameter(p, 'FrameHeight', Inf, @(v) isnumeric(v) && v > 0);
    addParameter(p, 'LikelihoodThreshold', 0.95, @(v) isnumeric(v) && v >= 0 && v <= 1);
    addParameter(p, 'MissingThresholdPct', 90, @(v) isnumeric(v) && v >= 0 && v <= 100);
    parse(p, rawX, rawY, likelihood, varargin{:});

    rawX = rawX(:); rawY = rawY(:); likelihood = likelihood(:);
    n = numel(rawX);

    isNaNRaw = isnan(rawX) | isnan(rawY);
    lowLikelihood = likelihood < p.Results.LikelihoodThreshold;
    outOfBounds = rawX < 0 | rawY < 0 | ...
                  rawX > p.Results.FrameWidth | rawY > p.Results.FrameHeight;

    bad = isNaNRaw | lowLikelihood | outOfBounds;

    X = rawX; Y = rawY;
    X(bad) = NaN;
    Y(bad) = NaN;

    out.X = X;
    out.Y = Y;
    out.PercentNaN = round(100 * sum(isNaNRaw) / n, 2);
    out.PercentLowLikelihood = round(100 * sum(lowLikelihood) / n, 2);
    out.PercentBadCombined = round(100 * sum(bad) / n, 2);
    if out.PercentBadCombined > p.Results.MissingThresholdPct
        out.Status = 'NotFound';
    else
        out.Status = 'Good';
    end
end
