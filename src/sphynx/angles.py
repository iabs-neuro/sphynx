"""Angle utilities. Ports of sphynx.angles.{wrap,unwrapForSmooth,headDirection}."""

from __future__ import annotations

import numpy as np
from scipy.signal import savgol_filter

from sphynx.exceptions import SphynxValueError


def wrap(angles) -> np.ndarray:
    """Wrap angles into (-pi, pi]. pi stays pi; -pi maps to pi. Port of
    sphynx.angles.wrap."""
    a = np.asarray(angles, dtype=float)
    out = a - 2.0 * np.pi * np.floor((a + np.pi) / (2.0 * np.pi))
    return np.where(out == -np.pi, np.pi, out)


def unwrap_for_smooth(angles, window_len, poly_order: int = 3) -> np.ndarray:
    """Unwrap a circular signal, Savitzky-Golay smooth it, re-wrap into
    (-pi, pi]. Port of sphynx.angles.unwrapForSmooth (Bug-2 fix)."""
    if window_len % 2 == 0:
        raise SphynxValueError(f"window_len must be odd; got {window_len}")
    if window_len < 3:
        raise SphynxValueError(f"window_len must be >= 3; got {window_len}")

    a = np.asarray(angles, dtype=float).ravel()
    unwrapped = np.unwrap(a)
    if unwrapped.size < window_len:
        smoothed = unwrapped
    else:
        poly = min(poly_order, window_len - 1)
        smoothed = savgol_filter(unwrapped, window_len, poly)
    return wrap(smoothed)


def head_direction(tip_x, tip_y, center_x, center_y, smooth_window) -> np.ndarray:
    """Head-direction angle in (-pi, pi], continuous across +/-pi. Port of
    sphynx.angles.headDirection."""
    tip_x = np.asarray(tip_x, dtype=float).ravel()
    tip_y = np.asarray(tip_y, dtype=float).ravel()
    center_x = np.asarray(center_x, dtype=float).ravel()
    center_y = np.asarray(center_y, dtype=float).ravel()
    raw = np.arctan2(tip_y - center_y, tip_x - center_x)
    if smooth_window >= 3:
        return unwrap_for_smooth(raw, smooth_window)
    return wrap(raw)
