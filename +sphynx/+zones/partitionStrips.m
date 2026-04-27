function zones = partitionStrips(arenaMask, N, direction)
% PARTITIONSTRIPS  Divide arena mask into N equal strips.
%
%   zones = sphynx.zones.partitionStrips(arenaMask, N, direction)
%
%   Inputs:
%     arenaMask - HxW logical, true inside arena
%     N         - positive integer, number of strips
%     direction - 'horizontal' (top->bottom) | 'vertical' (left->right)
%
%   Output:
%     zones - 1xN struct array with fields:
%               name        - 'strip1', 'strip2', ...
%               type        - 'area'
%               maskfilled  - HxW logical, true inside strip i
%
%   The strips partition the arena: their union equals the input
%   arena mask, and they are pairwise disjoint. Strips are computed
%   by splitting the bounding box of the arena into N equal slabs
%   along the chosen direction, then intersecting with arenaMask.
%
%   Implements feature 1.3 (square arena partitioning) from
%   docs/superpowers/specs/2026-04-27-sphynx-stage-c-design.md.

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

    [yIdx, xIdx] = find(arenaMask);
    if isempty(yIdx)
        error('sphynx:partitionStrips:emptyArena', 'arenaMask is empty');
    end
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
