function out = interpolateGaps(trace, varargin)
% INTERPOLATEGAPS  Fill NaN gaps in a 1D trace by interpolation.
%
%   out = sphynx.preprocess.interpolateGaps(trace) fills NaN entries
%   in `trace` using the chosen method (default pchip). Returns NaN
%   if every sample is NaN.
%
%   Name-value parameters:
%     'Method'   default 'pchip' — passed to interp1 for interior gaps
%                ('linear', 'pchip', 'spline' all valid)
%     'EdgeMode' default 'hold' — how to fill leading/trailing NaNs.
%                'hold' = constant-fill with first/last valid sample
%                         (recommended; pchip 'extrap' overshoots wildly
%                         when DLC has not converged yet at session start
%                         and the per-frame clamp then scatters body
%                         parts across the arena).
%                'extrap' = legacy behavior, extrapolate via interp1.
%                'nan' = leave the NaNs in place.

    p = inputParser;
    addRequired(p, 'trace');
    addParameter(p, 'Method', 'pchip', @ischar);
    addParameter(p, 'EdgeMode', 'hold', ...
        @(s) any(strcmpi(s, {'hold', 'extrap', 'nan'})));
    parse(p, trace, varargin{:});

    trace = trace(:);
    n = numel(trace);
    good = ~isnan(trace);
    out = trace;

    if all(~good); return; end
    if all(good); return; end

    firstGood = find(good, 1, 'first');
    lastGood  = find(good, 1, 'last');

    % Leading / trailing NaNs.
    switch lower(p.Results.EdgeMode)
        case 'hold'
            if firstGood > 1
                out(1:firstGood-1) = trace(firstGood);
            end
            if lastGood < n
                out(lastGood+1:n) = trace(lastGood);
            end
        case 'extrap'
            idx = (1:n)';
            edgeMask = (idx < firstGood) | (idx > lastGood);
            out(edgeMask) = interp1(idx(good), trace(good), idx(edgeMask), ...
                p.Results.Method, 'extrap');
        case 'nan'
            % leave as NaN
    end

    % Interior gaps: interp1 with the chosen method between firstGood
    % and lastGood. No extrapolation here (it can't trigger inside a
    % range bracketed by good samples).
    if firstGood < lastGood
        interior = (firstGood:lastGood)';
        interiorGood = good(firstGood:lastGood);
        if any(~interiorGood)
            out(interior(~interiorGood)) = interp1( ...
                interior(interiorGood), trace(interior(interiorGood)), ...
                interior(~interiorGood), p.Results.Method);
        end
    end
end
