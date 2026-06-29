function out = unwrapForSmooth(angles, windowLen, varargin)
% UNWRAPFORSMOOTH  Smooth a circular angle signal correctly.
%
%   out = sphynx.angles.unwrapForSmooth(angles, windowLen) unwraps
%   the input, applies a Savitzky-Golay smoother of length windowLen,
%   and wraps the result back into (-pi, pi].
%
%   Optional name-value:
%     'PolyOrder' - sgolay polynomial order (default 3, capped at windowLen-1)
%
%   This is the Bug-2 fix for HeadDirection and BodyDirection traces:
%   smoothing the wrapped (-pi, pi] signal directly produces severe
%   artifacts at the +-pi discontinuity.

    p = inputParser;
    addRequired(p, 'angles');
    addRequired(p, 'windowLen', @(v) isnumeric(v) && v >= 3 && mod(v,2)==1);
    addParameter(p, 'PolyOrder', 3, @(v) isnumeric(v) && v >= 1);
    parse(p, angles, windowLen, varargin{:});

    polyOrder = min(p.Results.PolyOrder, windowLen - 1);

    angles = angles(:);
    unwrapped = unwrap(angles);
    if numel(unwrapped) < windowLen
        smoothed = unwrapped;
    else
        if hasSgolayfilt()
            smoothed = sgolayfilt(unwrapped, polyOrder, windowLen);
        else
            % Signal Processing Toolbox not installed -- fall back to
            % a moving-average via smoothdata (base MATLAB). Matches
            % the fallback in sphynx.preprocess.smoothTrace.
            warnNoSgolayOnce();
            smoothed = smoothdata(unwrapped, 'movmean', windowLen, 'omitnan');
        end
    end
    out = sphynx.angles.wrap(smoothed);
end

function tf = hasSgolayfilt()
    persistent cached
    if isempty(cached)
        cached = exist('sgolayfilt', 'file') == 2;
    end
    tf = cached;
end

function warnNoSgolayOnce()
    persistent warned
    if isempty(warned)
        warning('sphynx:unwrapForSmooth:noSgolayfilt', ...
            ['sgolayfilt not found (Signal Processing Toolbox not ' ...
             'installed). Angle smoothing falls back to moving-average.']);
        warned = true;
    end
end
