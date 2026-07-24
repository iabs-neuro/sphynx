"""Ring-based zone classification for a round arena. Port of
sphynx.zones.classifyCircle."""

from __future__ import annotations

import numpy as np
from scipy.ndimage import distance_transform_edt

from sphynx.exceptions import SphynxError, SphynxValueError
from sphynx.zones.strips import Zone


def classify_circle(
    arena_mask, pixels_per_cm, wall_width_cm: float = 10, middle_width_cm: float = 20,
    min_center_cm: float = 10,  # accepted for compat; no effect on emitted zones
) -> list[Zone]:
    if pixels_per_cm is None or pixels_per_cm <= 0:
        raise SphynxValueError("pixels_per_cm is required")
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
