function d = hypotKcorr(dx, dy, x_kcorr)
% HYPOTKCORR  Anisotropy-corrected displacement magnitude.
%
%   d = sphynx.geom.hypotKcorr(dx, dy, x_kcorr)
%
%   Returns the displacement magnitude in normalized (isotropic, Y-scale)
%   pixels by stretching the X component by x_kcorr before the Euclidean
%   norm. Divide the result by pxl2sm (the Y scale) to get physical cm.
%   x_kcorr == 1 (or omitted) reduces to plain sqrt(dx^2 + dy^2).
%
%   Vectorized: dx, dy may be arrays of matching size.

    if nargin < 3 || isempty(x_kcorr); x_kcorr = 1; end
    d = sqrt((dx .* x_kcorr).^2 + dy.^2);
end
