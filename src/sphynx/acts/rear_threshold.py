"""Robust per-session rear threshold from the tailbase->hindlimb sum
distribution. Port of sphynx.acts.autoRearThresholdCm."""

from __future__ import annotations

import numpy as np


def auto_rear_threshold_cm(
    sum_dist_cm, pctl: float = 7, std_k: float = 1.5,
    clamp_min_cm: float = 1.5, clamp_max_cm: float = 3.5,
) -> float:
    s = np.asarray(sum_dist_cm, dtype=float).ravel()
    s = s[np.isfinite(s)]
    if s.size == 0:
        return float("nan")
    pctl_thr = float(np.percentile(s, pctl))
    std = float(np.std(s, ddof=1)) if s.size > 1 else 0.0
    std_thr = float(np.median(s)) - std_k * std
    thr = min(pctl_thr, std_thr)
    return max(clamp_min_cm, min(clamp_max_cm, thr))
