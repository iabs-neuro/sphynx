function out = smoothDerived(trace, windowLen)
% SMOOTHDERIVED  NaN-safe noise reduction for DERIVED signals.
%
%   out = sphynx.util.smoothDerived(trace, windowLen)
%
%   Used by act / posture / velocity code to denoise a value that
%   was COMPUTED from already-smoothed body-part traces
%   (sumDist, velocity, ...). Not for raw position data -- that goes
%   through applyPerPartSettings with the user's chosen
%   smoothing method.
%
%   Why a separate helper:
%     - the user's smoothingMethod (sgolay / movmean / gaussian /
%       kalman) is selected per body part for POSITION smoothing.
%       Derived signals get a fixed generic moving-average so
%       downstream act metrics stay deterministic regardless of
%       the user's per-part preference.
%     - moving average is implemented via smoothdata (base MATLAB,
%       no Signal Processing or Curve Fitting toolbox required) and
%       does not blow up on single/int input or NaN runs the way
%       sgolayfilt does on some MATLAB releases.
%
%   Behaviour:
%     - cast to double (sgolayfilt-like fragility avoided)
%     - any leading/trailing NaN passes through; interior NaN is
%       handled by smoothdata's 'omitnan'
%     - windowLen <= 1 -> passthrough

    if isempty(trace); out = trace; return; end
    trace = double(trace(:));
    if nargin < 2 || isempty(windowLen) || windowLen <= 1
        out = trace; return;
    end
    out = smoothdata(trace, 'movmean', round(windowLen), 'omitnan');
end
