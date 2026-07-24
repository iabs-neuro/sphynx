function [x, y] = linesIntersection(k1, B1, k2, B2)
% LINESINTERSECTION  Intersection point of two y=kx+B lines.
%
%   [x, y] = sphynx.util.linesIntersection(k1, B1, k2, B2)
%
%   Returns the (x, y) intersection of lines y = k1*x + B1 and
%   y = k2*x + B2.
%
%   If the slopes are equal (parallel), this returns NaN, NaN
%   (cleaner than the legacy "k2 = k2 + 0.01" hack).
%
%   Ported from legacy functions/LinesPoint.m.

    if k1 == k2
        x = NaN;
        y = NaN;
        return;
    end
    x = (B2 - B1) / (k1 - k2);
    y = k1 * x + B1;
end
