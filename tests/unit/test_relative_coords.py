import numpy as np
import pytest

from sphynx.bodyparts import relative_coords, Point
from sphynx.exceptions import SphynxValueError


def test_tailbase_row_zero_radius():
    bx = np.array([[0.0, 0], [5, 5], [8, 8]])
    by = np.array([[0.0, 0], [0, 0], [0, 0]])
    out = relative_coords(bx, by, Point(tailbase=0, center=1))
    assert np.allclose(out["R"][0, :], [0, 0], atol=1e-9)


def test_center_row_aligned_after_rotation():
    bx = np.array([[0.0, 0], [5, 5]])
    by = np.array([[0.0, 0], [5, 0]])
    out = relative_coords(bx, by, Point(tailbase=0, center=1))
    assert np.allclose(out["Theta"][1, :], [0, 0], atol=1e-9)


def test_angle_rot_matches_body_axis():
    bx = np.array([[0.0], [5]])
    by = np.array([[0.0], [0]])
    out = relative_coords(bx, by, Point(tailbase=0, center=1))
    assert np.allclose(out["AngleRot"], 0.0, atol=1e-9)


def test_fallback_center_from_left_right():
    bx = np.array([[0.0], [-2], [2]])
    by = np.array([[-1.0], [0], [0]])
    out = relative_coords(bx, by, Point(tailbase=0, left_body_center=1, right_body_center=2))
    assert np.allclose(out["AngleRot"], np.pi / 2, atol=1e-9)


def test_no_tailbase_raises():
    with pytest.raises(SphynxValueError):
        relative_coords(np.array([[1.0], [2]]), np.array([[1.0], [2]]),
                        Point(tailbase=None, center=1))
