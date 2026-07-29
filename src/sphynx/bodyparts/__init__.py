"""Body-part identification and geometry."""

from sphynx.bodyparts.center import compute_center
from sphynx.bodyparts.fallbacks import DEFAULT_FALLBACKS
from sphynx.bodyparts.identify import Point, identify_parts
from sphynx.bodyparts.relative import relative_coords
from sphynx.bodyparts.resolve import resolve_part

__all__ = ["Point", "identify_parts", "resolve_part", "compute_center", "relative_coords", "DEFAULT_FALLBACKS"]
