"""Pure geometry helpers ported from +sphynx/+util."""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass

import numpy as np
from numpy.typing import ArrayLike

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


def circle_fit(x: ArrayLike, y: ArrayLike) -> tuple[float, float, float]:
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


@dataclass
class EllipseFit:
    """Result of ellipse_fit. On a non-elliptical conic, most fields are None
    and `status` carries the reason (an explicit, inspected signal)."""

    a: float | None = None
    b: float | None = None
    phi: float | None = None
    X0: float | None = None
    Y0: float | None = None
    X0_in: float | None = None
    Y0_in: float | None = None
    long_axis: float | None = None
    short_axis: float | None = None
    status: str = ""
    ar: float | None = None
    br: float | None = None
    cr: float | None = None
    dr: float | None = None
    er: float | None = None


def ellipse_fit(x, y) -> EllipseFit:
    """Least-squares ellipse fit (Ohad Gal algorithm). Port of
    sphynx.util.ellipseFit. Raises TooFewPointsError for < 5 points; returns an
    EllipseFit with a non-empty `status` for degenerate conics.
    """
    orientation_tolerance = 1e-3
    x = np.asarray(x, dtype=float).ravel()
    y = np.asarray(y, dtype=float).ravel()
    if x.size < 5:
        raise TooFewPointsError(f"Need at least 5 points; got {x.size}")

    mean_x = float(np.mean(x))
    mean_y = float(np.mean(y))
    x = x - mean_x
    y = y - mean_y

    design = np.column_stack([x**2, x * y, y**2, x, y])
    gram = design.T @ design
    try:
        coef = np.sum(design, axis=0) @ np.linalg.inv(gram)
    except np.linalg.LinAlgError:
        return EllipseFit(status="matrix inversion warning")
    if not np.all(np.isfinite(coef)):
        return EllipseFit(status="matrix inversion warning")

    a, b, c, d, e = coef  # numpy float64 scalars (inf on /0, matching MATLAB)
    ar, br, cr, dr, er = float(a), float(b), float(c), float(d), float(e)

    if min(abs(b / a), abs(b / c)) > orientation_tolerance:
        orientation_rad = 0.5 * np.arctan(b / (c - a))
        cos_phi = np.cos(orientation_rad)
        sin_phi = np.sin(orientation_rad)
        a, b, c, d, e = (
            a * cos_phi**2 - b * cos_phi * sin_phi + c * sin_phi**2,
            0.0,
            a * sin_phi**2 + b * cos_phi * sin_phi + c * cos_phi**2,
            d * cos_phi - e * sin_phi,
            d * sin_phi + e * cos_phi,
        )
        mean_x, mean_y = (
            cos_phi * mean_x - sin_phi * mean_y,
            sin_phi * mean_x + cos_phi * mean_y,
        )
    else:
        orientation_rad = 0.0
        cos_phi = 1.0
        sin_phi = 0.0

    test = a * c
    if test == 0:
        return EllipseFit(status="Parabola found", ar=ar, br=br, cr=cr, dr=dr, er=er)
    if test < 0:
        return EllipseFit(status="Hyperbola found", ar=ar, br=br, cr=cr, dr=dr, er=er)

    if a < 0:
        a, c, d, e = -a, -c, -d, -e
    x0 = mean_x - d / 2 / a
    y0 = mean_y - e / 2 / c
    f = 1 + (d**2) / (4 * a) + (e**2) / (4 * c)
    a, b = np.sqrt(f / a), np.sqrt(f / c)
    long_axis = 2 * max(a, b)
    short_axis = 2 * min(a, b)

    rot = np.array([[cos_phi, sin_phi], [-sin_phi, cos_phi]])
    p_in = rot @ np.array([x0, y0])

    return EllipseFit(
        a=float(a), b=float(b), phi=float(orientation_rad),
        X0=float(x0), Y0=float(y0),
        X0_in=float(p_in[0]), Y0_in=float(p_in[1]),
        long_axis=float(long_axis), short_axis=float(short_axis),
        status="", ar=ar, br=br, cr=cr, dr=dr, er=er,
    )
