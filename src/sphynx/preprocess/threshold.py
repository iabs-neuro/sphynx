"""Suggest a likelihood threshold from the distribution. Port of
sphynx.preprocess.autoThreshold (Otsu hand-rolled; no Image Processing Toolbox)."""

from __future__ import annotations

import numpy as np
import pandas as pd

from sphynx.exceptions import SphynxValueError
from sphynx.logging_setup import get_logger

_LOG = get_logger("sphynx.preprocess")
_FLOOR = 0.4


def _otsu(L: np.ndarray) -> float:
    if np.unique(L).size < 2:
        return 0.95
    hist, edges = np.histogram(L, bins=256, range=(0.0, 1.0))
    centers = (edges[:-1] + edges[1:]) / 2.0
    p = hist.astype(float)
    total = p.sum()
    if total == 0:
        return 0.95
    p /= total
    omega = np.cumsum(p)
    mu = np.cumsum(p * centers)
    mu_t = mu[-1]
    denom = omega * (1.0 - omega)
    with np.errstate(divide="ignore", invalid="ignore"):
        sigma_b = (mu_t * omega - mu) ** 2 / denom
    if not np.isfinite(sigma_b).any():
        return float(np.median(L))
    return float(centers[int(np.nanargmax(sigma_b))])


def _knee(L: np.ndarray) -> float:
    ls = np.sort(L)
    n = ls.size
    if n < 5:
        return 0.95
    win = max(5, round(n / 100))
    if win % 2 == 0:
        win += 1
    lsm = (
        pd.Series(ls).rolling(win, center=True, min_periods=1).mean().to_numpy()
        if n >= win else ls
    )
    d2 = np.diff(np.diff(lsm))
    if d2.size == 0:
        return float(np.median(ls))
    thr = float(lsm[int(np.argmax(np.abs(d2))) + 1])
    if not np.isfinite(thr) or thr <= 0 or thr >= 1:
        thr = float(np.median(ls))
    return thr


def _preset(value) -> float:
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return float(value)
    key = str(value).strip().lower()
    presets = {"aggressive": 0.99, "moderate": 0.95, "lax": 0.60}
    if key in presets:
        return presets[key]
    try:
        return float(value)
    except (TypeError, ValueError):
        raise SphynxValueError(
            f"Unknown preset: {value} (use a number or aggressive/moderate/lax)"
        )


def auto_threshold(likelihood, method: str = "otsu", param=None) -> float:
    L = np.asarray(likelihood, dtype=float).ravel()
    L = L[~np.isnan(L)]
    if L.size == 0:
        return 0.95

    m = str(method).lower()
    if m == "otsu":
        thr = _otsu(L)
    elif m == "knee":
        thr = _knee(L)
    elif m == "quantile":
        thr = float(np.quantile(L, 0.05 if param is None else param))
    elif m == "preset":
        thr = _preset("moderate" if param is None else param)
    else:
        raise SphynxValueError(f"Unknown method: {method}")

    thr = max(0.0, min(1.0, thr))
    if thr < _FLOOR:
        _LOG.warning("autoThreshold[%s] suggested %.3f, clamped to floor %.2f",
                     m, thr, _FLOOR)
        thr = _FLOOR
    return thr
