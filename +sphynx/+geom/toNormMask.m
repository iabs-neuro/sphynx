function maskNorm = toNormMask(mask, x_kcorr)
% TONORMMASK  Resample a pixel-space logical mask into normalized space.
%
%   maskNorm = sphynx.geom.toNormMask(mask, x_kcorr)
%
%   Stretches the columns (X axis) by x_kcorr so the mask lives in the
%   isotropic-cm space where distance transforms and ring widths are
%   physically correct on both axes. Rows (Y) are unchanged.
%
%   x_kcorr == 1 is a no-op (returns the mask unchanged as logical).
%
%   Inverse: sphynx.geom.fromNormMask (pass the original [H W] size).

    mask = logical(mask);
    if x_kcorr == 1
        maskNorm = mask;
        return;
    end
    [H, W] = size(mask);
    Wn = max(1, round(W * x_kcorr));
    maskNorm = imresize(mask, [H, Wn], 'nearest') > 0;
end
