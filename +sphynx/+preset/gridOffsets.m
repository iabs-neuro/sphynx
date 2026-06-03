function offsets = gridOffsets(n, step)
% GRIDOFFSETS  Layout offsets for N copies of an object.
%
%   offsets = sphynx.preset.gridOffsets(n, step) returns an Nx2 matrix
%   of (dx, dy). Row layout for n <= 5; 5-column grid for n > 5,
%   row-major filling.
    if n <= 0
        offsets = zeros(0, 2);
        return;
    end
    cols = min(n, 5);
    offsets = zeros(n, 2);
    for k = 1:n
        r = floor((k - 1) / cols);
        c = mod(k - 1, cols);
        offsets(k, :) = [(c + 1) * step, r * step];
    end
end
