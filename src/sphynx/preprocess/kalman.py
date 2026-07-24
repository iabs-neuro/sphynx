"""Forward 2D constant-velocity Kalman smoother. Port of
sphynx.preprocess.kalmanFilter2D."""

from __future__ import annotations

import numpy as np


def kalman_filter_2d(
    X, Y, likelihood=None, process_noise: float = 1e-2, meas_noise_scale: float = 1.0
):
    """State [x, y, vx, vy], dt=1 frame. Measurement noise R scales with
    1/max(0.01, likelihood)^2 so low-likelihood frames are discounted.
    n<3 -> unchanged."""
    X = np.asarray(X, dtype=float).ravel()
    Y = np.asarray(Y, dtype=float).ravel()
    n = X.size
    if likelihood is None or np.size(likelihood) == 0:
        likelihood = np.ones(n)
    else:
        likelihood = np.asarray(likelihood, dtype=float).ravel()

    xs = X.copy()
    ys = Y.copy()
    if n < 3:
        return xs, ys

    finite = ~np.isnan(X) & ~np.isnan(Y)
    if not finite.any():
        return xs, ys
    ff = int(np.argmax(finite))

    state = np.array([X[ff], Y[ff], 0.0, 0.0])
    p = np.eye(4) * 10.0
    f_mat = np.array([[1, 0, 1, 0], [0, 1, 0, 1], [0, 0, 1, 0], [0, 0, 0, 1]], float)
    h = np.array([[1, 0, 0, 0], [0, 1, 0, 0]], float)
    q = np.eye(4) * process_noise
    i4 = np.eye(4)

    for k in range(n):
        state = f_mat @ state
        p = f_mat @ p @ f_mat.T + q
        if not np.isnan(X[k]) and not np.isnan(Y[k]):
            lk = likelihood[k]
            if np.isnan(lk):
                lk = 0.5
            r = meas_noise_scale / max(0.01, lk) ** 2 * np.eye(2)
            s = h @ p @ h.T + r
            gain = p @ h.T @ np.linalg.inv(s)
            innov = np.array([X[k], Y[k]]) - h @ state
            state = state + gain @ innov
            p = (i4 - gain @ h) @ p
        xs[k] = state[0]
        ys[k] = state[1]
    return xs, ys
