function Zones = buildZonesCircleWall(arenaMask, varargin)
% BUILDZONESCIRCLEWALL  Two-zone partition: wall ring + center (everything else).
%
%   Zones = sphynx.preset.buildZonesCircleWall(arenaMask, ...)
%
%   Required name-value: 'PixelsPerCm', 'WallWidthCm'.
%
%   Returns 2 zones: 'wall' (ring of WallWidthCm from arena edge) and
%   'center' (arena minus wall). Works on any arena shape (Circle,
%   Ellipse, O-maze, Polygon) -- uses bwdist on the mask.

    p = inputParser;
    addRequired(p, 'arenaMask', @(m) islogical(m) || isnumeric(m));
    addParameter(p, 'PixelsPerCm', [], @(v) isnumeric(v) && v > 0);
    addParameter(p, 'WallWidthCm', 0, @(v) isnumeric(v) && v >= 0);
    parse(p, arenaMask, varargin{:});
    pxlPerCm = p.Results.PixelsPerCm;
    if isempty(pxlPerCm)
        error('sphynx:buildZonesCircleWall:missingPixelsPerCm', ...
            'PixelsPerCm is required');
    end

    arenaMask = arenaMask > 0;
    wallWPx = p.Results.WallWidthCm * pxlPerCm;
    Zones = struct('name', {}, 'type', {}, 'maskfilled', {});

    if wallWPx > 0
        distOutside = bwdist(~arenaMask);
        wallMask   = arenaMask & distOutside > 0 & distOutside <= wallWPx;
        centerMask = arenaMask & ~wallMask;
        if any(wallMask(:))
            Zones(end+1).name = 'wall';
            Zones(end).type = 'area';
            Zones(end).maskfilled = wallMask;
        end
        if any(centerMask(:))
            Zones(end+1).name = 'center';
            Zones(end).type = 'area';
            Zones(end).maskfilled = centerMask;
        end
    else
        % WallWidthCm == 0 -> entire arena is center.
        if any(arenaMask(:))
            Zones(end+1).name = 'center';
            Zones(end).type = 'area';
            Zones(end).maskfilled = arenaMask;
        end
    end
end
