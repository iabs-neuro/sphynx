function [xR, yR] = rotateAroundCentroid(x, y, centroid, angleRad)
% ROTATEAROUNDCENTROID  Rotate points (x,y) by `angleRad` around `centroid`.
%
%   [xR, yR] = sphynx.preset.rotateAroundCentroid(x, y, centroid, angleRad)
%
%   centroid  1x2 [cx cy]
%   angleRad  radians (positive = CCW)
    cx = centroid(1); cy = centroid(2);
    c = cos(angleRad); s = sin(angleRad);
    dx = x - cx;       dy = y - cy;
    xR = cx + dx*c - dy*s;
    yR = cy + dx*s + dy*c;
end
