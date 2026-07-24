function regions = arenaExclusionRing(arenaMask, widthPx)
% ARENAEXCLUSIONRING  Build polygon vertices of a ring of given pixel width
% OUTSIDE the arena boundary.
%
%   regions = sphynx.preprocess.arenaExclusionRing(arenaMask, widthPx)
%
%   Returns a struct array with .vertices (Nx2 [x y]). One element per
%   connected component of the ring (frame edges can split it). Empty
%   array if widthPx <= 0 or arena fills the frame.
    if widthPx <= 0
        regions = struct('vertices', {});
        return;
    end
    arenaMask = arenaMask > 0;
    distOutside = bwdist(arenaMask);
    ringMask = distOutside > 0 & distOutside <= widthPx;
    if ~any(ringMask(:))
        regions = struct('vertices', {});
        return;
    end
    B = bwboundaries(ringMask, 'noholes');
    regions = struct('vertices', {});
    for k = 1:numel(B)
        v = B{k};
        if size(v, 1) < 3; continue; end
        regions(end + 1).vertices = v(:, [2 1]);   % [row col] -> [x y]
    end
end
