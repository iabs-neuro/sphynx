function hd = headDirection(headTipX, headTipY, headCenterX, headCenterY, smoothWindow)
% HEADDIRECTION  Compute head-direction angle, safely smoothed.
%
%   hd = sphynx.angles.headDirection(tipX, tipY, centerX, centerY, win)
%   returns the head-direction angle in (-pi, pi] for each frame,
%   computed as atan2(tipY - centerY, tipX - centerX) and smoothed
%   with a Savitzky-Golay filter of length `win` after unwrapping.
%
%   Bug-2 fix: angle is unwrapped before smoothing and wrapped after,
%   so the result is continuous across the +/-pi boundary.
%
%   Inputs:
%     headTipX, headTipY       - Nx1 trace of head tip position (e.g., nose)
%     headCenterX, headCenterY - Nx1 trace of head center position
%     smoothWindow             - odd integer window length (>=3); if < 3, no smoothing

    headTipX = headTipX(:); headTipY = headTipY(:);
    headCenterX = headCenterX(:); headCenterY = headCenterY(:);

    raw = atan2(headTipY - headCenterY, headTipX - headCenterX);
    if smoothWindow >= 3
        hd = sphynx.angles.unwrapForSmooth(raw, smoothWindow);
    else
        hd = sphynx.angles.wrap(raw);
    end
end
