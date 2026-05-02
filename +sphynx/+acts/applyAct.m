function bool = applyAct(act, ctx)
% APPLYACT  Evaluate one act on a session's data, returning a 1xN logical
% array (true = the act is happening on that frame).
%
%   bool = sphynx.acts.applyAct(act, ctx)
%
%   ctx fields (build via sphynx.acts.makeActContext):
%     X, Y       - HxN smoothed coords per body part (H = # parts)
%     bodyParts  - 1xH cell of names
%     velocityCmS - HxN per-part velocity (cm/s)
%     zones      - struct array {name, type, maskfilled} from preset
%     frameRate  - Hz
%     allActs    - struct array of acts (for complex.components lookup)
%     resultsByName - containers.Map of already-computed bool arrays so
%                     complex acts can reference simpler ones without
%                     recursive recomputation.
%
%   For 'simple' acts:  zones-AND/OR/EXCLUDE & bodyPart in zone(s)
%                       & velocity in [speedMin, speedMax].
%   For 'complex' acts: lookup components in resultsByName and combine.
%   For 'special' acts: dispatch to freezing / rears legacy logic.

    nFrames = size(ctx.X, 2);
    bool = false(1, nFrames);

    switch lower(act.type)
        case 'simple'
            bool = applySimple(act, ctx, nFrames);
        case 'complex'
            bool = applyComplex(act, ctx, nFrames);
        case 'special'
            bool = applySpecial(act, ctx, nFrames);
        otherwise
            warning('sphynx:applyAct:unknownType', ...
                'Unknown act type "%s" for "%s"', act.type, act.name);
    end
end

function b = applySimple(act, ctx, nFrames)
    % Body part lookup
    partIdx = findPart(ctx.bodyParts, act.bodyPart);
    if isempty(partIdx)
        b = false(1, nFrames); return;
    end

    % Speed gate
    v = ctx.velocityCmS(partIdx, :);
    speedOK = v >= act.speedMin & v <= act.speedMax;

    % Zone gate
    zoneOK = inAnyZone(act, ctx, partIdx, nFrames);

    b = speedOK & zoneOK;
end

function inside = inAnyZone(act, ctx, partIdx, nFrames)
    if isempty(act.zones)
        inside = true(1, nFrames); return;
    end
    masks = false(numel(act.zones), nFrames);
    for k = 1:numel(act.zones)
        zname = act.zones{k};
        zIdx = findZone(ctx.zones, zname);
        if isempty(zIdx); continue; end
        zoneMask = ctx.zones(zIdx).maskfilled;
        if ~islogical(zoneMask); zoneMask = zoneMask > 0; end
        masks(k, :) = pointsInMask(ctx.X(partIdx, :), ctx.Y(partIdx, :), zoneMask);
    end
    switch upper(act.zoneOp)
        case 'AND'
            inside = all(masks, 1);
        case 'EXCLUDE'
            inside = masks(1, :) & ~any(masks(2:end, :), 1);
        otherwise   % OR
            inside = any(masks, 1);
    end
end

function b = applyComplex(act, ctx, nFrames)
    comps = act.components;
    if isempty(comps); b = false(1, nFrames); return; end
    cmasks = false(numel(comps), nFrames);
    for k = 1:numel(comps)
        if isKey(ctx.resultsByName, comps{k})
            cmasks(k, :) = ctx.resultsByName(comps{k});
        else
            % Fall back to recursive evaluation if not pre-computed
            j = findActByName(ctx.allActs, comps{k});
            if ~isempty(j)
                cmasks(k, :) = sphynx.acts.applyAct(ctx.allActs(j), ctx);
            end
        end
    end
    switch lower(act.operation)
        case 'intersect'; b = all(cmasks, 1);
        case 'union';     b = any(cmasks, 1);
        case 'exclude';   b = cmasks(1, :) & ~any(cmasks(2:end, :), 1);
        case 'sequence'
            % A then B: B-frames within seqDelaySec after A-frames.
            if size(cmasks, 1) < 2; b = cmasks; return; end
            delayFrames = max(1, round(act.seqDelaySec * ctx.frameRate));
            A = cmasks(1, :);
            window = false(1, nFrames);
            for k = 1:nFrames
                if A(k)
                    e = min(nFrames, k + delayFrames);
                    window(k+1:e) = true;
                end
            end
            b = window & cmasks(2, :);
            for j = 3:size(cmasks, 1)
                b = b & cmasks(j, :);
            end
        otherwise
            b = false(1, nFrames);
    end
end

function b = applySpecial(act, ctx, nFrames)
    switch lower(act.specialKind)
        case 'freezing'
            b = applyFreezing(act, ctx, nFrames);
        case 'rears'
            b = applyRears(act, ctx, nFrames);
        otherwise
            b = false(1, nFrames);
    end
end

function b = applyFreezing(act, ctx, nFrames)
    parts = act.bodyParts;
    if isempty(parts); parts = {'headcenter', 'bodycenter'}; end
    masks = false(numel(parts), nFrames);
    for k = 1:numel(parts)
        idx = findPart(ctx.bodyParts, parts{k});
        if isempty(idx); continue; end
        masks(k, :) = ctx.velocityCmS(idx, :) < act.speedMax;
    end
    b = all(masks, 1);
end

function b = applyRears(act, ctx, nFrames)
    % Tailbase-paws mode: distance(tailbase, paws) below threshold.
    if strcmpi(act.rearMode, 'TailbasePaws') || isempty(act.rearMode)
        tIdx = findPart(ctx.bodyParts, 'tailbase');
        lIdx = findPart(ctx.bodyParts, 'lefthindlimb');
        rIdx = findPart(ctx.bodyParts, 'righthindlimb');
        if isempty(tIdx) || isempty(lIdx) || isempty(rIdx)
            b = false(1, nFrames); return;
        end
        thrPx = act.thresholdCm * ctx.pixelsPerCm;
        dL = sqrt((ctx.X(tIdx,:) - ctx.X(lIdx,:)).^2 + (ctx.Y(tIdx,:) - ctx.Y(lIdx,:)).^2);
        dR = sqrt((ctx.X(tIdx,:) - ctx.X(rIdx,:)).^2 + (ctx.Y(tIdx,:) - ctx.Y(rIdx,:)).^2);
        b = (dL < thrPx) | (dR < thrPx);
    else
        % AllBodyParts mode: simple Y < threshold heuristic on bodycenter
        idx = findPart(ctx.bodyParts, 'bodycenter');
        if isempty(idx); b = false(1, nFrames); return; end
        b = ctx.Y(idx, :) < act.thresholdPxl;
    end
end

% --- helpers ---------------------------------------------------------------

function idx = findPart(parts, name)
    idx = find(strcmpi(parts, name), 1);
end

function idx = findZone(zones, name)
    idx = find(strcmp({zones.name}, name), 1);
end

function idx = findActByName(acts, name)
    idx = find(strcmp({acts.name}, name), 1);
end

function in = pointsInMask(xs, ys, mask)
    [H, W] = size(mask);
    xi = round(xs); yi = round(ys);
    valid = isfinite(xi) & isfinite(yi) & xi >= 1 & xi <= W & yi >= 1 & yi <= H;
    in = false(1, numel(xs));
    if any(valid)
        idx = sub2ind([H, W], yi(valid), xi(valid));
        in(valid) = mask(idx);
    end
end
