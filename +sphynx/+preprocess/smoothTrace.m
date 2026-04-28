function out = smoothTrace(trace, windowLen, varargin)
% SMOOTHTRACE  Edge-aware Savitzky-Golay smoothing.
%
%   out = sphynx.preprocess.smoothTrace(trace, windowLen) smooths the
%   input with a Savitzky-Golay filter of length windowLen and
%   polynomial order min(3, windowLen-1).
%
%   Bug-3 fix: input is anti-symmetrically mirror-padded by
%   (windowLen-1)/2 samples on each side before smoothing, then the
%   padding is stripped. This preserves linear trends across the
%   trace edges, fixing the inflated edge values produced by plain
%   sgolayfilt / smooth(...,'sgolay',...) at the start/end of a trace.
%
%   Optional name-value:
%     'PolyOrder' - default 3, capped at windowLen-1
%
%   Edge cases:
%     - If trace is shorter than windowLen, returns trace unchanged.
%     - windowLen must be odd and >= 3.
%
%   Implementation note: uses sgolayfilt (Signal Processing Toolbox)
%   instead of smooth (Curve Fitting Toolbox) for portability.

    p = inputParser;
    addRequired(p, 'trace', @(v) isnumeric(v));
    addRequired(p, 'windowLen', @(v) isnumeric(v));
    addParameter(p, 'PolyOrder', 3, @(v) isnumeric(v) && v >= 1);
    parse(p, trace, windowLen, varargin{:});

    if mod(windowLen, 2) == 0
        error('sphynx:smoothTrace:windowEven', ...
            'windowLen must be odd; got %d', windowLen);
    end
    if windowLen < 3
        error('sphynx:smoothTrace:windowTooSmall', ...
            'windowLen must be >= 3; got %d', windowLen);
    end

    trace = trace(:);
    n = numel(trace);
    if n < windowLen
        out = trace;
        return;
    end

    polyOrder = min(p.Results.PolyOrder, windowLen - 1);
    halfPad = (windowLen - 1) / 2;

    % Anti-symmetric mirror-padding: reflect around the endpoint value
    % so that linear trends are preserved across the boundary.
    padFront = 2*trace(1)   - trace(halfPad+1 : -1 : 2);
    padBack  = 2*trace(end) - trace(end-1 : -1 : end-halfPad);
    padded = [padFront; trace; padBack];

    smoothed = sgolayfilt(padded, polyOrder, windowLen);

    out = smoothed(halfPad+1 : halfPad+n);
end
