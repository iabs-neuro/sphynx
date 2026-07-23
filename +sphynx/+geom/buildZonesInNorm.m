function Z = buildZonesInNorm(maskPx, x_kcorr, builderFn)
% BUILDZONESINNORM  Run a mask-based zone builder in normalized space.
%
%   Z = sphynx.geom.buildZonesInNorm(maskPx, x_kcorr, builderFn)
%
%   builderFn is a function handle taking a normalized (isotropic-cm)
%   arena mask and returning a zone struct array (name/type/maskfilled).
%   The arena mask is resampled into normalized space (X stretched by
%   x_kcorr), builderFn runs there so distance transforms and ring widths
%   are physically correct on both axes, and every returned zone mask is
%   resampled back to the original pixel size so it overlays the video.
%
%   'point' zones (maskfilled = [x y]) have their coordinate mapped back
%   instead. x_kcorr == 1 bypasses all resampling (exact legacy path).
%
%   Any point-geometry inputs the builder needs (corner points, arena
%   vertices) must already be expressed in normalized space by the caller
%   via sphynx.geom.toNormPoints.

    maskPx = logical(maskPx);
    sz = size(maskPx);

    if x_kcorr == 1
        Z = builderFn(maskPx);
        return;
    end

    maskNorm = sphynx.geom.toNormMask(maskPx, x_kcorr);
    Z = builderFn(maskNorm);

    for k = 1:numel(Z)
        mf = Z(k).maskfilled;
        if isfield(Z(k), 'type') && strcmp(Z(k).type, 'point')
            if numel(mf) >= 2
                [px, py] = sphynx.geom.fromNormPoints(mf(1), mf(2), x_kcorr);
                Z(k).maskfilled = [px, py];
            end
        elseif ~isempty(mf) && ~isvector(mf)
            Z(k).maskfilled = sphynx.geom.fromNormMask(logical(mf), sz);
        end
    end
end
