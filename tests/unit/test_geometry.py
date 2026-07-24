import math

import numpy as np
import pytest

from sphynx.util.geometry import line_through_points, lines_intersection, circle_fit
from sphynx.exceptions import (
    SphynxGeometryError, TooFewPointsError, DegenerateGeometryError,
)


def test_line_from_two_points():
    k, b, xc = line_through_points((0, 0), (1, 2))  # y = 2x
    assert k == 2
    assert b == 0
    assert math.isnan(xc)


def test_vertical_line():
    k, b, xc = line_through_points((5, 0), (5, 7))
    assert math.isnan(k)
    assert math.isnan(b)
    assert xc == 5


def test_degenerate_points():
    k, b, xc = line_through_points((3, 4), (3, 4))
    assert math.isnan(k) and math.isnan(b) and math.isnan(xc)


def test_intersection():
    x, y = lines_intersection(1, 0, -1, 4)  # y=x and y=-x+4 -> (2, 2)
    assert x == 2
    assert y == 2


def test_parallel_returns_nan():
    x, y = lines_intersection(2, 1, 2, 3)
    assert math.isnan(x) and math.isnan(y)


def test_fits_unit_circle():
    th = np.linspace(0, 2 * np.pi, 100)
    xc, yc, r = circle_fit(np.cos(th), np.sin(th))
    assert xc == pytest.approx(0.0, abs=1e-9)
    assert yc == pytest.approx(0.0, abs=1e-9)
    assert r == pytest.approx(1.0, abs=1e-9)


def test_fits_offset_circle():
    th = np.linspace(0, 2 * np.pi, 50)
    xc, yc, r = circle_fit(5 + 3 * np.cos(th), -7 + 3 * np.sin(th))
    assert xc == pytest.approx(5.0, abs=1e-9)
    assert yc == pytest.approx(-7.0, abs=1e-9)
    assert r == pytest.approx(3.0, abs=1e-9)


def test_fits_three_non_collinear_points():
    th = np.array([0.0, 2 * np.pi / 3, 4 * np.pi / 3])
    xc, yc, r = circle_fit(np.cos(th), np.sin(th))
    assert xc == pytest.approx(0.0, abs=1e-9)
    assert yc == pytest.approx(0.0, abs=1e-9)
    assert r == pytest.approx(1.0, abs=1e-9)


def test_rejects_too_few_points():
    with pytest.raises(TooFewPointsError):
        circle_fit([0, 1], [0, 0])


def test_rejects_collinear_points():
    with pytest.raises(DegenerateGeometryError):
        circle_fit([0, 1, 2, 3], [0, 0, 0, 0])


def test_rejects_length_mismatch():
    with pytest.raises(SphynxGeometryError):
        circle_fit([0, 1, 2], [0, 1])


from sphynx.util.geometry import ellipse_fit, EllipseFit


def test_fits_axis_aligned_ellipse():
    th = np.linspace(0, 2 * np.pi, 50)
    x = 10 + 5 * np.cos(th)
    y = 20 + 3 * np.sin(th)
    e = ellipse_fit(x, y)
    assert e.status == ""
    assert e.X0_in == pytest.approx(10.0, abs=1e-6)
    assert e.Y0_in == pytest.approx(20.0, abs=1e-6)
    assert sorted([e.a, e.b]) == pytest.approx([3.0, 5.0], abs=1e-6)


def test_fits_circle_as_ellipse():
    th = np.linspace(0, 2 * np.pi, 50)
    x = 4 * np.cos(th)
    y = 4 * np.sin(th)
    e = ellipse_fit(x, y)
    assert e.status == ""
    assert e.a == pytest.approx(4.0, abs=1e-6)
    assert e.b == pytest.approx(4.0, abs=1e-6)


def test_ellipse_rejects_too_few_points():
    with pytest.raises(TooFewPointsError):
        ellipse_fit([1, 2, 3, 4], [1, 2, 3, 4])
