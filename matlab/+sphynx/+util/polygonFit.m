function [x, y, sidesX, sidesY] = polygonFit(xCorners, yCorners, varargin)
% POLYGONFIT  Build closed dense polygon outline + per-side traces.
%
%   [x, y, sidesX, sidesY] = sphynx.util.polygonFit(xCorners, yCorners)
%
%   Inputs:
%     xCorners, yCorners - vectors of corner coordinates (>=3 points)
%
%   Outputs:
%     x, y      - closed dense outline (concatenation of all sides)
%     sidesX{i} - dense x-coords for side i (corner i to corner i+1)
%     sidesY{i} - dense y-coords for side i
%
%   Optional name-value:
%     'PointsPerSide' - number of points per side (default 1000)
%
%   Replacement for legacy functions/PolygonFit.m.

    p = inputParser;
    addParameter(p, 'PointsPerSide', 1000, @(v) isnumeric(v) && v > 1);
    parse(p, varargin{:});
    nPerSide = p.Results.PointsPerSide;

    xCorners = xCorners(:); yCorners = yCorners(:);
    if numel(xCorners) ~= numel(yCorners)
        error('sphynx:polygonFit:sizeMismatch', ...
            'xCorners and yCorners must match in length');
    end
    if numel(xCorners) < 3
        error('sphynx:polygonFit:tooFewCorners', ...
            'Need at least 3 corners; got %d', numel(xCorners));
    end

    nSides = numel(xCorners);
    sidesX = cell(1, nSides);
    sidesY = cell(1, nSides);
    for i = 1:nSides
        i2 = mod(i, nSides) + 1; % wrap
        sidesX{i} = linspace(xCorners(i), xCorners(i2), nPerSide);
        sidesY{i} = linspace(yCorners(i), yCorners(i2), nPerSide);
    end

    x = [];
    y = [];
    for i = 1:nSides
        x = [x; sidesX{i}(:)]; %#ok<AGROW>
        y = [y; sidesY{i}(:)]; %#ok<AGROW>
    end
end
