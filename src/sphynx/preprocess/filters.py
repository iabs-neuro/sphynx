"""Pre-interpolation outlier filters. Ports of sphynx.preprocess.hampelFilter
and velocityJumpFilter."""

from __future__ import annotations

import numpy as np
import pandas as pd

from sphynx.geom import hypot_kcorr


def _hampel_mask(v: np.ndarray, window_size: int, n_sigma: float) -> np.ndarray:
    # Windowed MAD (median |window - window median|), matching MATLAB's
    # builtin hampel semantics -- NOT the lower-quality movmedian-of-
    # pointwise-residuals fallback. A flat window (sigma == 0) is never
    # flagged, since that fallback collapses toward 0 on smooth signals
    # and spuriously flags tiny deviations.
    win = 2 * window_size + 1
    s = pd.Series(v)
    med = s.rolling(win, center=True, min_periods=1).median().to_numpy()
    mad = (
        s.rolling(win, center=True, min_periods=1)
        .apply(lambda w: np.median(np.abs(w - np.median(w))), raw=True)
        .to_numpy()
    )
    sigma = 1.4826 * mad
    with np.errstate(invalid="ignore"):
        return (sigma > 0) & (np.abs(v - med) > n_sigma * sigma)


def hampel_filter(X, Y, window_size: int = 7, n_sigma: float = 3):
    """Hampel identifier per axis (median + MAD over a 2*window_size+1 window).
    Flagged frames -> NaN. NaN input passes through unflagged. Port of
    sphynx.preprocess.hampelFilter."""
    X = np.asarray(X, dtype=float).ravel()
    Y = np.asarray(Y, dtype=float).ravel()
    n = X.size
    bad = np.zeros(n, dtype=bool)
    if n < 3:
        return X.copy(), Y.copy(), bad

    finite_x = ~np.isnan(X)
    finite_y = ~np.isnan(Y)
    med_x = np.nanmedian(X[finite_x]) if finite_x.any() else 0.0
    med_y = np.nanmedian(Y[finite_y]) if finite_y.any() else 0.0
    if np.isnan(med_x):
        med_x = 0.0
    if np.isnan(med_y):
        med_y = 0.0
    xt = X.copy()
    yt = Y.copy()
    xt[~finite_x] = med_x
    yt[~finite_y] = med_y

    out_x = _hampel_mask(xt, window_size, n_sigma)
    out_y = _hampel_mask(yt, window_size, n_sigma)
    bad = (out_x | out_y) & finite_x & finite_y

    xo = X.copy()
    yo = Y.copy()
    xo[bad] = np.nan
    yo[bad] = np.nan
    return xo, yo, bad


def velocity_jump_filter(
    X, Y, frame_rate, pxl_per_cm, max_cm_s: float = 50.0, x_kcorr: float = 1.0
):
    """Flag the frame AFTER a between-frame displacement exceeding max_cm_s.
    NaN-safe; n<2 or non-positive scale/rate -> unchanged. Port of
    sphynx.preprocess.velocityJumpFilter."""
    X = np.asarray(X, dtype=float).ravel()
    Y = np.asarray(Y, dtype=float).ravel()
    n = X.size
    bad = np.zeros(n, dtype=bool)
    if n < 2 or pxl_per_cm <= 0 or frame_rate <= 0:
        return X.copy(), Y.copy(), bad

    dx = np.diff(X)
    dy = np.diff(Y)
    disp_cm = hypot_kcorr(dx, dy, x_kcorr) / pxl_per_cm
    vel = disp_cm * frame_rate
    overflow = (vel > max_cm_s) & np.isfinite(vel)
    bad[1:] = overflow

    xo = X.copy()
    yo = Y.copy()
    xo[bad] = np.nan
    yo[bad] = np.nan
    return xo, yo, bad
