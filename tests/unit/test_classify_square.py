import numpy as np
import pytest
from matplotlib.path import Path

from sphynx.zones import classify_square
from sphynx.exceptions import SphynxValueError


def _rect(h, w, xc, yc):
    yy, xx = np.mgrid[1 : h + 1, 1 : w + 1]
    pts = np.column_stack([xx.ravel(), yy.ravel()])
    inside = Path(np.column_stack([xc, yc])).contains_points(pts)
    return inside.reshape(h, w)


def test_corners_walls_center_basic():
    xc = [50, 250, 250, 50]
    yc = [50, 50, 150, 150]
    m = _rect(200, 300, xc, yc)
    zones = classify_square(m, strategy="corners-walls-center", pixels_per_cm=5,
                            wall_width_cm=3, corner_points=np.column_stack([xc, yc]))
    names = [z.name for z in zones]
    assert "corners" in names and "walls" in names and "center" in names


def test_arena_touching_frame_edge_walls_and_corners_nonempty():
    xc = [1, 200, 200, 1]
    yc = [1, 1, 100, 100]
    m = np.ones((100, 200), bool)
    zones = classify_square(m, strategy="corners-walls-center", pixels_per_cm=5,
                            wall_width_cm=3, corner_points=np.column_stack([xc, yc]))
    walls = next(z for z in zones if z.name == "walls")
    corners = next(z for z in zones if z.name == "corners")
    assert walls.maskfilled.sum() > 0
    assert corners.maskfilled.sum() > 0


def test_strips_strategy_delegates():
    m = np.zeros((100, 200), bool)
    m[19:80, 19:180] = True
    zones = classify_square(m, strategy="strips", num_strips=3, strip_direction="vertical")
    assert len(zones) == 3
    assert zones[0].name == "strip1"


def test_none_strategy_returns_arena_only():
    m = np.zeros((100, 200), bool)
    m[19:80, 19:180] = True
    zones = classify_square(m, strategy="none")
    assert len(zones) == 1
    assert zones[0].name == "arena"


def test_rejects_unknown_strategy():
    with pytest.raises(SphynxValueError):
        classify_square(np.ones((10, 10), bool), strategy="blah")
