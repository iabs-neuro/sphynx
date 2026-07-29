import math

import numpy as np
import pytest

from sphynx.exceptions import SphynxGeometryError
from sphynx.zones.geometry import (
    arena_centroid, mask_centroid, resolve_arena_center, zone_angle,
)


def _block(r0, r1, c0, c1, shape=(20, 20)):
    m = np.zeros(shape, dtype=bool)
    m[r0:r1, c0:c1] = True
    return m


def test_arena_centroid_center_of_block():
    m = _block(5, 15, 5, 15)  # rows 5..14, cols 5..14 -> centroid (9.5, 9.5)
    cx, cy = arena_centroid(m)
    assert cx == pytest.approx(9.5)
    assert cy == pytest.approx(9.5)


def test_arena_centroid_empty_raises():
    with pytest.raises(SphynxGeometryError):
        arena_centroid(np.zeros((5, 5), dtype=bool))


def test_resolve_manual_override():
    m = _block(5, 15, 5, 15)
    assert resolve_arena_center(m, manual=(3.0, 4.0)) == (3.0, 4.0)


def test_resolve_manual_bad_shape_raises():
    m = _block(5, 15, 5, 15)
    with pytest.raises(SphynxGeometryError):
        resolve_arena_center(m, manual=(1.0,))


def test_resolve_auto_falls_to_centroid():
    m = _block(5, 15, 5, 15)
    assert resolve_arena_center(m) == pytest.approx((9.5, 9.5))


def test_zone_angle_cardinals():
    center = (10.0, 10.0)
    assert zone_angle((20.0, 10.0), center) == pytest.approx(0.0)          # east
    assert zone_angle((10.0, 20.0), center) == pytest.approx(math.pi / 2)  # south (y down)
    assert zone_angle((0.0, 10.0), center) == pytest.approx(math.pi)       # west
    assert zone_angle((10.0, 0.0), center) == pytest.approx(-math.pi / 2)  # north


def test_mask_centroid_matches_arena():
    m = _block(0, 10, 0, 4)
    assert mask_centroid(m) == pytest.approx(arena_centroid(m))
