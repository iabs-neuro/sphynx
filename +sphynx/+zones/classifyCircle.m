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
%   Behavior (updated 2026-06-03):
%     - Wall is always returned (no early return).
%     - Middles are added greedily while there is room for another full
%       ring of width MiddleWidthCm; epsilon-relaxed comparison tolerates
%       float rasterization slop at exact wall+mid+minC == radius.
%     - Center is always added if any pixels remain past the last middle
%       (even when narrower than MinCenterCm -- Barnes-style narrow arenas).
%
%   Bug-1 fix (preserved): distance transform runs on a padded frame so
%   arenas touching the original frame edge classify correctly.
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

    % Wall always exists (outermost ring). No early return -- we always
    % try to produce wall + (optional middles) + center.
    wallRing = paddedMask & distFromOutside > 0 & distFromOutside <= wallW;
    if any(wallRing(:))
        zones(end+1) = mkZone('wall', wallRing, pad); %#ok<AGROW>
    end

    % Greedy middles: add a ring whenever there is at least midW worth
    % of space past the current cumulative width. Relaxed boundary
    % (epsilon = 0.5 px) tolerates rasterization slop on exact
    % wall+mid+minC == radius arenas.
    eps = 0.5;
    cumW = wallW;
    middleIdx = 1;
    while cumW + midW <= maxDist + eps
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

    % Center: everything past the last middle (or past wall if no middles).
    % Added unconditionally if any pixels remain -- even if narrower than
    % MinCenterCm. MinCenterCm now controls greedy-middle stopping (above)
    % rather than dropping the center entirely.
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
