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
    maxDist = max(distFromOutside(:)); % effective arena "radius"

    zones = struct('name',{},'type',{},'maskfilled',{});

    % Wall always exists (outermost ring)
    wallRing = paddedMask & distFromOutside > 0 & distFromOutside <= wallW;
    if any(wallRing(:))
        zones(end+1) = mkZone('wall', wallRing, pad); %#ok<AGROW>
    end

    % If no room for center past wall, stop here.
    if maxDist < wallW + minC
        return;
    end

    % Greedy: add middle rings while another middle would still leave
    % at least minC for the center disk.
    cumW = wallW;
    middleIdx = 1;
    while cumW + midW + minC <= maxDist
        nextCumW = cumW + midW;
        ring = paddedMask & distFromOutside > cumW & distFromOutside <= nextCumW;
        if any(ring(:))
            zones(end+1) = mkZone(sprintf('middle%d', middleIdx), ring, pad); %#ok<AGROW>
        end
        cumW = nextCumW;
        middleIdx = middleIdx + 1;
        if middleIdx > 50
            error('sphynx:classifyCircle:tooManyRings', ...
                'Computed > 50 middle rings; check input parameters');
        end
    end

    % Center: everything inside the last middle (or wall, if no middles).
    centerMask = paddedMask & distFromOutside > cumW;
    if any(centerMask(:))
        zones(end+1) = mkZone('center', centerMask, pad); %#ok<AGROW>
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
