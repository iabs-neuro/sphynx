function equation = getLineEquation(point1, point2)
% GETLINEEQUATION  Equation [k B x] of a line through two points.
%
%   equation = sphynx.util.getLineEquation(point1, point2)
%
%   point1, point2 - 1x2 [x y] coordinates.
%
%   Returns a 1x3 vector [k, B, x_const] interpreted as:
%     - if equation is "y = kx + B": [k, B, NaN]
%     - if equation is "x = a"      : [NaN, NaN, a] (vertical line)
%     - if point1 == point2         : [NaN, NaN, NaN] (degenerate)
%
%   Ported from legacy functions/GetLineEquation.m.

    if point1(1) == point2(1)
        if point1(2) == point2(2)
            equation = [nan nan nan];
        else
            equation = [nan nan point1(1)];
        end
    else
        k = (point1(2) - point2(2)) / (point1(1) - point2(1));
        B = (point2(2)*point1(1) - point1(2)*point2(1)) / (point1(1) - point2(1));
        equation = [k B nan];
    end
end
