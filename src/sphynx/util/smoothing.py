"""NaN-safe smoothing for DERIVED signals. Port of sphynx.util.smoothDerived."""

from __future__ import annotations

import numpy as np
import pandas as pd


def smooth_derived(trace, window_len) -> np.ndarray:
    """Centered moving-average that ignores NaN. window_len <= 1 or empty input
    is a passthrough. Fixed generic MA so downstream act metrics stay
    deterministic regardless of the user's per-part smoothing choice."""
    t = np.asarray(trace, dtype=float).ravel()
    if t.size == 0 or window_len is None or window_len <= 1:
        return t
    win = int(round(window_len))
    return (
        pd.Series(t)
        .rolling(window=win, center=True, min_periods=1)
        .mean()
        .to_numpy()
    )
