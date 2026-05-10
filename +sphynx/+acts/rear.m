function rearMask = rear(BodyPartsX, BodyPartsY, Point, mode, varargin)
% REAR  Per-frame rear detection with selectable mode.
%
%   rearMask = sphynx.acts.rear(BodyPartsX, BodyPartsY, Point, mode, ...)
%
%   Inputs:
%     BodyPartsX, BodyPartsY - PartsxN body-part traces (pixels)
%     Point                  - struct from identifyParts
%     mode                   - 'AllBodyParts' | 'TailbasePaws'
%
%   Name-value:
%     'PixelsPerCm'                default required
%     'AllBodyPartsThresholdPxl'   default 170 (mode 'AllBodyParts')
%     'TailbasePawsThresholdCm'    default 3.6 (mode 'TailbasePaws')
%     'SmoothWindowFrames'         default round(FrameRate/2) — caller must supply
%     'MinRunFrames'               default 5
%     'FrameRate'                  default 30 (used to default the smoothing window)
%
%   Output:
%     rearMask - Nx1 logical
%
%   Decomposition of legacy BehaviorAnalyzer.m:511-533.
%   AllBodyParts mode:  rears = (sum of distances from Center to all
%                       parts) is small.
%   TailbasePaws mode:  rears = (sum of distances from Tailbase to
%                       Left/RightHindLimb) is small (paws under body).

    p = inputParser;
    addParameter(p, 'PixelsPerCm', [], @(v) isempty(v) || (isnumeric(v) && v > 0));
    addParameter(p, 'AllBodyPartsThresholdPxl', 170);
    addParameter(p, 'TailbasePawsThresholdCm', 2.8);
    addParameter(p, 'AutoThreshold', false, @islogical);
    addParameter(p, 'SmoothWindowFrames', [], @(v) isempty(v) || (isnumeric(v) && v >= 3 && mod(v,2)==1));
    addParameter(p, 'MinRunFrames', 5);
    addParameter(p, 'FrameRate', 30);
    parse(p, varargin{:});

    if ~ismember(mode, {'AllBodyParts', 'TailbasePaws'})
        error('sphynx:rear:unknownMode', ...
            'mode must be AllBodyParts | TailbasePaws; got "%s"', mode);
    end
    if isempty(p.Results.PixelsPerCm)
        error('sphynx:rear:missingPixelsPerCm', 'PixelsPerCm is required');
    end

    n = size(BodyPartsX, 2);

    switch mode
        case 'AllBodyParts'
            requirePart(Point, 'Center');
            cx = BodyPartsX(Point.Center, :);
            cy = BodyPartsY(Point.Center, :);
            sumDist = zeros(1, n);
            for part = 1:size(BodyPartsX, 1)
                dx = cx - BodyPartsX(part, :);
                dy = cy - BodyPartsY(part, :);
                sumDist = sumDist + sqrt(dx.^2 + dy.^2);
            end
            window = orDefault(p.Results.SmoothWindowFrames, makeOdd(round(p.Results.FrameRate)));
            smoothed = sphynx.preprocess.smoothTrace(sumDist(:), window);
            raw = smoothed' < p.Results.AllBodyPartsThresholdPxl;

        case 'TailbasePaws'
            requirePart(Point, 'Tailbase');
            requirePart(Point, 'LeftHindLimb');
            requirePart(Point, 'RightHindLimb');
            tx = BodyPartsX(Point.Tailbase, :);
            ty = BodyPartsY(Point.Tailbase, :);
            sumDist = zeros(1, n);
            for part = [Point.LeftHindLimb, Point.RightHindLimb]
                dx = tx - BodyPartsX(part, :);
                dy = ty - BodyPartsY(part, :);
                sumDist = sumDist + sqrt(dx.^2 + dy.^2);
            end
            window = orDefault(p.Results.SmoothWindowFrames, makeOdd(ceil(p.Results.FrameRate / 2)));
            smoothed = sphynx.preprocess.smoothTrace(sumDist(:), window);
            % Decide threshold: explicit cm value, or auto from
            % distribution of smoothed sumDist (cm). Auto wins when
            % the AutoThreshold flag is set.
            if p.Results.AutoThreshold
                smoothedCm = smoothed(:)' / p.Results.PixelsPerCm;
                thrCm = sphynx.acts.autoRearThresholdCm(smoothedCm);
                if ~isfinite(thrCm)
                    thrCm = p.Results.TailbasePawsThresholdCm;
                end
            else
                thrCm = p.Results.TailbasePawsThresholdCm;
            end
            thresholdPxl = thrCm * p.Results.PixelsPerCm;
            raw = smoothed' < thresholdPxl;
    end

    refined = sphynx.acts.refineAct(raw, p.Results.MinRunFrames, p.Results.MinRunFrames);
    rearMask = refined(:);
end

function requirePart(Point, name)
    if isempty(Point.(name))
        error('sphynx:rear:missingPart', ...
            'Mode requires Point.%s but it is empty', name);
    end
end

function v = orDefault(value, fallback)
    if isempty(value)
        v = fallback;
    else
        v = value;
    end
end

function w = makeOdd(w)
    if mod(w, 2) == 0
        w = w + 1;
    end
    if w < 3
        w = 3;
    end
end
