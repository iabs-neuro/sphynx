function ctx = makeActContext(result)
% MAKEACTCONTEXT  Build the ctx struct that sphynx.acts.applyAct expects
% from an analyzeSession result struct (BodyPartsTraces / Zones / etc.).

    n = result.n_frames;
    H = numel(result.BodyPartsTraces);
    X = nan(H, n); Y = nan(H, n); V = nan(H, n);
    bodyParts = cell(1, H);
    for k = 1:H
        t = result.BodyPartsTraces(k);
        bodyParts{k} = t.BodyPartName;
        if ~isempty(t.TraceSmoothed) && isfield(t.TraceSmoothed, 'X')
            X(k, :) = t.TraceSmoothed.X(:)';
            Y(k, :) = t.TraceSmoothed.Y(:)';
        end
        if isfield(t, 'VelocitySmoothed') && ~isempty(t.VelocitySmoothed)
            V(k, :) = t.VelocitySmoothed(:)';
        end
    end
    ctx.X = X; ctx.Y = Y; ctx.velocityCmS = V;
    ctx.bodyParts = bodyParts;
    ctx.zones = result.Zones;
    ctx.frameRate = result.Options.FrameRate;
    if isfield(result.Options, 'pxl2sm')
        ctx.pixelsPerCm = result.Options.pxl2sm;
    else
        ctx.pixelsPerCm = 1;
    end
    if isfield(result.Options, 'x_kcorr') && isnumeric(result.Options.x_kcorr) ...
            && isscalar(result.Options.x_kcorr) && result.Options.x_kcorr > 0
        ctx.xKcorr = result.Options.x_kcorr;
    else
        ctx.xKcorr = 1;
    end
    ctx.allActs = sphynx.acts.emptyActsArray();
    ctx.resultsByName = containers.Map();
end
