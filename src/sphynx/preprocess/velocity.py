"""Velocity from a position trace, clipped + smoothed. Port of
sphynx.preprocess.computeVelocity."""

from __future__ import annotations

import numpy as np
from scipy.interpolate import interp1d

from sphynx.exceptions import SphynxValueError
from sphynx.geom import hypot_kcorr
from sphynx.util.smoothing import smooth_derived


def compute_velocity(
    x, y, frame_rate, pxl_per_cm, max_velocity_cm_s: float = 50.0,
    smooth_window: int = 11, x_kcorr: float = 1.0,
) -> np.ndarray:
    if not frame_rate > 0:
        raise SphynxValueError(f"frame_rate must be positive; got {frame_rate}")
    if not pxl_per_cm > 0:
        raise SphynxValueError(f"pxl_per_cm must be positive; got {pxl_per_cm}")
    if smooth_window % 2 == 0 or smooth_window < 3:
        raise SphynxValueError(f"smooth_window must be odd >= 3; got {smooth_window}")

    x = np.asarray(x, dtype=float).ravel()
    y = np.asarray(y, dtype=float).ravel()
    n = x.size

    dx = np.concatenate([[0.0], np.diff(x)])
    dy = np.concatenate([[0.0], np.diff(y)])
    raw_v = hypot_kcorr(dx, dy, x_kcorr) * frame_rate / pxl_per_cm

    cleaned = raw_v.copy()
    cleaned[raw_v > max_velocity_cm_s] = np.nan
    if np.isnan(cleaned).any():
        good = ~np.isnan(cleaned)
        idx = np.arange(n)
        if int(good.sum()) >= 2:
            f = interp1d(idx[good], cleaned[good], kind="linear", fill_value="extrapolate")
            cleaned[~good] = f(idx[~good])
        elif int(good.sum()) == 1:
            cleaned[:] = cleaned[good][0]
        else:
            cleaned[:] = 0.0

    cleaned[cleaned > max_velocity_cm_s] = max_velocity_cm_s
    cleaned[cleaned < 0] = 0.0

    v = np.asarray(smooth_derived(cleaned, smooth_window), dtype=float)
    v[v > max_velocity_cm_s] = max_velocity_cm_s
    v[v < 0] = 0.0
    return v
