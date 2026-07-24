function zones = partitionStrips(arenaMask, N, direction, varargin)
% PARTITIONSTRIPS  Divide arena mask into N equal strips.
%
%   zones = sphynx.zones.partitionStrips(arenaMask, N, direction, ...)
%
%   Inputs:
%     arenaMask - HxW logical, true inside arena
%     N         - positive integer, number of strips
%     direction - 'horizontal' (top->bottom) | 'vertical' (left->right)
%
%   Optional name-value:
%     'ArenaVertices' - Mx2 polygon vertices [x y] of the arena. When
%                       provided, the slab direction follows the arena's
%                       principal axis (PCA) rather than image x/y. For
%                       a square / rectangular polygon this means strips
%                       are parallel to the arena's sides even when the
%                       polygon is drawn at an angle.
%
%   Output:
%     zones - 1xN struct array with fields name/type/maskfilled.

    p = inputParser;
    addRequired(p, 'arenaMask');
    addRequired(p, 'N');
    addRequired(p, 'direction');
    addParameter(p, 'ArenaVertices', []);
    parse(p, arenaMask, N, direction, varargin{:});

    if ~islogical(arenaMask)
        arenaMask = arenaMask > 0;
    end
    if ~isnumeric(N) || N < 1 || N ~= round(N)
        error('sphynx:partitionStrips:invalidN', ...
            'N must be a positive integer; got %g', N);
    end
    if ~ismember(direction, {'horizontal','vertical'})
        error('sphynx:partitionStrips:unknownDirection', ...
            'direction must be horizontal|vertical; got "%s"', direction);
    end

    [H, W] = size(arenaMask);
    if ~any(arenaMask(:))
        error('sphynx:partitionStrips:emptyArena', 'arenaMask is empty');
    end

    verts = p.Results.ArenaVertices;
    if ~isempty(verts) && size(verts, 1) >= 3
        zones = stripsAlongPrincipalAxis(arenaMask, verts, N, direction, H, W);
    else
        zones = stripsAxisAligned(arenaMask, N, direction, H, W);
    end
end

function zones = stripsAxisAligned(arenaMask, N, direction, H, W)
    [yIdx, xIdx] = find(arenaMask);
    yMin = min(yIdx); yMax = max(yIdx);
    xMin = min(xIdx); xMax = max(xIdx);
    zones = struct('name',{},'type',{},'maskfilled',{});
    for i = 1:N
        m = false(H, W);
        switch direction
            case 'horizontal'
                yLo = yMin + round((i-1) * (yMax - yMin + 1) / N);
                yHi = yMin + round(i     * (yMax - yMin + 1) / N) - 1;
                yLo = max(yLo, 1); yHi = min(yHi, H);
                m(yLo:yHi, :) = true;
            case 'vertical'
                xLo = xMin + round((i-1) * (xMax - xMin + 1) / N);
                xHi = xMin + round(i     * (xMax - xMin + 1) / N) - 1;
                xLo = max(xLo, 1); xHi = min(xHi, W);
                m(:, xLo:xHi) = true;
        end
        zones(i).name = sprintf('strip%d', i);
        zones(i).type = 'area';
        zones(i).maskfilled = m & arenaMask;
    end
end

function zones = stripsAlongPrincipalAxis(arenaMask, verts, N, direction, H, W)
    % Compute the arena's principal direction. For a 4-vertex polygon use
    % the average of opposite sides (more stable than PCA for rectangles);
    % otherwise PCA on the vertices.
    cx = mean(verts(:, 1)); cy = mean(verts(:, 2));
    if size(verts, 1) == 4
        % Sides: 1->2, 2->3, 3->4, 4->1. Opposite pairs: (1->2 vs 3->4)
        % and (2->3 vs 4->1). Average each pair as a direction vector.
        side1 = verts(2, :) - verts(1, :);
        side3 = verts(3, :) - verts(4, :);   % flipped so the same side direction
        dir12 = (side1 + side3) / 2;
        if norm(dir12) == 0; dir12 = side1; end
        principalAngle = atan2(dir12(2), dir12(1));
    else
        % PCA: covariance of (x - cx, y - cy)
        dv = verts - [cx, cy];
        C = (dv' * dv) / max(1, size(dv, 1) - 1);
        [V, D] = eig(C);
        [~, ord] = sort(diag(D), 'descend');
        principalAngle = atan2(V(2, ord(1)), V(1, ord(1)));
    end

    % If the user asked for 'vertical' strips (left-right), they should run
    % perpendicular to the principal axis (across the long side). 'horizontal'
    % runs along the principal axis (top-bottom in arena frame).
    if strcmp(direction, 'horizontal')
        sliceAngle = principalAngle + pi/2;     % perpendicular to long side
    else
        sliceAngle = principalAngle;
    end

    % Project every arena pixel onto sliceAngle to get a scalar coordinate;
    % bin into N equal strips between min and max projection.
    [yIdx, xIdx] = find(arenaMask);
    px = xIdx - cx; py = yIdx - cy;
    proj = px * cos(sliceAngle) + py * sin(sliceAngle);
    pMin = min(proj); pMax = max(proj);
    edges = linspace(pMin, pMax, N + 1);

    zones = struct('name',{},'type',{},'maskfilled',{});
    for i = 1:N
        lo = edges(i); hi = edges(i+1);
        if i == N
            inStrip = proj >= lo & proj <= hi;
        else
            inStrip = proj >= lo & proj < hi;
        end
        m = false(H, W);
        idx = sub2ind([H, W], yIdx(inStrip), xIdx(inStrip));
        m(idx) = true;
        zones(i).name = sprintf('strip%d', i);
        zones(i).type = 'area';
        zones(i).maskfilled = m;
    end
end
