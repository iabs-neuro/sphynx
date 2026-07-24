"""Body-center trace. Port of sphynx.bodyparts.computeCenter."""

from __future__ import annotations

import numpy as np

from sphynx.bodyparts.identify import Point


def compute_center(bpx, bpy, point: Point):
    """Resolve the body-center: explicit center row, else mean of
    left+right body center, else NaN-ignored mean of all parts (synthetic).
    Empty input -> empty arrays."""
    bpx = np.asarray(bpx, dtype=float)
    bpy = np.asarray(bpy, dtype=float)
    if bpx.size == 0 or bpy.size == 0:
        return np.zeros(0), np.zeros(0)

    if point.center is not None:
        return bpx[point.center, :], bpy[point.center, :]

    if point.left_body_center is not None and point.right_body_center is not None:
        xc = (bpx[point.left_body_center, :] + bpx[point.right_body_center, :]) / 2.0
        yc = (bpy[point.left_body_center, :] + bpy[point.right_body_center, :]) / 2.0
        return xc, yc

    return np.nanmean(bpx, axis=0), np.nanmean(bpy, axis=0)
