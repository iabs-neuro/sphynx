function mask = maskFromBorder(H, W, x, y)
% MASKFROMBORDER  Build a 2D logical border mask from polyline points.
%
%   mask = sphynx.preset.maskFromBorder(H, W, x, y) returns an HxW
%   logical mask with TRUE at every pixel rounded from (x(k), y(k))
%   that falls within bounds. Out-of-bounds points are silently
%   skipped — this is the Bug-1-aware version of the legacy
%   functions/MaskCreator.m (which only differed by being numeric).
%
%   Use this followed by `imfill` to get the filled region of an arena
%   or object polygon.

    mask = false(H, W);
    n = numel(x);
    for k = 1:n
        xi = round(x(k));
        yi = round(y(k));
        if xi >= 1 && xi <= W && yi >= 1 && yi <= H
            mask(yi, xi) = true;
        end
    end
end
