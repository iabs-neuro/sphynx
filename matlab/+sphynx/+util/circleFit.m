function [xc, yc, r] = circleFit(x, y)
% CIRCLEFIT  Least-squares circle fit through given (x, y) points.
%
%   [xc, yc, r] = sphynx.util.circleFit(x, y) returns the center
%   (xc, yc) and radius r of the best-fit circle.
%
%   Algorithm: linear LS solve of (x^2 + y^2) + a*x + b*y + c = 0
%   then xc = -a/2, yc = -b/2, r = sqrt((a^2+b^2)/4 - c).
%
%   Errors:
%     sphynx:circleFit:tooFewPoints  if numel(x) < 3
%     sphynx:circleFit:degenerate    if points are collinear (singular A)
%
%   Replacement for legacy functions/circfit.m, with explicit error
%   on degenerate input (legacy returned NaN silently).

    x = x(:); y = y(:);
    if numel(x) ~= numel(y)
        error('sphynx:circleFit:sizeMismatch', 'x and y must have the same length');
    end
    if numel(x) < 3
        error('sphynx:circleFit:tooFewPoints', ...
            'Need at least 3 points; got %d', numel(x));
    end

    A = [x, y, ones(numel(x), 1)];
    bvec = -(x.^2 + y.^2);

    if rcond(A' * A) < 1e-12
        error('sphynx:circleFit:degenerate', ...
            'Points appear collinear; cannot fit a circle');
    end

    sol = A \ bvec;
    a = sol(1); b = sol(2); c = sol(3);
    xc = -a/2;
    yc = -b/2;
    r = sqrt((a^2 + b^2)/4 - c);
end
