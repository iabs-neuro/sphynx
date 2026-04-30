function out = applyPerPartSettings(rawX, rawY, likelihood, settings, ctx)
% APPLYPERPARTSETTINGS  Run the full per-part preprocessing pipeline.
%
%   out = sphynx.preprocess.applyPerPartSettings(rawX, rawY, likelihood,
%         settings, ctx)
%
%   This is the orchestrator used by both the GUI tab (Compute one
%   part) and the future batch runner. The pipeline order matches
%   the spec (`docs/superpowers/specs/2026-04-30-sphynx-preprocess-tab-design.md`):
%
%     1. likelihoodFilter   (likelihood < thr -> NaN)
%     2. boundsFilter       (out of frame -> NaN)
%     3. velocityJumpFilter (pre-interp, optional, Slice 4)
%     4. hampelFilter       (pre-interp, optional, Slice 4)
%     5. manualRegions      (pre-interp, Slice 5)
%     6. interpolateGaps
%     7. smoothing (sgolay / movmean / movmedian / gaussian) OR
%        kalmanFilter2D (Slice 4, replaces 7a)
%
%   In Slice 2, only steps 1-2 (via cleanBodyPart), 6, and 7 are wired.
%   Steps 3-5 and Kalman are no-ops, hooked in subsequent slices.
%
%   Inputs:
%     rawX, rawY  - Nx1 raw position (px)
%     likelihood  - Nx1 DLC confidence
%     settings    - struct with fields
%                     likelihoodThreshold, smoothWindowSec,
%                     interpolationMethod, smoothingMethod,
%                     smoothingPolyOrder, notFoundThresholdPct
%                   (see sphynx.preprocess.perPartDefault)
%     ctx         - struct with run-time context:
%                     frameWidth, frameHeight, frameRate (Hz)
%                   optional: pixelsPerCm (needed for velocity-jump in Slice 4),
%                             outlier (struct with filter flags, Slice 4),
%                             manualRegions (Slice 5)
%
%   Returns:
%     out.X_clean              Nx1 (NaN where bad)
%     out.Y_clean              Nx1
%     out.X_interp             Nx1 (filled)
%     out.Y_interp             Nx1
%     out.X_smooth             Nx1 (final)
%     out.Y_smooth             Nx1
%     out.percentNaN           %
%     out.percentLowLikelihood %
%     out.percentBadCombined   %
%     out.percentOutliers      % (zero in Slice 2)
%     out.status               'Good' | 'NotFound'

    rawX = rawX(:); rawY = rawY(:); likelihood = likelihood(:);

    % --- 1-2. Clean (likelihood + bounds) ----------------------------
    cleaned = sphynx.preprocess.cleanBodyPart(rawX, rawY, likelihood, ...
        'FrameWidth',          ctx.frameWidth, ...
        'FrameHeight',         ctx.frameHeight, ...
        'LikelihoodThreshold', settings.likelihoodThreshold, ...
        'MissingThresholdPct', settings.notFoundThresholdPct);

    out.X_clean = cleaned.X;
    out.Y_clean = cleaned.Y;
    out.percentNaN = cleaned.PercentNaN;
    out.percentLowLikelihood = cleaned.PercentLowLikelihood;
    out.percentBadCombined = cleaned.PercentBadCombined;
    out.percentOutliers = 0;  % filled in Slice 4
    out.status = cleaned.Status;

    if strcmp(out.status, 'NotFound')
        out.X_interp = nan(size(rawX));
        out.Y_interp = nan(size(rawY));
        out.X_smooth = nan(size(rawX));
        out.Y_smooth = nan(size(rawY));
        return;
    end

    % --- 3-4. Outlier filters (pre-interp on raw position) ----------
    outliers = false(size(rawX));
    if isfield(ctx, 'outlier') && isstruct(ctx.outlier)
        % velocity-jump
        if isfield(ctx.outlier, 'velocityJump') && ...
                ctx.outlier.velocityJump.enabled && ~isempty(ctx.pixelsPerCm)
            [out.X_clean, out.Y_clean, badV] = ...
                sphynx.preprocess.velocityJumpFilter(out.X_clean, out.Y_clean, ...
                    ctx.frameRate, ctx.pixelsPerCm, ...
                    ctx.outlier.velocityJump.maxVelocityCmS);
            outliers = outliers | badV;
        end
        % Hampel
        if isfield(ctx.outlier, 'hampel') && ctx.outlier.hampel.enabled
            [out.X_clean, out.Y_clean, badH] = ...
                sphynx.preprocess.hampelFilter(out.X_clean, out.Y_clean, ...
                    ctx.outlier.hampel.windowSize, ctx.outlier.hampel.nSigma);
            outliers = outliers | badH;
        end
    end
    out.percentOutliers = round(100 * sum(outliers) / numel(outliers), 2);

    % --- 5. Manual regions ------------------------------------------
    if isfield(ctx, 'manualRegions') && ~isempty(ctx.manualRegions)
        partName = '';
        if isfield(ctx, 'partName'); partName = ctx.partName; end
        for r = 1:numel(ctx.manualRegions)
            reg = ctx.manualRegions(r);
            applies = strcmp(reg.appliesTo, 'all') || ...
                (~isempty(partName) && strcmpi(reg.appliesTo, partName));
            if ~applies; continue; end
            v = reg.vertices;
            if isempty(v) || size(v, 2) ~= 2; continue; end
            in = inpolygon(out.X_clean, out.Y_clean, v(:, 1), v(:, 2));
            in = in(:);
            out.X_clean(in) = NaN;
            out.Y_clean(in) = NaN;
        end
    end

    % Recompute combined-bad percent after outlier+manual stages
    nFrames = numel(rawX);
    out.percentBadCombined = round(100 * sum(isnan(out.X_clean) | isnan(out.Y_clean)) / nFrames, 2);

    % --- 6. Interpolate gaps -----------------------------------------
    out.X_interp = sphynx.preprocess.interpolateGaps(out.X_clean, ...
        'Method', settings.interpolationMethod);
    out.Y_interp = sphynx.preprocess.interpolateGaps(out.Y_clean, ...
        'Method', settings.interpolationMethod);

    % Clamp to frame bounds (legacy parity)
    out.X_interp = clamp(out.X_interp, 1, ctx.frameWidth);
    out.Y_interp = clamp(out.Y_interp, 1, ctx.frameHeight);

    % --- 7. Smooth ----------------------------------------------------
    winSamples = makeOdd(round(ctx.frameRate * settings.smoothWindowSec));
    if strcmpi(settings.smoothingMethod, 'kalman')
        kp = defaultKalmanParams();
        if isfield(ctx, 'outlier') && isfield(ctx.outlier, 'kalman')
            kp = mergeStruct(kp, ctx.outlier.kalman);
        end
        [out.X_smooth, out.Y_smooth] = sphynx.preprocess.kalmanFilter2D( ...
            out.X_interp, out.Y_interp, likelihood, ...
            kp.processNoise, kp.measNoiseScale);
    else
        out.X_smooth = applySmoothing(out.X_interp, winSamples, settings);
        out.Y_smooth = applySmoothing(out.Y_interp, winSamples, settings);
    end

    % Final clamp to frame bounds (smoothing can over/undershoot slightly)
    out.X_smooth = clamp(out.X_smooth, 1, ctx.frameWidth);
    out.Y_smooth = clamp(out.Y_smooth, 1, ctx.frameHeight);
end

function y = applySmoothing(x, winSamples, settings)
    method = settings.smoothingMethod;
    if numel(x) < winSamples
        y = x; return;
    end
    switch lower(method)
        case 'sgolay'
            y = sphynx.preprocess.smoothTrace(x, winSamples, ...
                'PolyOrder', settings.smoothingPolyOrder);
        case 'movmean'
            y = smoothdata(x, 'movmean', winSamples);
        case 'movmedian'
            y = smoothdata(x, 'movmedian', winSamples);
        case 'gaussian'
            y = smoothdata(x, 'gaussian', winSamples);
        otherwise
            error('sphynx:applyPerPartSettings:unknownSmoothing', ...
                'Unknown smoothing method: %s', method);
    end
end

function p = defaultKalmanParams()
    p.processNoise = 1e-2;
    p.measNoiseScale = 1.0;
end

function out = mergeStruct(base, override)
    out = base;
    f = fieldnames(override);
    for k = 1:numel(f)
        out.(f{k}) = override.(f{k});
    end
end

function w = makeOdd(w)
    if w < 3, w = 3; end
    if mod(w, 2) == 0, w = w + 1; end
end

function v = clamp(x, lo, hi)
    v = x;
    v(v < lo) = lo;
    v(v > hi) = hi;
end
