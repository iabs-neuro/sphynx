function out = interpolateGaps(trace, varargin)
% INTERPOLATEGAPS  Fill NaN gaps in a 1D trace by interpolation.
%
%   out = sphynx.preprocess.interpolateGaps(trace) fills NaN entries
%   in `trace` using the chosen method (default pchip). Returns NaN
%   if every sample is NaN.
%
%   Name-value parameters:
%     'Method'   default 'pchip' — passed to interp1
%                ('linear', 'pchip', 'spline' all valid)
%     'Extrap'   default 'extrap' — extrapolate beyond first/last good
%                sample. Set to NaN to disable extrapolation.
%
%   Decomposition of legacy BehaviorAnalyzer.m:202-214 (the pchip
%   interpolation block).

    % TODO(polish): user wants pluggable interpolation methods. Currently
    %   wired through the 'Method' name-value; promote to top-level config
    %   when integrating into analyzeSession.

    p = inputParser;
    addRequired(p, 'trace');
    addParameter(p, 'Method', 'pchip', @ischar);
    addParameter(p, 'Extrap', 'extrap');
    parse(p, trace, varargin{:});

    trace = trace(:);
    n = numel(trace);
    good = ~isnan(trace);
    out = trace;

    if all(~good)
        return;
    end
    if all(good)
        return;
    end

    idx = (1:n)';
    out(~good) = interp1(idx(good), trace(good), idx(~good), ...
                          p.Results.Method, p.Results.Extrap);
end
