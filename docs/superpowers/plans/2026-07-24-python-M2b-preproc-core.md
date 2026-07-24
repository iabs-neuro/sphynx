# Python engine — M2b preprocess core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Port the outlier/interpolation/velocity chain: `hypot_kcorr`,
`interpolate_gaps`, `compute_velocity`, `hampel_filter`, `velocity_jump_filter`.

**Architecture:** Approach C — mirror MATLAB `+geom/hypotKcorr`, `+preprocess/*`.
Continues M2. scipy replaces Signal-Processing-Toolbox functions (interp1 ->
scipy.interpolate; hampel -> the movmedian rolling-Hampel identifier that MATLAB
itself falls back to). No toolbox-absent branches.

**Tech Stack:** Python 3.11+, numpy, scipy.interpolate, pandas; pytest.

## Global Constraints
- Python at repo ROOT; MATLAB reference under `matlab/` (do not touch). Commands from root.
- No silent fallbacks (§10): non-positive frame_rate/pxl_per_cm and invalid
  method/edge_mode raise `SphynxValueError`.
- Behavioural parity with MATLAB sources; tests ported from `matlab/tests/unit/`.
- `hypot_kcorr(dx,dy,k) = sqrt((dx*k)^2 + dy^2)`; k=1 -> plain hypot.
- TDD: failing test first.

---

### Task 1: geom.hypot_kcorr

**Files:** Create `src/sphynx/geom.py`; Test `tests/unit/test_geom.py`.
**Interfaces:** `sphynx.geom.hypot_kcorr(dx, dy, x_kcorr=1.0) -> np.ndarray`.

- [ ] **Step 1: Failing test** — `tests/unit/test_geom.py`:
```python
import numpy as np

from sphynx.geom import hypot_kcorr


def test_plain_hypot_when_kcorr_one():
    assert hypot_kcorr(3.0, 4.0) == 5.0


def test_stretches_x():
    # dx=1 stretched by 2 -> effective 2; with dy=0 -> 2
    assert hypot_kcorr(1.0, 0.0, 2.0) == 2.0


def test_vectorized():
    d = hypot_kcorr(np.array([3.0, 0.0]), np.array([4.0, 5.0]))
    assert np.allclose(d, [5.0, 5.0])
```
- [ ] **Step 2: Run — FAIL** `python -m pytest tests/unit/test_geom.py -v`.
- [ ] **Step 3: Implement** `src/sphynx/geom.py`:
```python
"""Small geometry helpers. Port of sphynx.geom."""

from __future__ import annotations

import numpy as np


def hypot_kcorr(dx, dy, x_kcorr: float = 1.0) -> np.ndarray:
    """Anisotropy-corrected displacement magnitude: sqrt((dx*x_kcorr)^2 + dy^2).
    x_kcorr == 1 reduces to plain hypot. Port of sphynx.geom.hypotKcorr."""
    dx = np.asarray(dx, dtype=float)
    dy = np.asarray(dy, dtype=float)
    return np.sqrt((dx * x_kcorr) ** 2 + dy**2)
```
- [ ] **Step 4: Run — PASS** (3 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/geom.py tests/unit/test_geom.py && git commit -m "feat(python): geom.hypot_kcorr"`

---

### Task 2: preprocess.interpolate_gaps

**Files:** Create `src/sphynx/preprocess/interpolation.py`; Test `tests/unit/test_interpolate_gaps.py`.
**Interfaces:** `interpolate_gaps(trace, method="pchip", edge_mode="hold") -> np.ndarray`.
Fill NaN gaps; all-NaN -> all-NaN; leading/trailing per edge_mode (hold|extrap|nan).
Raises `SphynxValueError` on bad method/edge_mode. Port of `interpolateGaps.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_interpolate_gaps.py`:
```python
import numpy as np

from sphynx.preprocess.interpolation import interpolate_gaps


def test_no_gaps_unchanged():
    x = np.arange(1.0, 11.0)
    assert np.array_equal(interpolate_gaps(x), x)


def test_fills_interior_gap():
    out = interpolate_gaps(np.array([1.0, 2.0, np.nan, 4.0, 5.0]))
    assert abs(out[2] - 3.0) < 0.5
    assert not np.isnan(out).any()


def test_fills_leading_and_trailing():
    out = interpolate_gaps(np.array([np.nan, np.nan, 3.0, 4.0, 5.0, np.nan, np.nan]))
    assert not np.isnan(out).any()


def test_all_nan_returns_all_nan():
    assert np.isnan(interpolate_gaps(np.full(5, np.nan))).all()


def test_linear_method():
    out = interpolate_gaps(np.array([10.0, np.nan, np.nan, 40.0]), method="linear")
    assert np.allclose(out, [10, 20, 30, 40], atol=1e-9)
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** `src/sphynx/preprocess/interpolation.py`:
```python
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
```
- [ ] **Step 4: Run — PASS** (5 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/preprocess/interpolation.py tests/unit/test_interpolate_gaps.py && git commit -m "feat(python): preprocess.interpolate_gaps"`

---

### Task 3: preprocess.compute_velocity

**Files:** Create `src/sphynx/preprocess/velocity.py`; Test `tests/unit/test_compute_velocity.py`.
**Interfaces:** `compute_velocity(x, y, frame_rate, pxl_per_cm, max_velocity_cm_s=50.0,
smooth_window=11, x_kcorr=1.0) -> np.ndarray`. Velocity (cm/s), outlier-clipped +
smoothed. Raises `SphynxValueError` for non-positive frame_rate/pxl_per_cm or
even/<3 smooth_window. Port of `computeVelocity.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_compute_velocity.py`:
```python
import numpy as np
import pytest

from sphynx.preprocess.velocity import compute_velocity
from sphynx.exceptions import SphynxValueError


def test_stationary_yields_zero():
    x = np.full(100, 50.0)
    y = np.full(100, 50.0)
    v = compute_velocity(x, y, 30, 5)
    assert np.max(v) == pytest.approx(0.0, abs=1e-9)


def test_uniform_motion():
    n = 200
    ppc = 5
    x = np.arange(1, n + 1) * ppc  # 1 cm/frame
    y = np.full(n, 100.0)
    v = compute_velocity(x, y, 30, ppc)
    assert np.mean(v[20:-20]) == pytest.approx(30.0, abs=1.0)


def test_outlier_clipped():
    n = 200
    ppc = 5
    x = np.arange(1, n + 1) * ppc * 10 / 30
    y = np.full(n, 100.0)
    x[99] += 200 * ppc
    v = compute_velocity(x, y, 30, ppc)
    assert np.max(v) <= 50 + 1e-9


def test_requires_positive_pxl_per_cm():
    with pytest.raises(SphynxValueError):
        compute_velocity([1.0, 2, 3], [1.0, 2, 3], 30, 0)


def test_requires_positive_frame_rate():
    with pytest.raises(SphynxValueError):
        compute_velocity([1.0, 2, 3], [1.0, 2, 3], 0, 5)
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** `src/sphynx/preprocess/velocity.py`:
```python
"""Velocity from a position trace, clipped + smoothed. Port of
sphynx.preprocess.computeVelocity."""

from __future__ import annotations

import numpy as np
from scipy.interpolate import interp1d

from sphynx.exceptions import SphynxValueError
from sphynx.geom import hypot_kcorr
from sphynx.util.smoothing import smooth_derived


def compute_velocity(
    x, y, frame_rate, pxl_per_cm, max_velocity_cm_s: float = 50.0,
    smooth_window: int = 11, x_kcorr: float = 1.0,
) -> np.ndarray:
    if not frame_rate > 0:
        raise SphynxValueError(f"frame_rate must be positive; got {frame_rate}")
    if not pxl_per_cm > 0:
        raise SphynxValueError(f"pxl_per_cm must be positive; got {pxl_per_cm}")
    if smooth_window % 2 == 0 or smooth_window < 3:
        raise SphynxValueError(f"smooth_window must be odd >= 3; got {smooth_window}")

    x = np.asarray(x, dtype=float).ravel()
    y = np.asarray(y, dtype=float).ravel()
    n = x.size

    dx = np.concatenate([[0.0], np.diff(x)])
    dy = np.concatenate([[0.0], np.diff(y)])
    raw_v = hypot_kcorr(dx, dy, x_kcorr) * frame_rate / pxl_per_cm

    cleaned = raw_v.copy()
    cleaned[raw_v > max_velocity_cm_s] = np.nan
    if np.isnan(cleaned).any():
        good = ~np.isnan(cleaned)
        idx = np.arange(n)
        if int(good.sum()) >= 2:
            f = interp1d(idx[good], cleaned[good], kind="linear", fill_value="extrapolate")
            cleaned[~good] = f(idx[~good])
        elif int(good.sum()) == 1:
            cleaned[:] = cleaned[good][0]
        else:
            cleaned[:] = 0.0

    cleaned[cleaned > max_velocity_cm_s] = max_velocity_cm_s
    cleaned[cleaned < 0] = 0.0

    v = np.asarray(smooth_derived(cleaned, smooth_window), dtype=float)
    v[v > max_velocity_cm_s] = max_velocity_cm_s
    v[v < 0] = 0.0
    return v
```
- [ ] **Step 4: Run — PASS** (5 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/preprocess/velocity.py tests/unit/test_compute_velocity.py && git commit -m "feat(python): preprocess.compute_velocity"`

---

### Task 4: preprocess.hampel_filter

**Files:** Create `src/sphynx/preprocess/filters.py`; Test `tests/unit/test_hampel_filter.py`.
**Interfaces:** `hampel_filter(X, Y, window_size=7, n_sigma=3) -> (Xout, Yout, bad_mask)`.
Rolling-Hampel outlier detector (median + MAD over window 2*window_size+1); flagged
frames -> NaN; NaN input passes through unflagged; n<3 -> unchanged. Port of
`hampelFilter.m` (the movmedian identifier MATLAB uses when the toolbox `hampel` is absent).

- [ ] **Step 1: Failing test** — `tests/unit/test_hampel_filter.py`:
```python
import numpy as np

from sphynx.preprocess.filters import hampel_filter


def test_flags_isolated_spike():
    n = 200
    x = np.sin(np.arange(1, n + 1) / 10) * 50 + 100
    y = np.cos(np.arange(1, n + 1) / 10) * 50 + 100
    x[79] = 9999.0
    xo, _, bad = hampel_filter(x, y, 7, 3)
    assert bad[79]
    assert np.isnan(xo[79])


def test_clean_input_nothing_flagged():
    n = 200
    x = np.sin(np.arange(1, n + 1) / 10) * 50 + 100
    y = np.cos(np.arange(1, n + 1) / 10) * 50 + 100
    xo, yo, bad = hampel_filter(x, y, 7, 3)
    assert bad.sum() == 0
    assert np.array_equal(xo, x)
    assert np.array_equal(yo, y)


def test_nan_input_passthrough():
    n = 50
    x = np.arange(1, n + 1) + 100.0
    y = np.arange(1, n + 1) + 100.0
    x[9] = np.nan
    y[9] = np.nan
    xo, yo, bad = hampel_filter(x, y, 5, 3)
    assert np.isnan(xo[9]) and np.isnan(yo[9])
    assert not bad[9]


def test_too_short_unchanged():
    xo, yo, bad = hampel_filter([1.0, 2.0], [1.0, 2.0])
    assert np.array_equal(xo, [1.0, 2.0])
    assert bad.sum() == 0
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** `src/sphynx/preprocess/filters.py`:
```python
"""Pre-interpolation outlier filters. Ports of sphynx.preprocess.hampelFilter
and velocityJumpFilter."""

from __future__ import annotations

import numpy as np
import pandas as pd

from sphynx.geom import hypot_kcorr


def _hampel_mask(v: np.ndarray, window_size: int, n_sigma: float) -> np.ndarray:
    win = 2 * window_size + 1
    s = pd.Series(v)
    med = s.rolling(win, center=True, min_periods=1).median().to_numpy()
    mad = (
        pd.Series(np.abs(v - med))
        .rolling(win, center=True, min_periods=1)
        .median()
        .to_numpy()
    )
    sigma = 1.4826 * mad
    sigma[sigma == 0] = np.finfo(float).eps
    return np.abs(v - med) > n_sigma * sigma


def hampel_filter(X, Y, window_size: int = 7, n_sigma: float = 3):
    """Hampel identifier per axis (median + MAD over a 2*window_size+1 window).
    Flagged frames -> NaN. NaN input passes through unflagged. Port of
    sphynx.preprocess.hampelFilter."""
    X = np.asarray(X, dtype=float).ravel()
    Y = np.asarray(Y, dtype=float).ravel()
    n = X.size
    bad = np.zeros(n, dtype=bool)
    if n < 3:
        return X.copy(), Y.copy(), bad

    finite_x = ~np.isnan(X)
    finite_y = ~np.isnan(Y)
    med_x = np.nanmedian(X[finite_x]) if finite_x.any() else 0.0
    med_y = np.nanmedian(Y[finite_y]) if finite_y.any() else 0.0
    if np.isnan(med_x):
        med_x = 0.0
    if np.isnan(med_y):
        med_y = 0.0
    xt = X.copy()
    yt = Y.copy()
    xt[~finite_x] = med_x
    yt[~finite_y] = med_y

    out_x = _hampel_mask(xt, window_size, n_sigma)
    out_y = _hampel_mask(yt, window_size, n_sigma)
    bad = (out_x | out_y) & finite_x & finite_y

    xo = X.copy()
    yo = Y.copy()
    xo[bad] = np.nan
    yo[bad] = np.nan
    return xo, yo, bad
```
- [ ] **Step 4: Run — PASS** (4 passed). If `test_clean_input_nothing_flagged` fails
  (smooth-sine false positives from the rolling identifier), report it — the fix is
  to widen the effective window or match MAD edge handling; do not weaken the spike test.
- [ ] **Step 5: Commit** `git add src/sphynx/preprocess/filters.py tests/unit/test_hampel_filter.py && git commit -m "feat(python): preprocess.hampel_filter"`

---

### Task 5: preprocess.velocity_jump_filter

**Files:** Modify `src/sphynx/preprocess/filters.py` (append); Test `tests/unit/test_velocity_jump_filter.py`.
**Interfaces:** `velocity_jump_filter(X, Y, frame_rate, pxl_per_cm, max_cm_s=50.0,
x_kcorr=1.0) -> (Xout, Yout, bad_mask)`. Flags the frame AFTER a supra-max
displacement; NaN-safe (no flag from NaN); n<2 or non-positive scale/rate ->
unchanged. Port of `velocityJumpFilter.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_velocity_jump_filter.py`:
```python
import numpy as np

from sphynx.preprocess.filters import velocity_jump_filter


def test_flags_obvious_jump():
    n = 200
    x = np.arange(1.0, n + 1)
    y = np.full(n, 100.0)
    x[49] = 5000.0  # teleport at (0-based) frame 49
    xo, yo, bad = velocity_jump_filter(x, y, 30, 5, 50)
    assert bad[49]  # out
    assert bad[50]  # back
    assert np.isnan(xo[49])
    assert bad.sum() == 2


def test_no_jumps_intact():
    n = 100
    x = np.arange(1.0, n + 1)
    y = np.full(n, 100.0)
    xo, yo, bad = velocity_jump_filter(x, y, 30, 5, 50)
    assert not bad.any()
    assert np.array_equal(xo, x)


def test_nan_safe():
    n = 50
    x = np.arange(1.0, n + 1)
    y = np.full(n, 100.0)
    x[19] = np.nan
    _, _, bad = velocity_jump_filter(x, y, 30, 5, 50)
    assert not bad.any()


def test_too_short_unchanged():
    xo, yo, bad = velocity_jump_filter([10.0, 11.0], [10.0, 11.0], 30, 5, 50)
    assert np.array_equal(xo, [10.0, 11.0])
    assert not bad.any()


def test_flags_index_after_jump():
    n = 100
    x = np.arange(1.0, n + 1)
    y = np.full(n, 100.0)
    x[59] = 9000.0
    _, _, bad = velocity_jump_filter(x, y, 30, 5, 50)
    assert bad[59]
    assert not bad[58]
```
- [ ] **Step 2: Run — FAIL** (`ImportError`).
- [ ] **Step 3: Implement.** Append to `src/sphynx/preprocess/filters.py`:
```python
def velocity_jump_filter(
    X, Y, frame_rate, pxl_per_cm, max_cm_s: float = 50.0, x_kcorr: float = 1.0
):
    """Flag the frame AFTER a between-frame displacement exceeding max_cm_s.
    NaN-safe; n<2 or non-positive scale/rate -> unchanged. Port of
    sphynx.preprocess.velocityJumpFilter."""
    X = np.asarray(X, dtype=float).ravel()
    Y = np.asarray(Y, dtype=float).ravel()
    n = X.size
    bad = np.zeros(n, dtype=bool)
    if n < 2 or pxl_per_cm <= 0 or frame_rate <= 0:
        return X.copy(), Y.copy(), bad

    dx = np.diff(X)
    dy = np.diff(Y)
    disp_cm = hypot_kcorr(dx, dy, x_kcorr) / pxl_per_cm
    vel = disp_cm * frame_rate
    overflow = (vel > max_cm_s) & np.isfinite(vel)
    bad[1:] = overflow

    xo = X.copy()
    yo = Y.copy()
    xo[bad] = np.nan
    yo[bad] = np.nan
    return xo, yo, bad
```
- [ ] **Step 4: Run — PASS** (5 passed), then full suite `python -m pytest -q`.
- [ ] **Step 5: Commit** `git add src/sphynx/preprocess/filters.py tests/unit/test_velocity_jump_filter.py && git commit -m "feat(python): preprocess.velocity_jump_filter"`

---

## Done criteria
- `python -m pytest -q` green (M2a 70 + these).
- `sphynx.geom.hypot_kcorr`, `sphynx.preprocess.{interpolate_gaps, compute_velocity,
  hampel_filter, velocity_jump_filter}` available.

## Next plan
- **M2c:** `preprocess` — clean_body_part, auto_threshold, kalman_filter_2d,
  arena_exclusion_ring, detect_session_start_frame, apply_per_part_settings;
  `bodyparts` — identify_parts, compute_center, resolve_part, relative_coords.
