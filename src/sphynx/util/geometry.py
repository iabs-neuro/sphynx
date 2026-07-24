"""Pure geometry helpers ported from +sphynx/+util."""

from __future__ import annotations

from collections.abc import Sequence

_NAN = float("nan")


def line_through_points(
    p1: Sequence[float], p2: Sequence[float]
) -> tuple[float, float, float]:
    """Return (k, B, x_const) describing the line through p1 and p2.

    y = k*x + B      -> (k, B, nan)
    x = a (vertical) -> (nan, nan, a)
    p1 == p2         -> (nan, nan, nan)
    Port of sphynx.util.getLineEquation.
    """
    x1, y1 = float(p1[0]), float(p1[1])
    x2, y2 = float(p2[0]), float(p2[1])
    if x1 == x2:
        if y1 == y2:
            return (_NAN, _NAN, _NAN)
        return (_NAN, _NAN, x1)
    k = (y1 - y2) / (x1 - x2)
    b = (y2 * x1 - y1 * x2) / (x1 - x2)
    return (k, b, _NAN)


def lines_intersection(
    k1: float, b1: float, k2: float, b2: float
) -> tuple[float, float]:
    """Intersection of y=k1*x+b1 and y=k2*x+b2; parallel -> (nan, nan).

    Port of sphynx.util.linesIntersection.
    """
    if k1 == k2:
        return (_NAN, _NAN)
    x = (b2 - b1) / (k1 - k2)
    y = k1 * x + b1
    return (x, y)
