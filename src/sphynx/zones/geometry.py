"""Arena center + zone angle geometry (S2 layer 1)."""

from __future__ import annotations

import math

import numpy as np

from sphynx.exceptions import SphynxGeometryError
from sphynx.logging_setup import get_logger

_log = get_logger()


def arena_centroid(mask) -> tuple[float, float]:
    m = np.asarray(mask) > 0
    if not m.any():
        raise SphynxGeometryError("arena mask is empty; cannot compute centroid")
    ys, xs = np.nonzero(m)
    return float(xs.mean()), float(ys.mean())


def mask_centroid(mask) -> tuple[float, float]:
    return arena_centroid(mask)


def resolve_arena_center(mask, manual=None) -> tuple[float, float]:
    if manual is not None:
        seq = list(manual)
        if len(seq) != 2 or not all(np.isreal(v) for v in seq):
            raise SphynxGeometryError(
                f"manual arena center must be (x, y); got {manual!r}")
        return float(seq[0]), float(seq[1])
    return arena_centroid(mask)


def zone_angle(zone_centroid, arena_center) -> float:
    dx = float(zone_centroid[0]) - float(arena_center[0])
    dy = float(zone_centroid[1]) - float(arena_center[1])
    return math.atan2(dy, dx)


def assign_zone_angles(zones, arena_center) -> None:
    for z in zones:
        m = np.asarray(z.maskfilled) > 0
        if not m.any():
            _log.warning('Zone "%s" has an empty mask; angle left None', z.name)
            continue
        z.angle = zone_angle(mask_centroid(m), arena_center)


def assign_zone_indices(zones) -> None:
    counters: dict = {}
    for z in zones:
        counters[z.zone_class] = counters.get(z.zone_class, 0) + 1
        z.index = counters[z.zone_class]
