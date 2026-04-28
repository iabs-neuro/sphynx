function freezeMask = freezing(BodyPartsVelocity, Point, mode, restThresholdCmS, minRunFrames)
% FREEZING  Per-frame freezing detection with selectable mode.
%
%   freezeMask = sphynx.acts.freezing(velocity, Point, mode, restCmS, minRunFrames)
%
%   Inputs:
%     BodyPartsVelocity - PartsxN smoothed velocity matrix (cm/s) per
%                         body part
%     Point             - struct from sphynx.bodyparts.identifyParts
%     mode              - 'AllBodyParts' | 'NoseAndCenter' | 'HeadAndCenter'
%     restThresholdCmS  - velocity threshold (e.g., 1)
%     minRunFrames      - min length for a freeze episode
%
%   Output:
%     freezeMask - Nx1 logical, true on frames classified as freezing
%
%   Decomposition of legacy BehaviorAnalyzer.m:495-509.

    if ~ismember(mode, {'AllBodyParts', 'NoseAndCenter', 'HeadAndCenter'})
        error('sphynx:freezing:unknownMode', ...
            'mode must be AllBodyParts | NoseAndCenter | HeadAndCenter; got "%s"', mode);
    end

    [parts, n] = size(BodyPartsVelocity);

    switch mode
        case 'AllBodyParts'
            % Sum across all parts; frame is "freeze" if sum < threshold * parts.
            totalV = sum(BodyPartsVelocity, 1);
            raw = totalV < restThresholdCmS * parts;
        case 'NoseAndCenter'
            requirePart(Point, 'Nose');
            requirePart(Point, 'Center');
            raw = (BodyPartsVelocity(Point.Nose, :)   < restThresholdCmS * 2) & ...
                  (BodyPartsVelocity(Point.Center, :) < restThresholdCmS);
        case 'HeadAndCenter'
            requirePart(Point, 'HeadCenter');
            requirePart(Point, 'Center');
            raw = (BodyPartsVelocity(Point.HeadCenter, :) < restThresholdCmS) & ...
                  (BodyPartsVelocity(Point.Center, :)     < restThresholdCmS);
    end

    refined = sphynx.acts.refineAct(raw, minRunFrames, minRunFrames);
    freezeMask = refined(:);
end

function requirePart(Point, name)
    if isempty(Point.(name))
        error('sphynx:freezing:missingPart', ...
            'Mode requires Point.%s but it is empty', name);
    end
end
