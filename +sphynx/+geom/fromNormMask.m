function mask = fromNormMask(maskNorm, targetSize)
% FROMNORMMASK  Resample a normalized-space mask back to pixel space.
%
%   mask = sphynx.geom.fromNormMask(maskNorm, targetSize)
%
%   targetSize = [H W] of the original pixel-space mask. Undoes the X
%   stretch applied by sphynx.geom.toNormMask so the mask overlays the
%   video frame. Nearest-neighbour keeps the mask crisply logical.

    maskNorm = logical(maskNorm);
    if isequal(size(maskNorm), targetSize)
        mask = maskNorm;
        return;
    end
    mask = imresize(maskNorm, targetSize, 'nearest') > 0;
end
