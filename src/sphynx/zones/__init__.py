"""Zone classification (rings, corners/walls/center, strips)."""

from sphynx.zones.circle import classify_circle
from sphynx.zones.geometry import (
    arena_centroid,
    assign_zone_angles,
    assign_zone_indices,
    mask_centroid,
    resolve_arena_center,
    zone_angle,
)
from sphynx.zones.square import classify_square
from sphynx.zones.strips import Zone, ZoneRoles, partition_strips

__all__ = [
    "Zone",
    "ZoneRoles",
    "partition_strips",
    "classify_circle",
    "classify_square",
    "arena_centroid",
    "mask_centroid",
    "resolve_arena_center",
    "zone_angle",
    "assign_zone_angles",
    "assign_zone_indices",
]
