"""Preset geometry: zone/arena mask construction and calibration."""

from sphynx.preset.calibration import pixels_per_cm
from sphynx.preset.mask import mask_from_border
from sphynx.preset.objects import build_object_zones, inflate_mask

__all__ = ["mask_from_border", "pixels_per_cm", "build_object_zones", "inflate_mask"]
