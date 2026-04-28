function ellipse = ellipseFit(x, y)
% ELLIPSEFIT  Least-squares ellipse fit through given (x, y) points.
%
%   ellipse = sphynx.util.ellipseFit(x, y) returns a struct with the
%   parameters of the best-fit ellipse to the points. Requires at
%   least 5 points.
%
%   Output struct (when fit succeeds):
%     a, b           - semi-axes (radii of the non-tilted ellipse)
%     phi            - tilt angle in radians
%     X0, Y0         - center in non-tilted coordinates
%     X0_in, Y0_in   - center of the tilted ellipse in original coords
%     long_axis      - 2 * max(a, b)
%     short_axis     - 2 * min(a, b)
%     status         - '' on success, otherwise 'Parabola found' /
%                      'Hyperbola found' (returned struct is otherwise
%                      mostly empty)
%
%   Ported from legacy functions/my_fit_ellipse.m (the algorithm
%   originally by Ohad Gal). Plotting (axis_handle) removed; this
%   function is pure compute. See +sphynx/+viz/ for visualization.

    orientation_tolerance = 1e-3;
    warning('');

    x = x(:);  y = y(:);
    if numel(x) < 5
        error('sphynx:ellipseFit:tooFewPoints', ...
            'Need at least 5 points; got %d', numel(x));
    end

    mean_x = mean(x);
    mean_y = mean(y);
    x = x - mean_x;
    y = y - mean_y;

    X = [x.^2, x.*y, y.^2, x, y];
    a = sum(X) / (X' * X);

    if ~isempty(lastwarn)
        ellipse = emptyEllipse('matrix inversion warning');
        return;
    end

    [a, b, c, d, e] = deal(a(1), a(2), a(3), a(4), a(5));
    ar = a; br = b; cr = c; dr = d; er = e;

    if (min(abs(b/a), abs(b/c)) > orientation_tolerance)
        orientation_rad = 1/2 * atan(b / (c - a));
        cos_phi = cos(orientation_rad);
        sin_phi = sin(orientation_rad);
        [a, b, c, d, e] = deal( ...
            a*cos_phi^2 - b*cos_phi*sin_phi + c*sin_phi^2, ...
            0, ...
            a*sin_phi^2 + b*cos_phi*sin_phi + c*cos_phi^2, ...
            d*cos_phi - e*sin_phi, ...
            d*sin_phi + e*cos_phi);
        [mean_x, mean_y] = deal( ...
            cos_phi*mean_x - sin_phi*mean_y, ...
            sin_phi*mean_x + cos_phi*mean_y);
    else
        orientation_rad = 0;
        cos_phi = cos(orientation_rad);
        sin_phi = sin(orientation_rad);
    end

    test = a * c;
    if test == 0
        ellipse = emptyEllipse('Parabola found');
        ellipse.ar = ar; ellipse.br = br; ellipse.cr = cr; ellipse.dr = dr; ellipse.er = er;
        return;
    end
    if test < 0
        ellipse = emptyEllipse('Hyperbola found');
        ellipse.ar = ar; ellipse.br = br; ellipse.cr = cr; ellipse.dr = dr; ellipse.er = er;
        return;
    end

    if a < 0, [a, c, d, e] = deal(-a, -c, -d, -e); end
    X0 = mean_x - d/2/a;
    Y0 = mean_y - e/2/c;
    F  = 1 + (d^2)/(4*a) + (e^2)/(4*c);
    [a, b] = deal(sqrt(F/a), sqrt(F/c));
    long_axis  = 2 * max(a, b);
    short_axis = 2 * min(a, b);

    R = [cos_phi, sin_phi; -sin_phi, cos_phi];
    P_in = R * [X0; Y0];
    X0_in = P_in(1);
    Y0_in = P_in(2);

    ellipse = struct( ...
        'ar', ar, 'br', br, 'cr', cr, 'dr', dr, 'er', er, ...
        'a', a, 'b', b, ...
        'phi', orientation_rad, ...
        'X0', X0, 'Y0', Y0, ...
        'X0_in', X0_in, 'Y0_in', Y0_in, ...
        'long_axis', long_axis, ...
        'short_axis', short_axis, ...
        'status', '');
end

function e = emptyEllipse(status)
    e = struct( ...
        'ar', [], 'br', [], 'cr', [], 'dr', [], 'er', [], ...
        'a', [], 'b', [], 'phi', [], ...
        'X0', [], 'Y0', [], 'X0_in', [], 'Y0_in', [], ...
        'long_axis', [], 'short_axis', [], 'status', status);
end
