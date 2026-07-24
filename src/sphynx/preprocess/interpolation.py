"""Fill NaN gaps in a 1D trace. Port of sphynx.preprocess.interpolateGaps."""

from __future__ import annotations

import numpy as np
from scipy.interpolate import CubicSpline, PchipInterpolator, interp1d

from sphynx.exceptions import SphynxValueError


def _interp1(x, y, xq, method: str, extrap: bool) -> np.ndarray:
    if method == "linear":
        if extrap:
            return interp1d(x, y, kind="linear", fill_value="extrapolate")(xq)
        return np.interp(xq, x, y)
    if method == "pchip":
        return PchipInterpolator(x, y, extrapolate=True)(xq)
    if method == "spline":
        return CubicSpline(x, y, extrapolate=True)(xq)
    raise SphynxValueError(f"method must be linear|pchip|spline; got {method}")


def interpolate_gaps(trace, method: str = "pchip", edge_mode: str = "hold") -> np.ndarray:
    if edge_mode not in ("hold", "extrap", "nan"):
        raise SphynxValueError(f"edge_mode must be hold|extrap|nan; got {edge_mode}")
    t = np.asarray(trace, dtype=float).ravel()
    n = t.size
    good = ~np.isnan(t)
    out = t.copy()
    if not good.any() or good.all():
        return out

    first = int(np.argmax(good))
    last = n - 1 - int(np.argmax(good[::-1]))

    if edge_mode == "hold":
        if first > 0:
            out[:first] = t[first]
        if last < n - 1:
            out[last + 1 :] = t[last]
    elif edge_mode == "extrap":
        idx = np.arange(n)
        edge = (idx < first) | (idx > last)
        out[edge] = _interp1(idx[good], t[good], idx[edge], method, extrap=True)
    # edge_mode == "nan": leave edges as NaN

    if first < last:
        interior = np.arange(first, last + 1)
        ig = good[first : last + 1]
        if (~ig).any():
            out[interior[~ig]] = _interp1(
                interior[ig], t[interior[ig]], interior[~ig], method, extrap=False
            )
    return out
