function zones = classifyCircle(arenaMask, varargin)
% CLASSIFYCIRCLE  Ring-based zone classification for round arena.
%
%   zones = sphynx.zones.classifyCircle(arenaMask, ...) returns a
%   struct array of concentric ring zones inside arenaMask:
%     wall     - outermost ring of width WallWidthCm
%     middle1  - next ring inward of width MiddleWidthCm
%     middle2  - next ring inward of width MiddleWidthCm
%     ...
%     center   - innermost remaining disk, if >= MinCenterCm radius
%
%   Name-value parameters:
%     PixelsPerCm    (required) - calibration scale
%     WallWidthCm    (default 10)
%     MiddleWidthCm  (default 20)
%     MinCenterCm    (default 10) - minimum center radius to keep
%
%   Bug-1 fix: distance transform runs on a padded frame so arena
%   boundaries touching the original frame edge classify correctly.
%
%   Implements feature 1.3 (round arena ring partitioning).

    p = inputParser;
    addRequired(p, 'arenaMask', @(m) islogical(m) || isnumeric(m));
    addParameter(p, 'PixelsPerCm', [], @(v) isnumeric(v) && v > 0);
    addParameter(p, 'WallWidthCm', 10, @(v) isnumeric(v) && v >= 0);
    addParameter(p, 'MiddleWidthCm', 20, @(v) isnumeric(v) && v > 0);
    addParameter(p, 'MinCenterCm', 10, @(v) isnumeric(v) && v >= 0);
    parse(p, arenaMask, varargin{:});

    if isempty(p.Results.PixelsPerCm)
        error('sphynx:classifyCircle:missingPixelsPerCm', ...
            'PixelsPerCm is required');
    end

    pxlPerCm = p.Results.PixelsPerCm;
    wallW = p.Results.WallWidthCm * pxlPerCm;
    midW  = p.Results.MiddleWidthCm * pxlPerCm;
    minC  = p.Results.MinCenterCm * pxlPerCm;

    arenaMask = arenaMask > 0;

    % Padded distance transform handles arena touching frame edges
    pad = max(round(wallW + midW * 4 + minC + 10), 20);
    paddedMask = padarray(arenaMask, [pad pad], false, 'both');
    distFromOutside = bwdist(~paddedMask);

    zones = struct('name',{},'type',{},'maskfilled',{});

    cumW = wallW;
    wallRingPadded = paddedMask & distFromOutside > 0 & distFromOutside <= wallW;
    zones(end+1) = mkZone('wall', wallRingPadded, pad);

    ringIdx = 1;
    while true
        prevW = cumW;
        cumW = cumW + midW;
        ring = paddedMask & distFromOutside > prevW & distFromOutside <= cumW;
        remaining = paddedMask & distFromOutside > cumW;
        if any(remaining(:))
            remainingDist = bwdist(~remaining);
            maxRemainingRadius = max(remainingDist(:));
        else
            maxRemainingRadius = 0;
        end
        if maxRemainingRadius < minC
            if any(ring(:))
                zones(end+1) = mkZone(sprintf('middle%d', ringIdx), ring, pad); %#ok<AGROW>
            end
            if any(remaining(:))
                zones(end+1) = mkZone('center', remaining, pad); %#ok<AGROW>
            end
            break;
        else
            zones(end+1) = mkZone(sprintf('middle%d', ringIdx), ring, pad); %#ok<AGROW>
            ringIdx = ringIdx + 1;
        end
        if ringIdx > 50
            error('sphynx:classifyCircle:tooManyRings', ...
                'Computed > 50 middle rings; check input parameters');
        end
    end
end

function zone = mkZone(name, paddedMask, pad)
    [Hp, Wp] = size(paddedMask);
    H = Hp - 2*pad;
    W = Wp - 2*pad;
    zone.name = name;
    zone.type = 'area';
    zone.maskfilled = paddedMask(pad+1 : pad+H, pad+1 : pad+W);
end
