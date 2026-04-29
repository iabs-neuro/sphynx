function zones = classifySquare(arenaMask, varargin)
% CLASSIFYSQUARE  Zone classification for square/polygon arena.
%
%   zones = sphynx.zones.classifySquare(arenaMask, ...) returns a
%   struct array of zone masks for a polygon arena, depending on the
%   chosen Strategy.
%
%   Name-value parameters:
%     'Strategy'        (default 'corners-walls-center')
%                       'corners-walls-center' | 'strips' | 'none'
%     'PixelsPerCm'     scale factor (required for corners-walls-center)
%     'WallWidthCm'     default 3
%     'CornerPoints'    Nx2 [x y] corner positions (required for corners-walls-center)
%     'NumStrips'       integer, for 'strips' strategy
%     'StripDirection'  'horizontal' | 'vertical', for 'strips'
%
%   Bug-1 fix: distance transforms run on a padded frame so arena
%   boundaries touching the original frame edge classify correctly.
%
%   See also: sphynx.zones.partitionStrips, sphynx.zones.classifyCircle

    p = inputParser;
    addRequired(p, 'arenaMask');
    addParameter(p, 'Strategy', 'corners-walls-center', @ischar);
    addParameter(p, 'PixelsPerCm', [], @(v) isempty(v) || (isnumeric(v) && v > 0));
    addParameter(p, 'WallWidthCm', 3, @(v) isnumeric(v) && v >= 0);
    addParameter(p, 'CornerPoints', [], @(v) isempty(v) || (size(v,2) == 2));
    addParameter(p, 'NumStrips', 3, @(v) isnumeric(v) && v >= 1);
    addParameter(p, 'StripDirection', 'horizontal', @ischar);
    parse(p, arenaMask, varargin{:});

    arenaMask = arenaMask > 0;

    switch p.Results.Strategy
        case 'corners-walls-center'
            zones = cornersWallsCenter(arenaMask, p.Results);
        case 'strips'
            zones = sphynx.zones.partitionStrips(arenaMask, p.Results.NumStrips, p.Results.StripDirection);
        case 'none'
            zones = struct('name','arena','type','area','maskfilled',arenaMask);
        otherwise
            error('sphynx:classifySquare:unknownStrategy', ...
                'Strategy must be corners-walls-center|strips|none; got "%s"', ...
                p.Results.Strategy);
    end
end

function zones = cornersWallsCenter(arenaMask, opts)
    if isempty(opts.PixelsPerCm)
        error('sphynx:classifySquare:missingPixelsPerCm', ...
            'PixelsPerCm is required for corners-walls-center strategy');
    end
    if isempty(opts.CornerPoints)
        error('sphynx:classifySquare:missingCornerPoints', ...
            'CornerPoints is required for corners-walls-center strategy');
    end

    pxlPerCm = opts.PixelsPerCm;
    wallW = opts.WallWidthCm * pxlPerCm;
    cornerW = wallW * sqrt(2);

    [H, W] = size(arenaMask);

    % Bug-1 fix: pad the frame so distance transform doesn't see frame edge
    % as "outside arena" when arena actually extends to the edge.
    pad = max(round(wallW + cornerW + 10), 20);
    paddedMask = padarray(arenaMask, [pad pad], false, 'both');

    distFromOutside = bwdist(~paddedMask);

    % Center: pixels deeper than wallW from the boundary
    centerPadded = paddedMask & distFromOutside > wallW;

    % Walls and corners region: arena minus center
    wallsAndCornersPadded = paddedMask & ~centerPadded;

    % Corners: pixels within cornerW of any corner POINT
    cornersPadded = false(size(paddedMask));
    if ~isempty(opts.CornerPoints)
        for i = 1:size(opts.CornerPoints, 1)
            cx = round(opts.CornerPoints(i,1)) + pad;
            cy = round(opts.CornerPoints(i,2)) + pad;
            if cx < 1 || cx > size(paddedMask,2) || cy < 1 || cy > size(paddedMask,1)
                continue;
            end
            seed = false(size(paddedMask));
            seed(cy, cx) = true;
            distFromCorner = bwdist(seed);
            cornerNeighborhood = distFromCorner <= cornerW;
            cornersPadded = cornersPadded | (wallsAndCornersPadded & cornerNeighborhood);
        end
    end

    wallsPadded = wallsAndCornersPadded & ~cornersPadded;

    zones = struct('name',{},'type',{},'maskfilled',{});
    zones(1) = mkZone('corners',           cornersPadded,         pad);
    zones(2) = mkZone('walls',             wallsPadded,           pad);
    zones(3) = mkZone('walls_and_corners', wallsAndCornersPadded, pad);
    zones(4) = mkZone('center',            centerPadded,          pad);
end

function zone = mkZone(name, paddedMask, pad)
    [Hp, Wp] = size(paddedMask);
    H = Hp - 2*pad;
    W = Wp - 2*pad;
    zone.name = name;
    zone.type = 'area';
    zone.maskfilled = paddedMask(pad+1 : pad+H, pad+1 : pad+W);
end
