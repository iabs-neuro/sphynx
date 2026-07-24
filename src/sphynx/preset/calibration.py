"""Pixels-per-cm calibration from 4 reference points. Port of
sphynx.preset.pixelsPerCm (headless math; interactive ginput path is GUI/S4)."""

from __future__ import annotations

import numpy as np


def pixels_per_cm(points, distances_cm, percent_threshold: float = 3):
    """points: 4x2 [x, y] (pts 1-2 = vertical pair, pts 3-4 = horizontal pair);
    distances_cm: [d_vertical, d_horizontal]. Returns
    (ppc, x_kcorr, pxl_y, pxl_x, diff_pct)."""
    pts = np.asarray(points, dtype=float)
    x = pts[:, 0]
    y = pts[:, 1]
    dist_px_y = abs(y[1] - y[0])
    dist_px_x = abs(x[3] - x[2])
    pxl_y = dist_px_y / distances_cm[0]
    pxl_x = dist_px_x / distances_cm[1]
    diff_pct = abs(pxl_x - pxl_y) / pxl_x * 100.0
    if diff_pct > percent_threshold:
        return pxl_y, pxl_y / pxl_x, pxl_y, pxl_x, diff_pct
    return (pxl_y + pxl_x) / 2.0, 1.0, pxl_y, pxl_x, diff_pct
