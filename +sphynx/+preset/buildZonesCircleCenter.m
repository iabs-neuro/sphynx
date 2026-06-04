function Zones = buildZonesCircleCenter(arenaMask, varargin)
% BUILDZONESCIRCLECENTER  Two- or three-zone partition: center disc + optional wall ring.
%
%   Zones = sphynx.preset.buildZonesCircleCenter(arenaMask, ...)
%
%   Required name-value: 'PixelsPerCm', 'CenterDiameterCm'.
%   Optional name-value: 'WallWidthCm' (default 0 = back-compat 2-zone).
%
%   WallWidthCm == 0: returns 2 zones {wall, center} (back-compat).
%   WallWidthCm  > 0: returns 3 zones {wall, middle, center}.
%     wall   = pixels within WallWidthCm of the arena edge (bwdist)
%     middle = remaining arena pixels (not wall, not center)
%     center = concentric disc of CenterDiameterCm

    p = inputParser;
    addRequired(p, 'arenaMask', @(m) islogical(m) || isnumeric(m));
    addParameter(p, 'PixelsPerCm', [], @(v) isnumeric(v) && v > 0);
    addParameter(p, 'CenterDiameterCm', 20, @(v) isnumeric(v) && v > 0);
    addParameter(p, 'WallWidthCm', 0, @(v) isnumeric(v) && v >= 0);
    parse(p, arenaMask, varargin{:});
    pxlPerCm = p.Results.PixelsPerCm;
    if isempty(pxlPerCm)
        error('sphynx:buildZonesCircleCenter:missingPixelsPerCm', ...
            'PixelsPerCm is required');
    end
    arenaMask = arenaMask > 0;
    wallWPx = p.Results.WallWidthCm * pxlPerCm;
    [H, W] = size(arenaMask);
    [yIdx, xIdx] = find(arenaMask);
    cx = mean(xIdx);
    cy = mean(yIdx);
    r = (p.Results.CenterDiameterCm / 2) * pxlPerCm;
    [X, Y] = meshgrid(1:W, 1:H);
    centerMask = ((X - cx).^2 + (Y - cy).^2) <= r^2 & arenaMask;

    Zones = struct('name', {}, 'type', {}, 'maskfilled', {});

    if wallWPx > 0
        % 3-zone partition: wall ring + middle + center
        distOutside = bwdist(~arenaMask);
        wallMask = arenaMask & distOutside > 0 & distOutside <= wallWPx;
        middleMask = arenaMask & ~wallMask & ~centerMask;
        if any(wallMask(:))
            Zones(end + 1).name = 'wall';
            Zones(end).type = 'area';
            Zones(end).maskfilled = wallMask;
        end
        if any(middleMask(:))
            Zones(end + 1).name = 'middle';
            Zones(end).type = 'area';
            Zones(end).maskfilled = middleMask;
        end
    else
        % 2-zone partition (back-compat): outer area called 'wall' + center
        outerMask = arenaMask & ~centerMask;
        if any(outerMask(:))
            Zones(end + 1).name = 'wall';
            Zones(end).type = 'area';
            Zones(end).maskfilled = outerMask;
        end
    end

    if any(centerMask(:))
        Zones(end + 1).name = 'center';
        Zones(end).type = 'area';
        Zones(end).maskfilled = centerMask;
    end
end
