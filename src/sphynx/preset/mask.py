"""Build a border mask from polyline points. Port of
sphynx.preset.maskFromBorder."""

from __future__ import annotations

import numpy as np


def mask_from_border(h: int, w: int, x, y) -> np.ndarray:
    """HxW bool mask, True at each in-bounds rounded (x, y). Coords are
    1-based image coords; out-of-bounds points are skipped."""
    mask = np.zeros((h, w), dtype=bool)
    xi = np.round(np.asarray(x, dtype=float).ravel()).astype(int)
    yi = np.round(np.asarray(y, dtype=float).ravel()).astype(int)
    valid = (xi >= 1) & (xi <= w) & (yi >= 1) & (yi <= h)
    mask[yi[valid] - 1, xi[valid] - 1] = True
    return mask
