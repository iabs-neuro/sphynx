"""Zone classification (rings, corners/walls/center, strips)."""

from sphynx.zones.circle import classify_circle
from sphynx.zones.square import classify_square
from sphynx.zones.strips import Zone, ZoneRoles, partition_strips

__all__ = ["Zone", "ZoneRoles", "partition_strips", "classify_circle", "classify_square"]
