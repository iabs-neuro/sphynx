function idx = marqueeSelect(centroids, rect)
% MARQUEESELECT  Return indices of centroids inside the rectangle.
%
%   idx = sphynx.preset.marqueeSelect(centroids, rect)
%
%   centroids  Nx2 [x y] points
%   rect       1x4 [x y w h] (MATLAB position rect); [] -> no selection
%
%   Edge inclusive on all four sides. Returns column vector (or [] if rect
%   is empty / no matches).
    if isempty(rect)
        idx = [];
        return;
    end
    x0 = rect(1); y0 = rect(2);
    x1 = x0 + rect(3); y1 = y0 + rect(4);
    inX = centroids(:,1) >= x0 & centroids(:,1) <= x1;
    inY = centroids(:,2) >= y0 & centroids(:,2) <= y1;
    idx = find(inX & inY);
end
