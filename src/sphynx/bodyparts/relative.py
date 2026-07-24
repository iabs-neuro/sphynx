"""Tailbase-relative polar coords. Port of sphynx.bodyparts.relativeCoords."""

from __future__ import annotations

import numpy as np

from sphynx.angles import wrap
from sphynx.bodyparts.center import compute_center
from sphynx.bodyparts.identify import Point
from sphynx.exceptions import SphynxValueError


def relative_coords(bpx, bpy, point: Point) -> dict:
    """Body parts in tailbase-relative polar coords, body-axis rotated to
    theta=0. Returns {R, Theta, AngleRot}. Raises if tailbase absent."""
    if point.tailbase is None:
        raise SphynxValueError("Point.tailbase is required")
    bpx = np.asarray(bpx, dtype=float)
    bpy = np.asarray(bpy, dtype=float)

    xc, yc = compute_center(bpx, bpy, point)

    rel_x = bpx - bpx[point.tailbase, :]
    rel_y = bpy - bpy[point.tailbase, :]
    theta = np.arctan2(rel_y, rel_x)
    r = np.hypot(rel_x, rel_y)

    if point.center is not None:
        angle_rot = theta[point.center, :]
    else:
        c_rel_x = xc - bpx[point.tailbase, :]
        c_rel_y = yc - bpy[point.tailbase, :]
        angle_rot = np.arctan2(c_rel_y, c_rel_x)

    theta_rotated = wrap(theta - angle_rot)
    return {"R": r, "Theta": theta_rotated, "AngleRot": angle_rot}
