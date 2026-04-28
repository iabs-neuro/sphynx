function out = speedActs(velocity, restThresholdCmS, locThresholdCmS, minRunFrames)
% SPEEDACTS  Classify per-frame velocity into rest/walk/locomotion.
%
%   out = sphynx.acts.speedActs(velocity, restCmS, locCmS, minRunFrames)
%
%   Inputs:
%     velocity         - Nx1 cm/s (already smoothed)
%     restThresholdCmS - frames with v < this are "rest"
%     locThresholdCmS  - frames with v >= this are "locomotion"
%     minRunFrames     - min consecutive frames for an act to count
%                        (used by refineAct)
%
%   Output struct:
%     rest, walk, locomotion - Nx1 logical arrays (mutually exclusive,
%                              cover all frames after refinement)
%
%   "walk" is the in-between region, plus any short rest/loc runs that
%   were dropped by the min-length filter — they get merged based on
%   the mean velocity in the dropped run (legacy logic at lines 484-493).
%
%   Decomposition of legacy BehaviorAnalyzer.m:467-493.

    % TODO(polish): expose midPointCmS = mean(rest, loc) as named param
    %   in case user wants asymmetric reassignment of dropped runs.

    velocity = velocity(:);
    n = numel(velocity);

    rawRest = velocity < restThresholdCmS;
    rawLoc  = velocity > locThresholdCmS;

    % Refine rest first
    refinedRest = sphynx.acts.refineAct(rawRest, minRunFrames, minRunFrames);

    % Locomotion is computed on the non-rest region
    rawLocOnNonRest = rawLoc(:)' & ~refinedRest;
    refinedLoc = sphynx.acts.refineAct(rawLocOnNonRest, minRunFrames, minRunFrames);

    % Walk is the rest of the non-rest region
    rawWalk = ~(refinedRest | refinedLoc);
    refinedWalk = sphynx.acts.refineAct(rawWalk, minRunFrames, minRunFrames);

    % Reassign frames that fell out of all three (legacy line 484-493:
    % short walk-runs get merged into rest or locomotion by their mean velocity)
    leftover = rawWalk & ~refinedWalk;
    midPoint = (restThresholdCmS + locThresholdCmS) / 2;
    [~, leftoverRuns] = sphynx.acts.refineAct(leftover, 0, 0);
    for k = 1:numel(leftoverRuns)
        rng = leftoverRuns(k).frameIn : leftoverRuns(k).frameOut;
        if mean(velocity(rng)) > midPoint
            refinedLoc(rng) = true;
        else
            refinedRest(rng) = true;
        end
    end

    out.rest       = refinedRest(:);
    out.walk       = refinedWalk(:);
    out.locomotion = refinedLoc(:);

    % Sanity: every frame should be in exactly one bucket
    assert(all(out.rest + out.walk + out.locomotion == 1), ...
        'sphynx:speedActs:partitionInvariant', ...
        'rest+walk+locomotion does not partition the frames');
end
