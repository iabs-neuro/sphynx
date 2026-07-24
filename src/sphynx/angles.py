"""Angle utilities. Ports of sphynx.angles.{wrap,unwrapForSmooth,headDirection}."""

from __future__ import annotations

import numpy as np
from scipy.signal import savgol_filter


def wrap(angles) -> np.ndarray:
    """Wrap angles into (-pi, pi]. pi stays pi; -pi maps to pi. Port of
    sphynx.angles.wrap."""
    a = np.asarray(angles, dtype=float)
    out = a - 2.0 * np.pi * np.floor((a + np.pi) / (2.0 * np.pi))
    return np.where(out == -np.pi, np.pi, out)
