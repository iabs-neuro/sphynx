"""Clean a raw DLC trace (NaN/bounds/likelihood mask). Port of
sphynx.preprocess.cleanBodyPart."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np


@dataclass
class CleanResult:
    X: np.ndarray
    Y: np.ndarray
    percent_nan: float
    percent_low_likelihood: float
    percent_bad_combined: float
    status: str


def clean_body_part(
    raw_x, raw_y, likelihood, frame_width=np.inf, frame_height=np.inf,
    likelihood_threshold: float = 0.95, missing_threshold_pct: float = 90,
) -> CleanResult:
    x = np.asarray(raw_x, dtype=float).ravel()
    y = np.asarray(raw_y, dtype=float).ravel()
    lk = np.asarray(likelihood, dtype=float).ravel()
    n = x.size

    is_nan = np.isnan(x) | np.isnan(y)
    low = lk < likelihood_threshold
    out_of_bounds = (x < 1) | (y < 1) | (x > frame_width) | (y > frame_height)
    bad = is_nan | low | out_of_bounds

    xc = x.copy()
    yc = y.copy()
    xc[bad] = np.nan
    yc[bad] = np.nan

    percent_bad = round(100.0 * bad.sum() / n, 2)
    status = "NotFound" if percent_bad > missing_threshold_pct else "Good"
    return CleanResult(
        X=xc, Y=yc,
        percent_nan=round(100.0 * is_nan.sum() / n, 2),
        percent_low_likelihood=round(100.0 * low.sum() / n, 2),
        percent_bad_combined=percent_bad,
        status=status,
    )
