function v = computeVelocity(x, y, frameRate, pxlPerCm, varargin)
% COMPUTEVELOCITY  Velocity from position trace, clipped + smoothed.
%
%   v = sphynx.preprocess.computeVelocity(x, y, frameRate, pxlPerCm, ...)
%
%   Inputs:
%     x, y        - Nx1 position traces (pixels)
%     frameRate   - Hz
%     pxlPerCm    - calibration scale (must be positive)
%
%   Name-value:
%     'MaxVelocityCmS' - biological clipping cap (default 50)
%     'SmoothWindow'   - sgolay window length (default 11, must be odd)
%
%   Output:
%     v - Nx1 velocity in cm/s
%
%   Bug-4 fix: per-frame velocity > MaxVelocityCmS is replaced with
%   NaN, then linearly interpolated, then smoothed. This prevents
%   single-frame DLC outliers from leaking through to the smoothed
%   trace.
%
%   Bug-3 partial fix: smoothing is delegated to sphynx.preprocess.smoothTrace
%   which handles edges with anti-symmetric mirror-padding.

    p = inputParser;
    addRequired(p, 'x');
    addRequired(p, 'y');
    addRequired(p, 'frameRate', @(v) isnumeric(v) && v > 0);
    addRequired(p, 'pxlPerCm', @(v) validateattributes(v, {'numeric'}, {'positive'}));
    addParameter(p, 'MaxVelocityCmS', 50, @(v) isnumeric(v) && v > 0);
    addParameter(p, 'SmoothWindow', 11, @(v) isnumeric(v) && v >= 3 && mod(v,2)==1);
    parse(p, x, y, frameRate, pxlPerCm, varargin{:});

    x = x(:); y = y(:);
    n = numel(x);

    dx = [0; diff(x)];
    dy = [0; diff(y)];

    rawV = sqrt(dx.^2 + dy.^2) * frameRate / pxlPerCm;  % cm/s per frame

    % Clip outliers
    bad = rawV > p.Results.MaxVelocityCmS;
    cleanedV = rawV;
    cleanedV(bad) = NaN;

    % Linear interpolate over NaN gaps
    if any(isnan(cleanedV))
        good = ~isnan(cleanedV);
        if any(good)
            idx = (1:n)';
            cleanedV(~good) = interp1(idx(good), cleanedV(good), idx(~good), 'linear', 'extrap');
        else
            cleanedV(:) = 0;
        end
    end

    % Cap any extrapolated outliers (paranoia)
    cleanedV(cleanedV > p.Results.MaxVelocityCmS) = p.Results.MaxVelocityCmS;
    cleanedV(cleanedV < 0) = 0;

    % Smooth with edge-aware sgolayfilt via smoothTrace
    v = sphynx.preprocess.smoothTrace(cleanedV, p.Results.SmoothWindow);

    % Final cap (smoothing can over- or under-shoot slightly)
    v(v > p.Results.MaxVelocityCmS) = p.Results.MaxVelocityCmS;
    v(v < 0) = 0;
end
