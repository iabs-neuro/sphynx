function s = pStars(p)
% PSTARS  Convert p-value to a star annotation.
%   ns   p >= 0.05
%   *    p <  0.05
%   **   p <  0.01
%   ***  p <  0.001
%   **** p <  0.0001
    if isnan(p) || ~isnumeric(p); s = ''; return; end
    if p < 0.0001; s = '****';
    elseif p < 0.001;  s = '***';
    elseif p < 0.01;   s = '**';
    elseif p < 0.05;   s = '*';
    else;              s = 'ns';
    end
end
