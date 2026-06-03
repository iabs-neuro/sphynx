function Zones = buildZonesCircleCenter(arenaMask, varargin)
% BUILDZONESCIRCLECENTER  Two-zone partition: center disc + wall annulus.
%
%   Zones = sphynx.preset.buildZonesCircleCenter(arenaMask, ...)
%
%   Required name-value: 'PixelsPerCm', 'CenterDiameterCm'.
%
%   Returns 2-element struct array with fields name/type/maskfilled.
%   `center` is a concentric disc of the requested diameter, clipped to
%   the arena mask. `wall` is the arena minus the center.

    p = inputParser;
    addRequired(p, 'arenaMask', @(m) islogical(m) || isnumeric(m));
    addParameter(p, 'PixelsPerCm', [], @(v) isnumeric(v) && v > 0);
    addParameter(p, 'CenterDiameterCm', 20, @(v) isnumeric(v) && v > 0);
    parse(p, arenaMask, varargin{:});
    pxlPerCm = p.Results.PixelsPerCm;
    if isempty(pxlPerCm)
        error('sphynx:buildZonesCircleCenter:missingPixelsPerCm', ...
            'PixelsPerCm is required');
    end
    arenaMask = arenaMask > 0;
    [H, W] = size(arenaMask);
    [yIdx, xIdx] = find(arenaMask);
    cx = mean(xIdx);
    cy = mean(yIdx);
    r = (p.Results.CenterDiameterCm / 2) * pxlPerCm;
    [X, Y] = meshgrid(1:W, 1:H);
    centerMask = ((X - cx).^2 + (Y - cy).^2) <= r^2 & arenaMask;
    wallMask = arenaMask & ~centerMask;
    Zones = struct('name', {}, 'type', {}, 'maskfilled', {});
    if any(wallMask(:))
        Zones(end + 1).name = 'wall';
        Zones(end).type = 'area';
        Zones(end).maskfilled = wallMask;
    end
    if any(centerMask(:))
        Zones(end + 1).name = 'center';
        Zones(end).type = 'area';
        Zones(end).maskfilled = centerMask;
    end
end
