"""Polygon ring OUTSIDE the arena boundary. Port of
sphynx.preprocess.arenaExclusionRing (scipy.ndimage EDT + cv2 contours)."""

from __future__ import annotations

import cv2
import numpy as np
from scipy import ndimage


def arena_exclusion_ring(arena_mask, width_px) -> list[dict]:
    if width_px <= 0:
        return []
    mask = np.asarray(arena_mask) > 0
    # distance from each pixel to nearest arena (True) pixel
    dist_outside = ndimage.distance_transform_edt(~mask)
    ring = (dist_outside > 0) & (dist_outside <= width_px)
    if not ring.any():
        return []
    contours, _ = cv2.findContours(
        ring.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE
    )
    regions: list[dict] = []
    for c in contours:
        v = c.reshape(-1, 2)  # cv2 gives (x, y) already
        if v.shape[0] < 3:
            continue
        regions.append({"vertices": v})
    return regions
