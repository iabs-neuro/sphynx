function [Xout, Yout, badMask] = velocityJumpFilter(X, Y, frameRate, pxlPerCm, maxCmS)
% VELOCITYJUMPFILTER  Mark frames where between-frame displacement
% exceeds the biological max velocity. Pre-interpolation outlier gate.
%
%   [Xout, Yout, badMask] = sphynx.preprocess.velocityJumpFilter(
%        X, Y, frameRate, pxlPerCm, maxCmS)
%
%   Inputs:
%     X, Y       - Nx1 raw position (px), may already contain NaN
%     frameRate  - Hz
%     pxlPerCm   - calibration scale (must be positive)
%     maxCmS     - biological max velocity (cm/s); default 50
%
%   Returns:
%     Xout, Yout - same shape as input; flagged frames set to NaN
%     badMask    - Nx1 logical (true = flagged at this frame)
%
%   The flagged frame is the one AFTER the offending displacement,
%   matching legacy semantics: if frame k is sensible and frame k+1
%   teleports, we drop frame k+1 (not k). Both endpoints of the jump
%   in actual outlier sequences usually trip the filter on adjacent
%   evaluations.
%
%   This filter runs PRE-interpolation. After interpolation, single-frame
%   outliers blend with neighbors and the threshold no longer triggers.

    if nargin < 5 || isempty(maxCmS); maxCmS = 50; end
    X = X(:); Y = Y(:);
    n = numel(X);
    badMask = false(n, 1);

    if n < 2 || pxlPerCm <= 0 || frameRate <= 0
        Xout = X; Yout = Y; return;
    end

    dx = diff(X);
    dy = diff(Y);
    dispCm = sqrt(dx.^2 + dy.^2) / pxlPerCm;
    velCmS = dispCm * frameRate;

    % NaN-safe: NaN comparisons -> false; we don't flag from NaN propagation
    overflow = velCmS > maxCmS & isfinite(velCmS);
    badMask(2:end) = overflow;

    Xout = X; Yout = Y;
    Xout(badMask) = NaN;
    Yout(badMask) = NaN;
end
