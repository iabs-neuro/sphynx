"""Ring-based zone classification for a round arena.

Three of the app's zone strategies live here, all measuring with a distance
transform and so working on ANY arena outline, not only a round one:

    classify_circle         'circle-rings' -- wall + middle1..N + centre
                            (port of sphynx.zones.classifyCircle)
    classify_circle_wall    'circle' -- wall + centre, the app's DEFAULT
                            (port of sphynx.preset.buildZonesCircleWall)
    classify_circle_center  'circle-with-center' -- a centre disc of a stated
                            diameter, with or without a wall band
                            (port of sphynx.preset.buildZonesCircleCenter)
"""

from __future__ import annotations

import numpy as np
from scipy.ndimage import distance_transform_edt

from sphynx.exceptions import SphynxError, SphynxValueError
from sphynx.zones.strips import Zone


def _checked(arena_mask, pixels_per_cm, wall_width_cm):
    if pixels_per_cm is None or pixels_per_cm <= 0:
        raise SphynxValueError("pixels_per_cm is required")
    if wall_width_cm < 0:
        raise SphynxValueError(f"wall_width_cm must be >= 0; got {wall_width_cm}")
    return np.asarray(arena_mask) > 0


def _distance_from_outside(mask, pad: int):
    """Distance from every arena pixel to the nearest pixel outside it.

    The mask is padded first. Without padding, an arena drawn flush against
    the frame border has no outside pixel on that side, so the whole band
    along it silently comes out as interior rather than wall -- an arena
    filling the frame would lose its wall entirely."""
    padded = np.pad(mask, pad, mode="constant", constant_values=False)
    return padded, distance_transform_edt(padded)


def _unpad(padded_mask, pad: int, shape):
    height, width = shape
    return padded_mask[pad : pad + height, pad : pad + width]


def classify_circle_wall(arena_mask, pixels_per_cm,
                         wall_width_cm: float = 0) -> list[Zone]:
    """'circle': a wall band of the stated width, and everything else.

    Port of buildZonesCircleWall.m -- the strategy the MATLAB app selects by
    default. A zero wall width makes the whole arena the centre, as there."""
    mask = _checked(arena_mask, pixels_per_cm, wall_width_cm)
    if not mask.any():
        return []
    wall_px = wall_width_cm * pixels_per_cm
    if wall_px <= 0:
        return [Zone("center", "area", mask)]

    pad = max(int(round(wall_px)) + 2, 4)
    padded, dist = _distance_from_outside(mask, pad)
    wall = padded & (dist > 0) & (dist <= wall_px)
    center = padded & ~wall

    zones: list[Zone] = []
    if wall.any():
        zones.append(Zone("wall", "area", _unpad(wall, pad, mask.shape)))
    if center.any():
        zones.append(Zone("center", "area", _unpad(center, pad, mask.shape)))
    return zones


def classify_circle_center(arena_mask, pixels_per_cm,
                           center_diameter_cm: float = 20,
                           wall_width_cm: float = 0) -> list[Zone]:
    """'circle-with-center': a concentric centre disc of a stated diameter.

    Port of buildZonesCircleCenter.m. With no wall band the arena splits in
    two and the outer part is named `wall` -- odd, but that is the name the
    legacy presets carry, and renaming it here would silently stop matching
    act definitions written against them."""
    mask = _checked(arena_mask, pixels_per_cm, wall_width_cm)
    if center_diameter_cm is None or center_diameter_cm <= 0:
        raise SphynxValueError(
            f"center_diameter_cm must be > 0; got {center_diameter_cm}")
    if not mask.any():
        return []

    ys, xs = np.nonzero(mask)
    cx, cy = xs.mean(), ys.mean()
    radius = (center_diameter_cm / 2.0) * pixels_per_cm
    grid_y, grid_x = np.mgrid[0 : mask.shape[0], 0 : mask.shape[1]]
    center = (((grid_x - cx) ** 2 + (grid_y - cy) ** 2) <= radius**2) & mask

    zones: list[Zone] = []
    wall_px = wall_width_cm * pixels_per_cm
    if wall_px > 0:
        pad = max(int(round(wall_px)) + 2, 4)
        padded, dist = _distance_from_outside(mask, pad)
        wall = _unpad(padded & (dist > 0) & (dist <= wall_px), pad, mask.shape)
        middle = mask & ~wall & ~center
        if wall.any():
            zones.append(Zone("wall", "area", wall))
        if middle.any():
            zones.append(Zone("middle", "area", middle))
    else:
        outer = mask & ~center
        if outer.any():
            zones.append(Zone("wall", "area", outer))

    if center.any():
        zones.append(Zone("center", "area", center))
    return zones


def classify_circle(
    arena_mask, pixels_per_cm, wall_width_cm: float = 10, middle_width_cm: float = 20,
    min_center_cm: float = 10,  # accepted for compat; no effect on emitted zones
) -> list[Zone]:
    if pixels_per_cm is None or pixels_per_cm <= 0:
        raise SphynxValueError("pixels_per_cm is required")
    if wall_width_cm < 0:
        raise SphynxValueError(f"wall_width_cm must be >= 0; got {wall_width_cm}")
    if middle_width_cm <= 0:
        raise SphynxValueError(f"middle_width_cm must be > 0; got {middle_width_cm}")
    mask = np.asarray(arena_mask) > 0
    h, w = mask.shape
    wall_w = wall_width_cm * pixels_per_cm
    mid_w = middle_width_cm * pixels_per_cm

    pad = max(round(wall_w + mid_w * 4 + 10), 20)
    padded = np.pad(mask, pad, mode="constant", constant_values=False)
    # bwdist(~padded): distance from arena pixels to the outside boundary.
    dist = distance_transform_edt(padded)
    max_dist = dist.max()

    def mk(name, pm):
        return Zone(name, "area", pm[pad : pad + h, pad : pad + w])

    zones: list[Zone] = []
    wall_ring = padded & (dist > 0) & (dist <= wall_w)
    if wall_ring.any():
        zones.append(mk("wall", wall_ring))

    rast_slop = 0.5
    cum = wall_w
    midi = 1
    while cum + mid_w <= max_dist + rast_slop:
        nxt = cum + mid_w
        ring = padded & (dist > cum) & (dist <= nxt)
        if ring.any():
            zones.append(mk(f"middle{midi}", ring))
        cum = nxt
        midi += 1
        if midi > 50:
            raise SphynxError("Computed > 50 middle rings; check input parameters")

    center = padded & (dist > cum)
    if center.any():
        zones.append(mk("center", center))
    return zones
