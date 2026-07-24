"""Per-part preprocessing orchestrator. Port of
sphynx.preprocess.applyPerPartSettings."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd
from matplotlib.path import Path
from scipy.ndimage import gaussian_filter1d

from sphynx.exceptions import SphynxValueError
from sphynx.preprocess.cleaning import clean_body_part
from sphynx.preprocess.filters import hampel_filter, velocity_jump_filter
from sphynx.preprocess.interpolation import interpolate_gaps
from sphynx.preprocess.kalman import kalman_filter_2d
from sphynx.preprocess.settings import PartContext, PartSettings
from sphynx.preprocess.smoothing import smooth_trace


@dataclass
class PartResult:
    x_clean: np.ndarray
    y_clean: np.ndarray
    x_interp: np.ndarray
    y_interp: np.ndarray
    x_smooth: np.ndarray
    y_smooth: np.ndarray
    percent_nan: float
    percent_low_likelihood: float
    percent_bad_combined: float
    percent_outliers: float
    percent_manual: float
    status: str


def _make_odd(w: int) -> int:
    w = int(w)
    if w < 3:
        w = 3
    if w % 2 == 0:
        w += 1
    return w


def _clamp(x, lo, hi):
    return np.clip(x, lo, hi)


def _apply_smoothing(x, win, settings: PartSettings):
    if x.size < win:
        return x
    m = settings.smoothing_method.lower()
    if m == "sgolay":
        return smooth_trace(x, win, poly_order=settings.smoothing_poly_order)
    if m == "movmean":
        return pd.Series(x).rolling(win, center=True, min_periods=1).mean().to_numpy()
    if m == "movmedian":
        return pd.Series(x).rolling(win, center=True, min_periods=1).median().to_numpy()
    if m == "gaussian":
        return gaussian_filter1d(x, sigma=max(1.0, win / 5.0))
    raise SphynxValueError(f"Unknown smoothing method: {settings.smoothing_method}")


def apply_per_part_settings(
    raw_x, raw_y, likelihood, settings: PartSettings, ctx: PartContext
) -> PartResult:
    raw_x = np.asarray(raw_x, dtype=float).ravel()
    raw_y = np.asarray(raw_y, dtype=float).ravel()
    likelihood = np.asarray(likelihood, dtype=float).ravel()
    n = raw_x.size

    cleaned = clean_body_part(
        raw_x, raw_y, likelihood,
        frame_width=ctx.frame_width, frame_height=ctx.frame_height,
        likelihood_threshold=settings.likelihood_threshold,
        missing_threshold_pct=settings.not_found_threshold_pct,
    )

    res = PartResult(
        x_clean=cleaned.X, y_clean=cleaned.Y,
        x_interp=np.full(n, np.nan), y_interp=np.full(n, np.nan),
        x_smooth=np.full(n, np.nan), y_smooth=np.full(n, np.nan),
        percent_nan=cleaned.percent_nan,
        percent_low_likelihood=cleaned.percent_low_likelihood,
        percent_bad_combined=cleaned.percent_bad_combined,
        percent_outliers=0.0, percent_manual=0.0, status=cleaned.status,
    )
    if res.status == "NotFound":
        return res

    # --- outlier filters (pre-interp) ---
    outliers = np.zeros(n, dtype=bool)
    o = ctx.outlier or {}
    vj = o.get("velocity_jump") if isinstance(o, dict) else None
    if vj and vj.get("enabled") and ctx.pixels_per_cm:
        res.x_clean, res.y_clean, bad_v = velocity_jump_filter(
            res.x_clean, res.y_clean, ctx.frame_rate, ctx.pixels_per_cm,
            vj.get("max_velocity_cm_s", 50.0), ctx.x_kcorr)
        outliers |= bad_v
    hp = o.get("hampel") if isinstance(o, dict) else None
    if hp and hp.get("enabled"):
        if hp.get("window_sec"):
            hp_win = max(1, round(hp["window_sec"] * ctx.frame_rate))
        else:
            hp_win = hp.get("window_size", 7)
        res.x_clean, res.y_clean, bad_h = hampel_filter(
            res.x_clean, res.y_clean, hp_win, hp.get("n_sigma", 3))
        outliers |= bad_h
    res.percent_outliers = round(100.0 * outliers.sum() / n, 2)

    # --- manual regions ---
    manual = np.zeros(n, dtype=bool)
    for reg in (ctx.manual_regions or []):
        applies = reg.get("applies_to") == "all" or (
            ctx.part_name and reg.get("applies_to", "").lower() == ctx.part_name.lower())
        if not applies:
            continue
        v = np.asarray(reg.get("vertices"))
        if v.size == 0 or v.ndim != 2 or v.shape[1] != 2:
            continue
        pts = np.column_stack([res.x_clean, res.y_clean])
        inside = Path(v).contains_points(pts)
        manual |= inside
        res.x_clean[inside] = np.nan
        res.y_clean[inside] = np.nan
    res.percent_manual = round(100.0 * manual.sum() / n, 2)

    res.percent_bad_combined = round(
        100.0 * (np.isnan(res.x_clean) | np.isnan(res.y_clean)).sum() / n, 2)

    # --- interpolate ---
    res.x_interp = interpolate_gaps(res.x_clean, method=settings.interpolation_method)
    res.y_interp = interpolate_gaps(res.y_clean, method=settings.interpolation_method)
    res.x_interp = _clamp(res.x_interp, 1, ctx.frame_width)
    res.y_interp = _clamp(res.y_interp, 1, ctx.frame_height)

    # --- smooth ---
    win = _make_odd(round(ctx.frame_rate * settings.smooth_window_sec))
    if settings.smoothing_method.lower() == "kalman":
        kp = {"process_noise": 1e-2, "meas_noise_scale": 1.0}
        if isinstance(o, dict) and isinstance(o.get("kalman"), dict):
            kp.update(o["kalman"])
        res.x_smooth, res.y_smooth = kalman_filter_2d(
            res.x_interp, res.y_interp, likelihood,
            kp["process_noise"], kp["meas_noise_scale"])
    else:
        res.x_smooth = _apply_smoothing(res.x_interp, win, settings)
        res.y_smooth = _apply_smoothing(res.y_interp, win, settings)

    res.x_smooth = _clamp(res.x_smooth, 1, ctx.frame_width)
    res.y_smooth = _clamp(res.y_smooth, 1, ctx.frame_height)
    return res
