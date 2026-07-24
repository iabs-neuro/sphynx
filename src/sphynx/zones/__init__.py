"""Zone classification (rings, corners/walls/center, strips)."""

from sphynx.zones.circle import classify_circle
from sphynx.zones.strips import Zone, partition_strips

__all__ = ["Zone", "partition_strips", "classify_circle"]
