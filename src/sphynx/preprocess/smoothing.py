"""Edge-aware Savitzky-Golay smoothing. Port of sphynx.preprocess.smoothTrace.
scipy.signal.savgol_filter replaces MATLAB sgolayfilt (no toolbox fallback)."""

from __future__ import annotations

import numpy as np
import pandas as pd
from scipy.signal import savgol_filter

from sphynx.exceptions import SphynxValueError


def smooth_trace(trace, window_len, poly_order: int = 3) -> np.ndarray:
    if int(window_len) != window_len:
        raise SphynxValueError(f"window_len must be an integer; got {window_len}")
    if window_len % 2 == 0:
        raise SphynxValueError(f"window_len must be odd; got {window_len}")
    if window_len < 3:
        raise SphynxValueError(f"window_len must be >= 3; got {window_len}")

    t = np.asarray(trace, dtype=float).ravel()
    n = t.size
    if n < window_len:
        return t

    poly = min(poly_order, window_len - 1)
    half = (window_len - 1) // 2

    if np.isnan(t).any():
        t = pd.Series(t).interpolate(method="linear").ffill().bfill().to_numpy()
        if np.isnan(t).any():  # whole-NaN trace
            t = np.nan_to_num(t, nan=0.0)

    # Anti-symmetric mirror padding: reflect around each endpoint value so
    # linear trends are preserved across the boundary.
    pad_front = 2.0 * t[0] - t[half:0:-1]
    pad_back = 2.0 * t[-1] - t[-2 : -2 - half : -1]
    padded = np.concatenate([pad_front, t, pad_back])

    smoothed = savgol_filter(padded, window_len, poly)
    return smoothed[half : half + n]
