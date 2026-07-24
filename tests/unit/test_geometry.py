import math

from sphynx.util.geometry import line_through_points, lines_intersection


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
