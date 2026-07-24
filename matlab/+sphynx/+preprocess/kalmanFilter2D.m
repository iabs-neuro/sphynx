function [Xs, Ys] = kalmanFilter2D(X, Y, likelihood, processNoise, measNoiseScale)
% KALMANFILTER2D  Hand-rolled 2D constant-velocity Kalman smoother.
%
%   [Xs, Ys] = sphynx.preprocess.kalmanFilter2D(X, Y, likelihood,
%       processNoise, measNoiseScale)
%
%   State:    [x; y; vx; vy]
%   Transition F (dt = 1 frame, time normalized inside the filter):
%     F = [1 0 1 0; 0 1 0 1; 0 0 1 0; 0 0 0 1]
%   Measurement H = [I_2  0_2x2]
%   Process noise Q   = processNoise * I_4
%   Measurement noise R per-frame is modulated by likelihood:
%     R_k = measNoiseScale / max(0.01, likelihood_k)^2 * I_2
%   So low-likelihood frames have large R -> filter discounts them.
%   At likelihood=1, R = measNoiseScale * I_2.
%   At likelihood=0.05, R = measNoiseScale * 400 * I_2 (heavily discounted).
%
%   Inputs:
%     X, Y         - Nx1 INTERPOLATED position (no NaN expected; but if
%                    any creep through they are treated like a missed
%                    measurement: predict-only step).
%     likelihood   - Nx1 in [0, 1]; defaults to ones(N,1) if empty.
%     processNoise - scalar > 0; default 1e-2
%     measNoiseScale - scalar > 0; default 1
%
%   Returns:
%     Xs, Ys - smoothed position, same shape as X, Y.
%
%   This is a one-pass forward filter, not a Rauch-Tung-Striebel smoother.
%   For our DLC traces (already interpolated, mostly clean) the forward
%   filter is enough and predictable. Replaces sgolay when selected as
%   the smoothing method.

    if nargin < 3 || isempty(likelihood); likelihood = ones(numel(X), 1); end
    if nargin < 4 || isempty(processNoise);   processNoise   = 1e-2; end
    if nargin < 5 || isempty(measNoiseScale); measNoiseScale = 1.0;  end

    X = X(:); Y = Y(:); likelihood = likelihood(:);
    n = numel(X);
    Xs = X; Ys = Y;
    if n < 3; return; end

    % Initialize state from the first finite measurement
    firstFinite = find(~isnan(X) & ~isnan(Y), 1);
    if isempty(firstFinite); return; end
    state = [X(firstFinite); Y(firstFinite); 0; 0];
    P = eye(4) * 10;

    F = [1 0 1 0; 0 1 0 1; 0 0 1 0; 0 0 0 1];
    H = [1 0 0 0; 0 1 0 0];
    Q = eye(4) * processNoise;
    I4 = eye(4);

    for k = 1:n
        % Predict
        state = F * state;
        P = F * P * F' + Q;

        % Update only if measurement available
        if ~isnan(X(k)) && ~isnan(Y(k))
            lk = likelihood(k);
            if isnan(lk); lk = 0.5; end
            r_factor = 1 / max(0.01, lk)^2;
            R = measNoiseScale * r_factor * eye(2);
            S = H * P * H' + R;
            K = P * H' / S;
            innov = [X(k); Y(k)] - H * state;
            state = state + K * innov;
            P = (I4 - K * H) * P;
        end

        Xs(k) = state(1);
        Ys(k) = state(2);
    end
end
