function [Xout, Yout, badMask] = hampelFilter(X, Y, windowSize, nSigma)
% HAMPELFILTER  Outlier detection via Hampel identifier on each axis.
%
%   [Xout, Yout, badMask] = sphynx.preprocess.hampelFilter(X, Y, win, k)
%
%   Wraps `hampel` from Signal Processing Toolbox: each sample is
%   replaced by the local median if it deviates from the local median
%   by more than k * 1.4826 * MAD (k = nSigma).
%
%   Inputs:
%     X, Y       - Nx1 raw position; NaN allowed
%     windowSize - half-window size in samples (Hampel uses 2*win+1 total)
%                  default 7
%     nSigma     - deviation threshold in robust sigmas; default 3
%
%   Returns:
%     Xout, Yout - same shape as input; flagged frames -> NaN
%     badMask    - Nx1 logical (true = flagged on either axis)
%
%   Pre-interpolation only. NaN entries are passed through unchanged
%   in output (and not flagged again).

    if nargin < 3 || isempty(windowSize); windowSize = 7; end
    if nargin < 4 || isempty(nSigma);      nSigma     = 3; end

    X = X(:); Y = Y(:);
    n = numel(X);
    badMask = false(n, 1);

    if n < 3
        Xout = X; Yout = Y; return;
    end

    % `hampel` does not handle NaN gracefully — we operate on a copy with
    % NaNs replaced by the median, then restore NaNs and detect outliers
    % only on samples that were originally finite.
    finiteX = ~isnan(X); finiteY = ~isnan(Y);
    Xtmp = X; Ytmp = Y;
    medX = median(X(finiteX), 'omitnan'); medY = median(Y(finiteY), 'omitnan');
    if isnan(medX); medX = 0; end
    if isnan(medY); medY = 0; end
    Xtmp(~finiteX) = medX;
    Ytmp(~finiteY) = medY;

    [~, outX] = hampel(Xtmp, windowSize, nSigma);
    [~, outY] = hampel(Ytmp, windowSize, nSigma);

    badMask = (outX | outY) & finiteX & finiteY;

    Xout = X; Yout = Y;
    Xout(badMask) = NaN;
    Yout(badMask) = NaN;
end
