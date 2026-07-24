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

    % Graceful mode degradation: NoseAndCenter / HeadAndCenter quietly
    % fall back to AllBodyParts when their preferred parts aren't in
    % the resolved Point struct. DLC schemas that drop the nose / head
    % via NotFound (e.g., superanimal_topviewmouse with strict
    % likelihood threshold) used to abort the whole session with a
    % hard error here. The AllBodyParts mode is the safe lowest-
    % common-denominator and stays correct (just less specific).
    effectiveMode = mode;
    switch mode
        case 'NoseAndCenter'
            if isempty(getOrEmpty(Point, 'Nose')) || isempty(getOrEmpty(Point, 'Center'))
                sphynx.util.log('warn', ['freezing: mode NoseAndCenter needs Nose+Center ' ...
                    'but at least one is unresolved -- falling back to AllBodyParts.']);
                effectiveMode = 'AllBodyParts';
            end
        case 'HeadAndCenter'
            if isempty(getOrEmpty(Point, 'HeadCenter')) || isempty(getOrEmpty(Point, 'Center'))
                sphynx.util.log('warn', ['freezing: mode HeadAndCenter needs HeadCenter+Center ' ...
                    'but at least one is unresolved -- falling back to AllBodyParts.']);
                effectiveMode = 'AllBodyParts';
            end
    end

    switch effectiveMode
        case 'AllBodyParts'
            % Sum across all parts; frame is "freeze" if sum < threshold * parts.
            totalV = sum(BodyPartsVelocity, 1);
            raw = totalV < restThresholdCmS * parts;
        case 'NoseAndCenter'
            raw = (BodyPartsVelocity(Point.Nose, :)   < restThresholdCmS * 2) & ...
                  (BodyPartsVelocity(Point.Center, :) < restThresholdCmS);
        case 'HeadAndCenter'
            raw = (BodyPartsVelocity(Point.HeadCenter, :) < restThresholdCmS) & ...
                  (BodyPartsVelocity(Point.Center, :)     < restThresholdCmS);
    end

    refined = sphynx.acts.refineAct(raw, minRunFrames, minRunFrames);
    freezeMask = refined(:);
end

function v = getOrEmpty(Point, name)
    if isfield(Point, name); v = Point.(name); else; v = []; end
end
