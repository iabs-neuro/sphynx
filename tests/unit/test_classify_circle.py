import numpy as np
import pytest

from sphynx.zones import classify_circle
from sphynx.exceptions import SphynxValueError


def _circle(h, w, cx, cy, r):
    yy, xx = np.mgrid[1 : h + 1, 1 : w + 1]  # 1-based grid like MATLAB
    return (xx - cx) ** 2 + (yy - cy) ** 2 <= r**2


def test_small_arena_wall_and_center():
    m = _circle(200, 200, 100, 100, 30 * 2)
    names = [z.name for z in classify_circle(m, 2, wall_width_cm=10, middle_width_cm=20)]
    assert "wall" in names and "middle1" in names and "center" in names


def test_large_arena_middle_rings():
    m = _circle(400, 400, 200, 200, 80 * 2)
    names = [z.name for z in classify_circle(m, 2, wall_width_cm=10, middle_width_cm=20)]
    for nm in ("wall", "middle1", "middle2", "middle3", "center"):
        assert nm in names


def test_center_always_added_even_if_narrow():
    m = _circle(200, 200, 100, 100, 15 * 2)
    names = [z.name for z in classify_circle(m, 2, wall_width_cm=10, middle_width_cm=20, min_center_cm=10)]
    assert "wall" in names and "center" in names and "middle1" not in names


def test_zones_partition_arena():
    m = _circle(300, 300, 150, 150, 60 * 2)
    zones = classify_circle(m, 2, wall_width_cm=10, middle_width_cm=20)
    summed = np.zeros_like(m)
    for z in zones:
        assert not (summed & z.maskfilled).any()
        summed |= z.maskfilled
    assert np.array_equal(summed, m)


def test_arena_touching_frame_edge():
    m = _circle(200, 200, 60, 60, 60 * 2)
    zones = classify_circle(m, 2, wall_width_cm=10, middle_width_cm=20)
    wall = next(z for z in zones if z.name == "wall")
    assert wall.maskfilled.sum() > 0


def test_rejects_zero_middle_width():
    m = _circle(200, 200, 100, 100, 30 * 2)
    with pytest.raises(SphynxValueError):
        classify_circle(m, 2, middle_width_cm=0)


def test_rejects_negative_wall_width():
    m = _circle(200, 200, 100, 100, 30 * 2)
    with pytest.raises(SphynxValueError):
        classify_circle(m, 2, wall_width_cm=-1)
