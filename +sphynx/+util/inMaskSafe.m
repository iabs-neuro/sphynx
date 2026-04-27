function inside = inMaskSafe(mask, x, y)
% INMASKSAFE  Query a 2D logical mask at (x, y) safely.
%
%   inside = sphynx.util.inMaskSafe(mask, x, y) returns true if the
%   given pixel is inside the mask. Coordinates are rounded to the
%   nearest pixel. Coordinates outside the mask bounds return false.
%
%   Vectorized: x and y can be vectors of the same length, returning
%   a logical column vector.
%
%   Use this instead of direct mask(round(y), round(x)) - that
%   crashes or returns garbage for out-of-bounds, contributing to
%   Bug-1 (arena boundary at frame edge).
%
%   See also: sphynx.zones.classifySquare

    x = x(:); y = y(:);
    if numel(x) ~= numel(y)
        error('sphynx:inMaskSafe:sizeMismatch', 'x and y must have same length');
    end

    [H, W] = size(mask);
    xi = round(x);
    yi = round(y);
    inBounds = xi >= 1 & xi <= W & yi >= 1 & yi <= H;
    inside = false(numel(x), 1);
    if any(inBounds)
        idx = sub2ind([H, W], yi(inBounds), xi(inBounds));
        inside(inBounds) = mask(idx) > 0;
    end
end
