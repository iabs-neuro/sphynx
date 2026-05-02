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
    addParameter(p, 'ArenaVertices', []);   % when set, strips align to arena sides
    addParameter(p, 'CornerType', 'round', ...
        @(s) any(strcmpi(s, {'round', 'square'})));
    parse(p, arenaMask, varargin{:});

    arenaMask = arenaMask > 0;

    switch p.Results.Strategy
        case 'corners-walls-center'
            zones = cornersWallsCenter(arenaMask, p.Results);
        case 'strips'
            % First split the arena into N equal strips. Then each
            % "_realout" strip is the same partition extended outward
            % by wallW only WITHIN the slab — i.e. each inner strip
            % grows toward the outside edge it touches, never overlapping
            % the inflation ring of another strip. This way the union of
            % strip{i} + strip{i}_realout equals the local part of the
            % outside-wall ring, not a duplicate global partition (round-4
            % bug fix).
            zones = sphynx.zones.partitionStrips(arenaMask, p.Results.NumStrips, ...
                p.Results.StripDirection, 'ArenaVertices', p.Results.ArenaVertices);
            if ~isempty(p.Results.PixelsPerCm)
                wallW = p.Results.WallWidthCm * p.Results.PixelsPerCm;
                bwd = bwdist(arenaMask);
                outsideRing = bwd > 0 & bwd <= wallW;
                stripsRealOut = struct('name', {}, 'type', {}, 'maskfilled', {});
                for k = 1:numel(zones)
                    inner = zones(k).maskfilled;
                    % For each outside-ring pixel: assign to the strip
                    % whose pixels are nearest. Use bwdist of the strip
                    % itself; pick the strip with minimum distance.
                    % Computed lazily via watershed-style nearest-strip
                    % map below.
                    stripsRealOut(k).name = sprintf('%s_realout', zones(k).name); %#ok<AGROW>
                    stripsRealOut(k).type = 'area';
                    stripsRealOut(k).maskfilled = inner;   % seed with inner
                end
                if any(outsideRing(:))
                    nearestStrip = nearestStripMap(zones, outsideRing);
                    for k = 1:numel(zones)
                        own = (nearestStrip == k);
                        stripsRealOut(k).maskfilled = stripsRealOut(k).maskfilled | own;
                    end
                end
                zones = [zones, stripsRealOut];
            end
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
    isSquareCorner = strcmpi(opts.CornerType, 'square');
    cornerW = wallW * sqrt(2);  % only used by round/Manhattan path

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

    % Corners: round = bwdist disk; square = parallelogram from corner along
    % the two adjacent walls, length wallW each side.
    cornersPadded = false(size(paddedMask));
    if ~isempty(opts.CornerPoints)
        if isSquareCorner
            % Build a parallelogram per vertex from the two adjacent edges.
            cornersPadded = squareCornerMask(paddedMask, opts.CornerPoints, ...
                wallW, pad, 'inner');
            % Restrict to wall band (interior of wallW)
            cornersPadded = cornersPadded & wallsAndCornersPadded;
        else
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
    end

    wallsPadded = wallsAndCornersPadded & ~cornersPadded;

    % "RealOut" zones: extend arena boundary outward by wallW so tracking
    % jitter just outside the polygon still counts as "in walls/corners".
    bwdistOutside = bwdist(paddedMask);
    outerRing = (bwdistOutside > 0) & (bwdistOutside <= wallW);
    arenaRealOutPadded = paddedMask | outerRing;
    wallsAndCornersRealOutPadded = arenaRealOutPadded & ~centerPadded;

    % Split the outer ring between corners and walls. Round mode = round
    % disk via bwdist from the corner point. Square mode = the same
    % parallelogram extended in the OPPOSITE direction (e1 -> -e1, e2 ->
    % -e2) so the outside corner is a continuation of the inside one
    % across the vertex (round-5 fix: previously outer used a circular
    % bwdist disk, breaking the visual continuity with the inner square).
    if ~isempty(opts.CornerPoints)
        if isSquareCorner
            % Square outer = two rectangles per vertex, each one a
            % continuation of an adjacent wall through the vertex
            % (length wallW past V, width wallW outward).
            outerNearCorners = squareCornerOuterStripsMask(paddedMask, ...
                opts.CornerPoints, wallW, pad);
            outerNearCorners = outerNearCorners & outerRing;
        else
            cornerSeed = false(size(paddedMask));
            for i = 1:size(opts.CornerPoints, 1)
                cx = round(opts.CornerPoints(i,1)) + pad;
                cy = round(opts.CornerPoints(i,2)) + pad;
                if cx >= 1 && cx <= size(paddedMask,2) && cy >= 1 && cy <= size(paddedMask,1)
                    cornerSeed(cy, cx) = true;
                end
            end
            distToCorner = bwdist(cornerSeed);
            outerNearCorners = outerRing & (distToCorner <= cornerW);
        end
    else
        outerNearCorners = false(size(paddedMask));
    end
    outerNearWalls = outerRing & ~outerNearCorners;
    cornersRealOutPadded = cornersPadded | outerNearCorners;
    wallsRealOutPadded   = wallsPadded   | outerNearWalls;

    zones = struct('name',{},'type',{},'maskfilled',{});
    zones(1) = mkZone('corners',                   cornersPadded,                pad);
    zones(2) = mkZone('walls',                     wallsPadded,                  pad);
    zones(3) = mkZone('walls_and_corners',         wallsAndCornersPadded,        pad);
    zones(4) = mkZone('center',                    centerPadded,                 pad);
    zones(5) = mkZone('arena_realout',             arenaRealOutPadded,           pad);
    zones(6) = mkZone('corners_realout',           cornersRealOutPadded,         pad);
    zones(7) = mkZone('walls_realout',             wallsRealOutPadded,           pad);
    zones(8) = mkZone('walls_and_corners_realout', wallsAndCornersRealOutPadded, pad);
end

function zone = mkZone(name, paddedMask, pad)
    [Hp, Wp] = size(paddedMask);
    H = Hp - 2*pad;
    W = Wp - 2*pad;
    zone.name = name;
    zone.type = 'area';
    zone.maskfilled = paddedMask(pad+1 : pad+H, pad+1 : pad+W);
end

function mask = squareCornerMask(paddedMask, cornerPoints, wallW, pad, mode)
    % Build a "square corner" parallelogram at each vertex.
    %
    %   mode = 'inner' (default) — quadrilateral inside the arena,
    %                              spanned by edges from V toward the two
    %                              neighboring corners ([V, V+L1*e1,
    %                              V+L1*e1+L2*e2, V+L2*e2]).
    %   mode = 'outer'           — same shape, mirrored across V (e1 →
    %                              -e1, e2 → -e2). Lies outside the arena
    %                              and extends each side outward by wallW.
    %                              Used for corners_realout so the outside
    %                              corner is a straight continuation of
    %                              the inside one across the vertex.
    %
    % Caller intersects the result with arenaMask (inner) or outerRing
    % (outer) as needed.
    if nargin < 5 || isempty(mode); mode = 'inner'; end
    sgn = 1;
    if strcmpi(mode, 'outer'); sgn = -1; end

    [Hp, Wp] = size(paddedMask);
    [yIdx, xIdx] = find(true(Hp, Wp));
    mask = false(Hp, Wp);
    n = size(cornerPoints, 1);
    if n < 3; return; end
    for i = 1:n
        prev = mod(i-2, n) + 1;
        next = mod(i,   n) + 1;
        V = cornerPoints(i, :) + pad;
        e1 = cornerPoints(prev, :) - cornerPoints(i, :);
        e2 = cornerPoints(next, :) - cornerPoints(i, :);
        n1 = norm(e1); if n1 == 0; continue; end
        n2 = norm(e2); if n2 == 0; continue; end
        e1 = e1 / n1; e2 = e2 / n2;
        % Inner: don't extend past the actual side length. Outer: full wallW.
        if sgn > 0
            L1 = min(wallW, n1);
            L2 = min(wallW, n2);
        else
            L1 = wallW; L2 = wallW;
        end
        P1 = V;
        P2 = V + sgn * L1 * e1;
        P3 = V + sgn * L1 * e1 + sgn * L2 * e2;
        P4 = V + sgn * L2 * e2;
        polyX = [P1(1), P2(1), P3(1), P4(1)];
        polyY = [P1(2), P2(2), P3(2), P4(2)];
        in = inpolygon(xIdx, yIdx, polyX, polyY);
        if any(in)
            idx = sub2ind([Hp, Wp], yIdx(in), xIdx(in));
            mask(idx) = true;
        end
    end
end

function mask = squareCornerOuterStripsMask(paddedMask, cornerPoints, wallW, pad)
    % For each vertex V, build TWO rectangles outside the arena, each one
    % a continuation of an adjacent wall through V — length wallW past V,
    % width wallW perpendicular to the wall (toward the OUTSIDE of the
    % arena). The pair forms two "wings" stretching past the corner along
    % the wall directions, so the outer-corner band visually continues
    % the inner square corner's straight edges past the vertex.
    [Hp, Wp] = size(paddedMask);
    [yIdx, xIdx] = find(true(Hp, Wp));
    mask = false(Hp, Wp);
    n = size(cornerPoints, 1);
    if n < 3; return; end
    cx = mean(cornerPoints(:, 1));
    cy = mean(cornerPoints(:, 2));
    for i = 1:n
        prev = mod(i-2, n) + 1;
        next = mod(i,   n) + 1;
        V = cornerPoints(i, :) + pad;
        % Each adjacent wall = 2 vertices of the polygon. We push wallW
        % past V along -e and wallW perpendicular outward.
        for nbr = [prev, next]
            e = cornerPoints(nbr, :) - cornerPoints(i, :);
            ne = norm(e); if ne == 0; continue; end
            e = e / ne;
            % Two perpendicular candidates; pick the one pointing AWAY
            % from arena centroid.
            perpA = [-e(2),  e(1)];
            perpB = [ e(2), -e(1)];
            midWall = (cornerPoints(i,:) + cornerPoints(nbr,:)) / 2;
            if norm(midWall + perpA - [cx, cy]) > norm(midWall + perpB - [cx, cy])
                nOut = perpA;
            else
                nOut = perpB;
            end
            P1 = V;
            P2 = V - wallW * e;
            P3 = V - wallW * e + wallW * nOut;
            P4 = V                + wallW * nOut;
            polyX = [P1(1), P2(1), P3(1), P4(1)];
            polyY = [P1(2), P2(2), P3(2), P4(2)];
            in = inpolygon(xIdx, yIdx, polyX, polyY);
            if any(in)
                idx = sub2ind([Hp, Wp], yIdx(in), xIdx(in));
                mask(idx) = true;
            end
        end
    end
end

function nearestMap = nearestStripMap(zones, ringMask)
    % For every pixel in ringMask, return the index k of the strip
    % whose interior is closest. Computed via per-strip bwdist; the
    % strip with the minimum distance to a pixel wins.
    [H, W] = size(ringMask);
    nearestMap = zeros(H, W, 'uint8');
    bestDist = inf(H, W);
    for k = 1:numel(zones)
        d = bwdist(zones(k).maskfilled);
        better = ringMask & (d < bestDist);
        bestDist(better) = d(better);
        nearestMap(better) = k;
    end
end
