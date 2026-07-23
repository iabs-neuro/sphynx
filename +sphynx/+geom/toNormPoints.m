function [xn, yn] = toNormPoints(x, y, x_kcorr)
% TONORMPOINTS  Map pixel coordinates into normalized (isotropic-cm) space.
%
%   [xn, yn] = sphynx.geom.toNormPoints(x, y, x_kcorr)
%
%   Calibration may yield different pixels-per-cm on the two axes; that
%   ratio is captured in x_kcorr = pxlPerCmY / pxlPerCmX. The reference
%   scale (pxl2sm) is the Y scale, so normalized space keeps Y unchanged
%   and stretches X by x_kcorr. In this space 1 px == the same cm on both
%   axes, so circles are circles and Euclidean distance is physical.
%
%   Inverse: sphynx.geom.fromNormPoints.

    xn = x .* x_kcorr;
    yn = y;
end
