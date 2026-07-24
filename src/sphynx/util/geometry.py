"""Pure geometry helpers ported from +sphynx/+util."""

from __future__ import annotations

from collections.abc import Sequence

import numpy as np

from sphynx.exceptions import (
    DegenerateGeometryError,
    SphynxGeometryError,
    TooFewPointsError,
)

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


def circle_fit(x, y) -> tuple[float, float, float]:
    """Least-squares circle fit through (x, y). Returns (xc, yc, r).

    Solves (x^2+y^2) + a*x + b*y + c = 0, then xc=-a/2, yc=-b/2,
    r=sqrt((a^2+b^2)/4 - c). Port of sphynx.util.circleFit — raises on
    degenerate input rather than returning NaN silently.
    """
    x = np.asarray(x, dtype=float).ravel()
    y = np.asarray(y, dtype=float).ravel()
    if x.size != y.size:
        raise SphynxGeometryError("x and y must have the same length")
    if x.size < 3:
        raise TooFewPointsError(f"Need at least 3 points; got {x.size}")

    a_mat = np.column_stack([x, y, np.ones(x.size)])
    b_vec = -(x**2 + y**2)

    ata = a_mat.T @ a_mat
    cond = np.linalg.cond(ata)
    rcond = 1.0 / cond if np.isfinite(cond) and cond != 0 else 0.0
    if rcond < 1e-12:
        raise DegenerateGeometryError("Points appear collinear; cannot fit a circle")

    sol, *_ = np.linalg.lstsq(a_mat, b_vec, rcond=None)
    a, b, c = float(sol[0]), float(sol[1]), float(sol[2])
    xc = -a / 2.0
    yc = -b / 2.0
    r = float(np.sqrt((a**2 + b**2) / 4.0 - c))
    return (xc, yc, r)
