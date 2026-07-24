"""Zone classification for a square/polygon arena (round-corner mode).
Port of sphynx.zones.classifySquare; square-corner mode and strips `_realout`
augmentation deferred to M3b."""

from __future__ import annotations

import numpy as np
from scipy.ndimage import distance_transform_edt

from sphynx.exceptions import SphynxValueError
from sphynx.zones.strips import Zone, partition_strips


def classify_square(
    arena_mask, strategy: str = "corners-walls-center", pixels_per_cm=None,
    wall_width_cm: float = 3, corner_points=None, num_strips: int = 3,
    strip_direction: str = "horizontal", corner_type: str = "round",
) -> list[Zone]:
    mask = np.asarray(arena_mask) > 0
    if strategy == "corners-walls-center":
        return _corners_walls_center(mask, pixels_per_cm, wall_width_cm,
                                     corner_points, corner_type)
    if strategy == "strips":
        return partition_strips(mask, num_strips, strip_direction)
    if strategy == "none":
        return [Zone("arena", "area", mask)]
    raise SphynxValueError(
        f"Strategy must be corners-walls-center|strips|none; got {strategy}")


def _corners_walls_center(mask, pixels_per_cm, wall_width_cm, corner_points, corner_type):
    if pixels_per_cm is None or pixels_per_cm <= 0:
        raise SphynxValueError("pixels_per_cm required for corners-walls-center")
    if corner_points is None or len(corner_points) == 0:
        raise SphynxValueError("corner_points required for corners-walls-center")
    if str(corner_type).lower() == "square":
        raise SphynxValueError("square corner_type not yet ported (round only)")

    cp = np.asarray(corner_points, dtype=float)
    wall_w = wall_width_cm * pixels_per_cm
    corner_w = wall_w * np.sqrt(2.0)
    h, w = mask.shape
    pad = max(round(wall_w + corner_w + 10), 20)
    padded = np.pad(mask, pad, mode="constant", constant_values=False)

    dist_out = distance_transform_edt(padded)          # bwdist(~padded)
    center = padded & (dist_out > wall_w)
    wc = padded & ~center

    def _seed(points):
        s = np.zeros_like(padded)
        for x, y in points:
            cx = round(x) + pad - 1
            cy = round(y) + pad - 1
            if 0 <= cx < padded.shape[1] and 0 <= cy < padded.shape[0]:
                s[cy, cx] = True
        return s

    corners = np.zeros_like(padded)
    for x, y in cp:
        seed = _seed([(x, y)])
        if not seed.any():
            continue
        dfc = distance_transform_edt(~seed)            # bwdist(seed)
        corners |= wc & (dfc <= corner_w)
    walls = wc & ~corners

    bwd_out = distance_transform_edt(~padded)          # bwdist(padded)
    outer_ring = (bwd_out > 0) & (bwd_out <= wall_w)
    arena_realout = padded | outer_ring
    wc_realout = arena_realout & ~center

    corner_seed = _seed(cp)
    dist_to_corner = distance_transform_edt(~corner_seed)
    outer_near_corners = outer_ring & (dist_to_corner <= corner_w)
    outer_near_walls = outer_ring & ~outer_near_corners
    corners_realout = corners | outer_near_corners
    walls_realout = walls | outer_near_walls

    def mk(name, pm):
        return Zone(name, "area", pm[pad : pad + h, pad : pad + w])

    return [
        mk("corners", corners),
        mk("walls", walls),
        mk("walls_and_corners", wc),
        mk("center", center),
        mk("arena_realout", arena_realout),
        mk("corners_realout", corners_realout),
        mk("walls_realout", walls_realout),
        mk("walls_and_corners_realout", wc_realout),
    ]
