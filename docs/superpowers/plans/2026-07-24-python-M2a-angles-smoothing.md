# Python engine — M2a angles + smoothing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Port angle utilities (`wrap`, `unwrap_for_smooth`, `head_direction`) and
smoothing helpers (`smooth_derived`, `smooth_trace`) from MATLAB, under TDD.

**Architecture:** Approach C — mirror MATLAB `+angles`, `+util/smoothDerived`,
`+preprocess/smoothTrace`. Start of milestone M2. KEY SIMPLIFICATION: scipy is a
hard dependency, so `scipy.signal.savgol_filter` replaces MATLAB's
sgolayfilt-with-toolbox-absent-fallback — the fallback branches are dropped.

**Tech Stack:** Python 3.11+, numpy, scipy.signal, pandas; pytest.

## Global Constraints
- Python at repo ROOT; MATLAB reference under `matlab/` (do not touch). Commands from root.
- No silent fallbacks (§10): invalid smoothing window raises `SphynxValueError`.
- Behavioural parity with MATLAB `+angles` / `smoothDerived` / `smoothTrace`; tests
  ported from `matlab/tests/unit/wrapTest.m` and `synthetic/headDirectionContinuityTest.m`.
- Angle convention: `wrap` maps into (-pi, pi]; pi stays pi; -pi maps to pi.
- TDD: failing test first.

---

### Task 1: exceptions + angles.wrap

**Files:**
- Modify: `src/sphynx/exceptions.py` (add `SphynxValueError`)
- Create: `src/sphynx/angles.py`
- Test: `tests/unit/test_angles.py`

**Interfaces:**
- Produces: `SphynxValueError(SphynxError)`; `sphynx.angles.wrap(angles) -> np.ndarray`
  (wrap into (-pi, pi]; -pi -> pi). Port of `sphynx.angles.wrap`.

- [ ] **Step 1: Write the failing test** — `tests/unit/test_angles.py`:
```python
import numpy as np
import pytest

from sphynx.angles import wrap


def test_zero_stays_zero():
    assert float(wrap(0.0)) == 0.0


def test_wraps_positive():
    assert float(wrap(3 * np.pi)) == pytest.approx(np.pi, abs=1e-12)
    assert float(wrap(2 * np.pi)) == pytest.approx(0.0, abs=1e-12)


def test_wraps_negative():
    assert float(wrap(-3 * np.pi)) == pytest.approx(np.pi, abs=1e-12)
    assert float(wrap(-2 * np.pi)) == pytest.approx(0.0, abs=1e-12)


def test_in_range_unchanged():
    a = np.array([-np.pi + 0.01, -np.pi / 2, 0, np.pi / 2, np.pi - 0.01])
    assert np.allclose(wrap(a), a, atol=1e-12)


def test_vectorized():
    out = wrap(np.array([3 * np.pi, -3 * np.pi, 0, np.pi / 4]))
    assert np.allclose(out, [np.pi, np.pi, 0, np.pi / 4], atol=1e-12)


def test_pi_stays_pi():
    assert float(wrap(np.pi)) == pytest.approx(np.pi, abs=1e-12)
    assert float(wrap(1000 * np.pi)) == pytest.approx(0.0, abs=1e-9)
```

- [ ] **Step 2: Run — expect FAIL** `python -m pytest tests/unit/test_angles.py -v` (no module `sphynx.angles`).

- [ ] **Step 3: Implement.** Append to `src/sphynx/exceptions.py`:
```python


class SphynxValueError(SphynxError):
    """Invalid parameter value passed to a sphynx function."""
```
Create `src/sphynx/angles.py`:
```python
"""Angle utilities. Ports of sphynx.angles.{wrap,unwrapForSmooth,headDirection}."""

from __future__ import annotations

import numpy as np
from scipy.signal import savgol_filter


def wrap(angles) -> np.ndarray:
    """Wrap angles into (-pi, pi]. pi stays pi; -pi maps to pi. Port of
    sphynx.angles.wrap."""
    a = np.asarray(angles, dtype=float)
    out = a - 2.0 * np.pi * np.floor((a + np.pi) / (2.0 * np.pi))
    return np.where(out == -np.pi, np.pi, out)
```

- [ ] **Step 4: Run — expect PASS** `python -m pytest tests/unit/test_angles.py -v` (6 passed).

- [ ] **Step 5: Commit** `git add src/sphynx/exceptions.py src/sphynx/angles.py tests/unit/test_angles.py && git commit -m "feat(python): angles.wrap + SphynxValueError"`

---

### Task 2: util.smooth_derived

**Files:**
- Create: `src/sphynx/util/smoothing.py`
- Test: `tests/unit/test_smoothing.py`

**Interfaces:**
- Produces: `sphynx.util.smoothing.smooth_derived(trace, window_len) -> np.ndarray`
  NaN-safe centered moving-average for derived signals. `window_len <= 1` or empty
  -> passthrough. Port of `sphynx.util.smoothDerived` (movmean/omitnan).

- [ ] **Step 1: Failing test** — `tests/unit/test_smoothing.py`:
```python
import numpy as np

from sphynx.util.smoothing import smooth_derived


def test_passthrough_when_window_le_1():
    x = np.array([1.0, 5.0, 2.0])
    assert np.allclose(smooth_derived(x, 1), x)


def test_empty_passthrough():
    assert smooth_derived(np.array([]), 5).size == 0


def test_reduces_noise_toward_mean():
    x = np.array([0.0, 10.0, 0.0, 10.0, 0.0, 10.0, 0.0])
    out = smooth_derived(x, 3)
    # interior values pulled toward the local mean (~5), away from 0/10 extremes
    assert out[3] > 2.0
    assert out[3] < 8.0


def test_ignores_nan_in_window():
    x = np.array([2.0, np.nan, 4.0])
    out = smooth_derived(x, 3)
    assert not np.isnan(out).all()
```

- [ ] **Step 2: Run — expect FAIL** (no module).

- [ ] **Step 3: Implement** `src/sphynx/util/smoothing.py`:
```python
"""NaN-safe smoothing for DERIVED signals. Port of sphynx.util.smoothDerived."""

from __future__ import annotations

import numpy as np
import pandas as pd


def smooth_derived(trace, window_len) -> np.ndarray:
    """Centered moving-average that ignores NaN. window_len <= 1 or empty input
    is a passthrough. Fixed generic MA so downstream act metrics stay
    deterministic regardless of the user's per-part smoothing choice."""
    t = np.asarray(trace, dtype=float).ravel()
    if t.size == 0 or window_len is None or window_len <= 1:
        return t
    win = int(round(window_len))
    return (
        pd.Series(t)
        .rolling(window=win, center=True, min_periods=1)
        .mean()
        .to_numpy()
    )
```

- [ ] **Step 4: Run — expect PASS** (4 passed).

- [ ] **Step 5: Commit** `git add src/sphynx/util/smoothing.py tests/unit/test_smoothing.py && git commit -m "feat(python): util.smooth_derived (NaN-safe moving average)"`

---

### Task 3: preprocess.smooth_trace

**Files:**
- Create: `src/sphynx/preprocess/__init__.py`
- Create: `src/sphynx/preprocess/smoothing.py`
- Test: `tests/unit/test_smooth_trace.py`

**Interfaces:**
- Consumes: `sphynx.exceptions.SphynxValueError`; scipy.signal.savgol_filter; pandas.
- Produces: `sphynx.preprocess.smoothing.smooth_trace(trace, window_len,
  poly_order=3) -> np.ndarray`. Edge-aware Savitzky-Golay with anti-symmetric
  mirror padding (Bug-3 fix). Raises `SphynxValueError` for even or `< 3` window;
  returns trace unchanged if shorter than window. Port of
  `sphynx.preprocess.smoothTrace` (scipy replaces sgolayfilt; no toolbox fallback).

- [ ] **Step 1: Failing test** — `tests/unit/test_smooth_trace.py`:
```python
import numpy as np
import pytest

from sphynx.preprocess.smoothing import smooth_trace
from sphynx.exceptions import SphynxValueError


def test_even_window_raises():
    with pytest.raises(SphynxValueError):
        smooth_trace(np.arange(20.0), 4)


def test_too_small_window_raises():
    with pytest.raises(SphynxValueError):
        smooth_trace(np.arange(20.0), 1)


def test_short_trace_passthrough():
    x = np.array([1.0, 2.0, 3.0])
    assert np.allclose(smooth_trace(x, 11), x)


def test_preserves_linear_trend_at_edges():
    # A pure line must come back (nearly) unchanged incl. the endpoints,
    # thanks to anti-symmetric mirror padding (Bug-3).
    x = np.linspace(0.0, 100.0, 200)
    out = smooth_trace(x, 11)
    assert out[0] == pytest.approx(x[0], abs=1e-6)
    assert out[-1] == pytest.approx(x[-1], abs=1e-6)
    assert np.allclose(out, x, atol=1e-6)


def test_interior_nan_filled():
    x = np.linspace(0.0, 50.0, 100)
    x[40:45] = np.nan
    out = smooth_trace(x, 11)
    assert not np.isnan(out).any()
```

- [ ] **Step 2: Run — expect FAIL** (no module).

- [ ] **Step 3: Implement.** `src/sphynx/preprocess/__init__.py`:
```python
"""Preprocessing: trace cleaning, smoothing, velocity, filters."""
```
`src/sphynx/preprocess/smoothing.py`:
```python
"""Edge-aware Savitzky-Golay smoothing. Port of sphynx.preprocess.smoothTrace.
scipy.signal.savgol_filter replaces MATLAB sgolayfilt (no toolbox fallback)."""

from __future__ import annotations

import numpy as np
import pandas as pd
from scipy.signal import savgol_filter

from sphynx.exceptions import SphynxValueError


def smooth_trace(trace, window_len, poly_order: int = 3) -> np.ndarray:
    if window_len % 2 == 0:
        raise SphynxValueError(f"window_len must be odd; got {window_len}")
    if window_len < 3:
        raise SphynxValueError(f"window_len must be >= 3; got {window_len}")

    t = np.asarray(trace, dtype=float).ravel()
    n = t.size
    if n < window_len:
        return t

    poly = min(poly_order, window_len - 1)
    half = (window_len - 1) // 2

    if np.isnan(t).any():
        t = pd.Series(t).interpolate(method="linear").ffill().bfill().to_numpy()
        if np.isnan(t).any():  # whole-NaN trace
            t = np.nan_to_num(t, nan=0.0)

    # Anti-symmetric mirror padding: reflect around each endpoint value so
    # linear trends are preserved across the boundary.
    pad_front = 2.0 * t[0] - t[half:0:-1]
    pad_back = 2.0 * t[-1] - t[-2 : -2 - half : -1]
    padded = np.concatenate([pad_front, t, pad_back])

    smoothed = savgol_filter(padded, window_len, poly)
    return smoothed[half : half + n]
```

- [ ] **Step 4: Run — expect PASS** (5 passed).

- [ ] **Step 5: Commit** `git add src/sphynx/preprocess/__init__.py src/sphynx/preprocess/smoothing.py tests/unit/test_smooth_trace.py && git commit -m "feat(python): preprocess.smooth_trace (edge-aware sgolay)"`

---

### Task 4: angles.unwrap_for_smooth + head_direction (+ rotating-mouse fixture)

**Files:**
- Modify: `src/sphynx/angles.py` (append `unwrap_for_smooth`, `head_direction`)
- Create: `tests/fixtures/__init__.py`
- Create: `tests/fixtures/synthetic.py`
- Test: `tests/unit/test_angles.py` (append)

**Interfaces:**
- Consumes: numpy, scipy.signal.savgol_filter; `sphynx.angles.wrap`.
- Produces:
  `unwrap_for_smooth(angles, window_len, poly_order=3) -> np.ndarray` — unwrap,
  sgolay-smooth (only if `len >= window_len`), re-wrap into (-pi, pi]. Port of
  `sphynx.angles.unwrapForSmooth` (scipy; no toolbox fallback).
  `head_direction(tip_x, tip_y, center_x, center_y, smooth_window) -> np.ndarray`
  — `atan2(tipY-centerY, tipX-centerX)`, unwrap-smoothed if `smooth_window >= 3`
  else wrapped. Port of `sphynx.angles.headDirection`.
  Fixture `make_rotating_mouse_dlc(total_rotation_deg, duration_s, frame_rate=30,
  nose_radius_cm=1.5) -> dict` with `head_tip_x/y`, `head_center_x/y`,
  `frame_rate`, `n_frames`, `expected_total_rotation_rad` (port of
  `sphynx.testing.makeRotatingMouseDLC`).

- [ ] **Step 1: Failing test** — append to `tests/unit/test_angles.py`:
```python
from sphynx.angles import unwrap_for_smooth, head_direction
from tests.fixtures.synthetic import make_rotating_mouse_dlc


def test_unwrap_for_smooth_short_input_returns_wrapped():
    a = np.array([0.1, 0.2, 0.3])
    out = unwrap_for_smooth(a, 11)
    assert out.size == 3
    assert np.all(out >= -np.pi) and np.all(out <= np.pi)


def test_head_direction_no_large_jumps():
    f = make_rotating_mouse_dlc(720, 4)
    hd = head_direction(f["head_tip_x"], f["head_tip_y"],
                        f["head_center_x"], f["head_center_y"], 11)
    from sphynx.angles import wrap
    diffs = wrap(np.diff(hd))
    assert np.max(np.abs(diffs)) < 0.5


def test_head_direction_in_range():
    f = make_rotating_mouse_dlc(720, 4)
    hd = head_direction(f["head_tip_x"], f["head_tip_y"],
                        f["head_center_x"], f["head_center_y"], 11)
    assert np.all(hd >= -np.pi) and np.all(hd <= np.pi)


def test_head_direction_total_rotation():
    f = make_rotating_mouse_dlc(720, 4)
    hd = head_direction(f["head_tip_x"], f["head_tip_y"],
                        f["head_center_x"], f["head_center_y"], 11)
    unwrapped = np.unwrap(hd)
    actual = unwrapped[-1] - unwrapped[0]
    assert actual == pytest.approx(f["expected_total_rotation_rad"], abs=0.2)
```

- [ ] **Step 2: Run — expect FAIL** (`unwrap_for_smooth` / fixture missing).

- [ ] **Step 3: Implement.** `tests/fixtures/__init__.py`: empty.
`tests/fixtures/synthetic.py`:
```python
"""Synthetic DLC fixtures with known ground truth (test-only)."""

from __future__ import annotations

import numpy as np


def make_rotating_mouse_dlc(
    total_rotation_deg, duration_s, frame_rate: float = 30.0, nose_radius_cm: float = 1.5
) -> dict:
    """A mouse rotating uniformly in place. Port of
    sphynx.testing.makeRotatingMouseDLC."""
    n = int(round(duration_s * frame_rate))
    t = np.arange(n) / frame_rate
    ang = np.deg2rad(total_rotation_deg) * t / duration_s
    return {
        "head_center_x": np.zeros(n),
        "head_center_y": np.zeros(n),
        "head_tip_x": nose_radius_cm * np.cos(ang),
        "head_tip_y": nose_radius_cm * np.sin(ang),
        "frame_rate": frame_rate,
        "n_frames": n,
        "expected_total_rotation_rad": np.deg2rad(total_rotation_deg),
    }
```
Append to `src/sphynx/angles.py`:
```python
def unwrap_for_smooth(angles, window_len, poly_order: int = 3) -> np.ndarray:
    """Unwrap a circular signal, Savitzky-Golay smooth it, re-wrap into
    (-pi, pi]. Port of sphynx.angles.unwrapForSmooth (Bug-2 fix)."""
    a = np.asarray(angles, dtype=float).ravel()
    unwrapped = np.unwrap(a)
    if unwrapped.size < window_len:
        smoothed = unwrapped
    else:
        poly = min(poly_order, window_len - 1)
        smoothed = savgol_filter(unwrapped, window_len, poly)
    return wrap(smoothed)


def head_direction(tip_x, tip_y, center_x, center_y, smooth_window) -> np.ndarray:
    """Head-direction angle in (-pi, pi], continuous across +/-pi. Port of
    sphynx.angles.headDirection."""
    tip_x = np.asarray(tip_x, dtype=float).ravel()
    tip_y = np.asarray(tip_y, dtype=float).ravel()
    center_x = np.asarray(center_x, dtype=float).ravel()
    center_y = np.asarray(center_y, dtype=float).ravel()
    raw = np.arctan2(tip_y - center_y, tip_x - center_x)
    if smooth_window >= 3:
        return unwrap_for_smooth(raw, smooth_window)
    return wrap(raw)
```

- [ ] **Step 4: Run — expect PASS** (`python -m pytest tests/unit/test_angles.py -v`, then full suite `python -m pytest -q`).

- [ ] **Step 5: Commit** `git add src/sphynx/angles.py tests/fixtures/__init__.py tests/fixtures/synthetic.py tests/unit/test_angles.py && git commit -m "feat(python): angles.unwrap_for_smooth + head_direction + rotating fixture"`

---

## Done criteria
- `python -m pytest -q` green (M1 47 + angles/smoothing tests).
- `sphynx.angles` (wrap/unwrap_for_smooth/head_direction), `sphynx.util.smoothing`,
  `sphynx.preprocess.smoothing` available; `SphynxValueError` added.

## Next plan
- **M2b:** `preprocess` core — interpolate_gaps, compute_velocity, clean_body_part;
  filters — hampel_filter, velocity_jump_filter, kalman_filter_2d, auto_threshold.
