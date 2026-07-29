"""Split an arena mask into N equal strips. Port of
sphynx.zones.partitionStrips (axis-aligned path)."""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

from sphynx.exceptions import SphynxValueError


@dataclass
class ZoneRoles:
    """Declarative role tags set once at mask-draw time (S2 layer 1)."""

    is_target: bool = False
    tags: list = field(default_factory=list)


@dataclass
class Zone:
    name: str
    type: str
    maskfilled: np.ndarray
    zone_class: str = "unknown"       # hole|object|wall|corner|arena|composite|unknown
    roles: ZoneRoles = field(default_factory=ZoneRoles)
    index: int | None = None          # 1-based position within its zone_class
    angle: float | None = None        # centroid angle rel. arena center, radians


def partition_strips(arena_mask, n, direction: str) -> list[Zone]:
    mask = np.asarray(arena_mask) > 0
    if not float(n).is_integer() or n < 1:
        raise SphynxValueError(f"N must be a positive integer; got {n}")
    n = int(n)
    if direction not in ("horizontal", "vertical"):
        raise SphynxValueError(f"direction must be horizontal|vertical; got {direction}")
    h, w = mask.shape
    if not mask.any():
        raise SphynxValueError("arena_mask is empty")

    ys, xs = np.nonzero(mask)
    zones: list[Zone] = []
    if direction == "horizontal":
        lo0, hi0 = int(ys.min()), int(ys.max())
    else:
        lo0, hi0 = int(xs.min()), int(xs.max())
    span = hi0 - lo0 + 1

    for i in range(n):
        lo = lo0 + round(i * span / n)
        hi = lo0 + round((i + 1) * span / n) - 1
        m = np.zeros((h, w), dtype=bool)
        if direction == "horizontal":
            lo = max(lo, 0)
            hi = min(hi, h - 1)
            m[lo : hi + 1, :] = True
        else:
            lo = max(lo, 0)
            hi = min(hi, w - 1)
            m[:, lo : hi + 1] = True
        zones.append(Zone(f"strip{i + 1}", "area", m & mask))
    return zones
