function [x, y] = fromNormPoints(xn, yn, x_kcorr)
% FROMNORMPOINTS  Map normalized (isotropic-cm) coordinates back to pixels.
%
%   [x, y] = sphynx.geom.fromNormPoints(xn, yn, x_kcorr)
%
%   Exact inverse of sphynx.geom.toNormPoints: undo the X stretch so the
%   result overlays the original video frame.

    x = xn ./ x_kcorr;
    y = yn;
end
