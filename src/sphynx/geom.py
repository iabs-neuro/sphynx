"""Small geometry helpers. Port of sphynx.geom."""

from __future__ import annotations

import numpy as np


def hypot_kcorr(dx, dy, x_kcorr: float = 1.0) -> np.ndarray:
    """Anisotropy-corrected displacement magnitude: sqrt((dx*x_kcorr)^2 + dy^2).
    x_kcorr == 1 reduces to plain hypot. Port of sphynx.geom.hypotKcorr."""
    dx = np.asarray(dx, dtype=float)
    dy = np.asarray(dy, dtype=float)
    return np.sqrt((dx * x_kcorr) ** 2 + dy**2)
