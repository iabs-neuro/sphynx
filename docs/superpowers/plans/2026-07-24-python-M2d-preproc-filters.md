# Python engine — M2d preprocess filters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Port `auto_threshold`, `kalman_filter_2d`, `detect_session_start_frame`,
`arena_exclusion_ring`.

**Architecture:** Approach C — mirror MATLAB `+preprocess`. Otsu is hand-rolled
(no skimage dep); the distance-transform + contour tracing use scipy.ndimage + cv2
(both already dependencies). Continues M2.

**Tech Stack:** Python 3.11+, numpy, pandas, scipy.ndimage, opencv-python; pytest.

## Global Constraints
- Python at repo ROOT; MATLAB reference under `matlab/` (do not touch). Commands from root.
- No silent fallbacks (§10): unknown auto_threshold method raises `SphynxValueError`.
  auto_threshold's documented safe fallbacks (0.95 on degenerate input, 0.4 floor) are
  intentional, inspected behavior — not silent bugs.
- Behavioural parity with MATLAB sources; tests ported from `matlab/tests/unit/`.
- Frame numbers from `detect_session_start_frame` are 1-BASED (matching read_dlc's
  1-based start_frame); array indices elsewhere are 0-based.
- TDD: failing test first.

---

### Task 1: preprocess.auto_threshold

**Files:** Create `src/sphynx/preprocess/threshold.py`; Test `tests/unit/test_auto_threshold.py`.
**Interfaces:** `auto_threshold(likelihood, method="otsu", param=None) -> float`.
Methods otsu|knee|quantile|preset; clamp [0,1]; 0.4 floor; 0.95 on degenerate.
Raises `SphynxValueError` on unknown method. Port of `autoThreshold.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_auto_threshold.py`:
```python
import numpy as np
import pytest

from sphynx.preprocess.threshold import auto_threshold
from sphynx.exceptions import SphynxValueError

RNG = np.random.default_rng(0)


def _bimodal():
    return np.clip(
        np.concatenate([0.99 + 0.005 * RNG.standard_normal(800),
                        0.20 + 0.05 * RNG.standard_normal(200)]), 0, 1)


def test_otsu_on_bimodal():
    thr = auto_threshold(_bimodal(), "otsu")
    assert 0.3 < thr < 0.95


def test_knee_on_bimodal():
    thr = auto_threshold(_bimodal(), "knee")
    assert 0.0 < thr < 1.0


def test_quantile_floor_and_above():
    L = np.linspace(0, 1, 1000)
    assert auto_threshold(L, "quantile", 0.05) == pytest.approx(0.4, abs=1e-2)
    assert auto_threshold(L, "quantile", 0.5) == pytest.approx(0.5, abs=1e-2)


def test_quantile_default_floored():
    assert auto_threshold(np.linspace(0, 1, 1000), "quantile") == pytest.approx(0.4, abs=1e-2)


def test_preset_keywords():
    L = RNG.random(100)
    assert auto_threshold(L, "preset", "aggressive") == 0.99
    assert auto_threshold(L, "preset", "moderate") == 0.95
    assert auto_threshold(L, "preset", "lax") == 0.60


def test_preset_default():
    assert auto_threshold(RNG.random(100), "preset") == 0.95


def test_preset_numeric():
    assert auto_threshold(RNG.random(100), "preset", 0.9) == pytest.approx(0.9)


def test_empty_fallback():
    assert auto_threshold([], "otsu") == 0.95
    assert auto_threshold([], "knee") == 0.95


def test_all_same_fallback():
    assert 0 <= auto_threshold(np.ones(500), "otsu") <= 1
    assert 0 <= auto_threshold(np.ones(500), "knee") <= 1


def test_unknown_method_raises():
    with pytest.raises(SphynxValueError):
        auto_threshold(RNG.random(100), "foobar")


def test_always_in_range():
    for _ in range(20):
        L = RNG.random(RNG.integers(50, 5000))
        for m in ("otsu", "knee", "quantile", "preset"):
            p = "moderate" if m == "preset" else None
            assert 0 <= auto_threshold(L, m, p) <= 1
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** `src/sphynx/preprocess/threshold.py`:
```python
"""Suggest a likelihood threshold from the distribution. Port of
sphynx.preprocess.autoThreshold (Otsu hand-rolled; no Image Processing Toolbox)."""

from __future__ import annotations

import numpy as np
import pandas as pd

from sphynx.exceptions import SphynxValueError
from sphynx.logging_setup import get_logger

_LOG = get_logger("sphynx.preprocess")
_FLOOR = 0.4


def _otsu(L: np.ndarray) -> float:
    if np.unique(L).size < 2:
        return 0.95
    hist, edges = np.histogram(L, bins=256, range=(0.0, 1.0))
    centers = (edges[:-1] + edges[1:]) / 2.0
    p = hist.astype(float)
    total = p.sum()
    if total == 0:
        return 0.95
    p /= total
    omega = np.cumsum(p)
    mu = np.cumsum(p * centers)
    mu_t = mu[-1]
    denom = omega * (1.0 - omega)
    with np.errstate(divide="ignore", invalid="ignore"):
        sigma_b = (mu_t * omega - mu) ** 2 / denom
    if not np.isfinite(sigma_b).any():
        return float(np.median(L))
    return float(centers[int(np.nanargmax(sigma_b))])


def _knee(L: np.ndarray) -> float:
    ls = np.sort(L)
    n = ls.size
    if n < 5:
        return 0.95
    win = max(5, round(n / 100))
    if win % 2 == 0:
        win += 1
    lsm = (
        pd.Series(ls).rolling(win, center=True, min_periods=1).mean().to_numpy()
        if n >= win else ls
    )
    d2 = np.diff(np.diff(lsm))
    if d2.size == 0:
        return float(np.median(ls))
    thr = float(lsm[int(np.argmax(np.abs(d2))) + 1])
    if not np.isfinite(thr) or thr <= 0 or thr >= 1:
        thr = float(np.median(ls))
    return thr


def _preset(value) -> float:
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return float(value)
    key = str(value).strip().lower()
    presets = {"aggressive": 0.99, "moderate": 0.95, "lax": 0.60}
    if key in presets:
        return presets[key]
    try:
        return float(value)
    except (TypeError, ValueError):
        raise SphynxValueError(
            f"Unknown preset: {value} (use a number or aggressive/moderate/lax)"
        )


def auto_threshold(likelihood, method: str = "otsu", param=None) -> float:
    L = np.asarray(likelihood, dtype=float).ravel()
    L = L[~np.isnan(L)]
    if L.size == 0:
        return 0.95

    m = str(method).lower()
    if m == "otsu":
        thr = _otsu(L)
    elif m == "knee":
        thr = _knee(L)
    elif m == "quantile":
        thr = float(np.quantile(L, 0.05 if param is None else param))
    elif m == "preset":
        thr = _preset("moderate" if param is None else param)
    else:
        raise SphynxValueError(f"Unknown method: {method}")

    thr = max(0.0, min(1.0, thr))
    if thr < _FLOOR:
        _LOG.warning("autoThreshold[%s] suggested %.3f, clamped to floor %.2f",
                     m, thr, _FLOOR)
        thr = _FLOOR
    return thr
```
- [ ] **Step 4: Run — PASS** (11 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/preprocess/threshold.py tests/unit/test_auto_threshold.py && git commit -m "feat(python): preprocess.auto_threshold"`

---

### Task 2: preprocess.kalman_filter_2d

**Files:** Create `src/sphynx/preprocess/kalman.py`; Test `tests/unit/test_kalman_filter_2d.py`.
**Interfaces:** `kalman_filter_2d(X, Y, likelihood=None, process_noise=1e-2,
meas_noise_scale=1.0) -> (Xs, Ys)`. Forward constant-velocity Kalman; low likelihood
inflates R; n<3 -> unchanged. Port of `kalmanFilter2D.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_kalman_filter_2d.py`:
```python
import numpy as np

from sphynx.preprocess.kalman import kalman_filter_2d


def test_smoothes_noisy_track():
    n = 500
    rng = np.random.default_rng(123)
    tx = np.arange(1, n + 1) * 0.5
    ty = np.sin(np.arange(1, n + 1) / 30) * 50 + 100
    ox = tx + rng.standard_normal(n) * 5
    oy = ty + rng.standard_normal(n) * 5
    xs, ys = kalman_filter_2d(ox, oy, np.ones(n), 1e-2, 1)
    assert np.sqrt(np.mean((xs - tx) ** 2)) < np.sqrt(np.mean((ox - tx) ** 2))
    assert np.sqrt(np.mean((ys - ty) ** 2)) < np.sqrt(np.mean((oy - ty) ** 2))


def test_low_likelihood_discounted():
    n = 200
    tx = np.arange(1, n + 1) * 0.5
    ox = tx.copy()
    oy = np.full(n, 100.0)
    lk = np.ones(n)
    ox[99:102] = 1000.0
    lk[99:102] = 0.05
    xs, _ = kalman_filter_2d(ox, oy, lk, 1e-2, 1)
    assert abs(xs[100] - tx[100]) < 50


def test_shape():
    n = 50
    rng = np.random.default_rng(1)
    xs, ys = kalman_filter_2d(rng.standard_normal(n) * 10 + 100,
                              rng.standard_normal(n) * 10 + 100)
    assert xs.size == n and ys.size == n


def test_too_short_unchanged():
    xs, ys = kalman_filter_2d([1.0, 2.0], [3.0, 4.0])
    assert np.array_equal(xs, [1.0, 2.0])
    assert np.array_equal(ys, [3.0, 4.0])
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** `src/sphynx/preprocess/kalman.py`:
```python
"""Forward 2D constant-velocity Kalman smoother. Port of
sphynx.preprocess.kalmanFilter2D."""

from __future__ import annotations

import numpy as np


def kalman_filter_2d(
    X, Y, likelihood=None, process_noise: float = 1e-2, meas_noise_scale: float = 1.0
):
    """State [x, y, vx, vy], dt=1 frame. Measurement noise R scales with
    1/max(0.01, likelihood)^2 so low-likelihood frames are discounted.
    n<3 -> unchanged."""
    X = np.asarray(X, dtype=float).ravel()
    Y = np.asarray(Y, dtype=float).ravel()
    n = X.size
    if likelihood is None or np.size(likelihood) == 0:
        likelihood = np.ones(n)
    else:
        likelihood = np.asarray(likelihood, dtype=float).ravel()

    xs = X.copy()
    ys = Y.copy()
    if n < 3:
        return xs, ys

    finite = ~np.isnan(X) & ~np.isnan(Y)
    if not finite.any():
        return xs, ys
    ff = int(np.argmax(finite))

    state = np.array([X[ff], Y[ff], 0.0, 0.0])
    p = np.eye(4) * 10.0
    f_mat = np.array([[1, 0, 1, 0], [0, 1, 0, 1], [0, 0, 1, 0], [0, 0, 0, 1]], float)
    h = np.array([[1, 0, 0, 0], [0, 1, 0, 0]], float)
    q = np.eye(4) * process_noise
    i4 = np.eye(4)

    for k in range(n):
        state = f_mat @ state
        p = f_mat @ p @ f_mat.T + q
        if not np.isnan(X[k]) and not np.isnan(Y[k]):
            lk = likelihood[k]
            if np.isnan(lk):
                lk = 0.5
            r = meas_noise_scale / max(0.01, lk) ** 2 * np.eye(2)
            s = h @ p @ h.T + r
            gain = p @ h.T @ np.linalg.inv(s)
            innov = np.array([X[k], Y[k]]) - h @ state
            state = state + gain @ innov
            p = (i4 - gain @ h) @ p
        xs[k] = state[0]
        ys[k] = state[1]
    return xs, ys
```
- [ ] **Step 4: Run — PASS** (4 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/preprocess/kalman.py tests/unit/test_kalman_filter_2d.py && git commit -m "feat(python): preprocess.kalman_filter_2d"`

---

### Task 3: preprocess.detect_session_start_frame

**Files:** Create `src/sphynx/preprocess/session.py`; Test `tests/unit/test_detect_session_start.py`.
**Interfaces:** `detect_session_start_frame(dlc, window_frames=30, population_ratio=0.5,
window_fill_ratio=0.5) -> (start_frame, info)`. `dlc` has `.X`, `.Y` (PxN). Returns
1-based start_frame and an info dict (first_populated_frame, total_populated_ratio,
window_frames, threshold, message). Port of `detectSessionStartFrame.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_detect_session_start.py`:
```python
import types

import numpy as np

from sphynx.preprocess.session import detect_session_start_frame


def _dlc(x, y):
    return types.SimpleNamespace(X=x, Y=y)


def test_detects_start_after_absent_prefix():
    n, parts = 100, 2
    x = np.full((parts, n), np.nan)
    y = np.full((parts, n), np.nan)
    x[:, 30:] = 50.0
    y[:, 30:] = 50.0
    start, info = detect_session_start_frame(_dlc(x, y), window_frames=10)
    assert start == 31  # first populated frame (0-based 30) -> 1-based 31
    assert info["message"] == ""
    assert info["first_populated_frame"] == 31


def test_present_from_frame_one():
    x = np.full((2, 50), 10.0)
    y = np.full((2, 50), 10.0)
    start, info = detect_session_start_frame(_dlc(x, y))
    assert start == 1


def test_never_populated_returns_one_with_message():
    x = np.full((2, 40), np.nan)
    y = np.full((2, 40), np.nan)
    start, info = detect_session_start_frame(_dlc(x, y))
    assert start == 1
    assert info["message"] != ""


def test_no_frames_returns_one():
    start, info = detect_session_start_frame(_dlc(np.zeros((2, 0)), np.zeros((2, 0))))
    assert start == 1
    assert info["message"] != ""
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** `src/sphynx/preprocess/session.py`:
```python
"""Detect the session-start frame from a DLC trace. Port of
sphynx.preprocess.detectSessionStartFrame. Frame numbers are 1-based."""

from __future__ import annotations

import numpy as np
import pandas as pd
from pandas.api.indexers import FixedForwardWindowIndexer


def detect_session_start_frame(
    dlc, window_frames: int = 30, population_ratio: float = 0.5,
    window_fill_ratio: float = 0.5,
):
    x = np.asarray(dlc.X, dtype=float)
    y = np.asarray(dlc.Y, dtype=float)
    n_parts, n_frames = x.shape

    info = {
        "first_populated_frame": None,
        "total_populated_ratio": 0.0,
        "window_frames": window_frames,
        "threshold": window_fill_ratio,
        "message": "",
    }
    if n_frames == 0:
        info["message"] = "No frames in DLC trace"
        return 1, info

    populated = (~np.isnan(x)) & (~np.isnan(y)) & (x >= 0) & (y >= 0)
    per_frame = populated.sum(axis=0) / n_parts
    frame_is_in = per_frame >= population_ratio

    if not frame_is_in.any():
        info["message"] = "Animal never reaches PopulationRatio in any frame"
        return 1, info
    first_hit = int(np.argmax(frame_is_in))  # 0-based
    info["first_populated_frame"] = first_hit + 1
    info["total_populated_ratio"] = float(frame_is_in.sum() / n_frames)

    w = int(round(window_frames))
    indexer = FixedForwardWindowIndexer(window_size=w)
    rolling = (
        pd.Series(frame_is_in.astype(float))
        .rolling(indexer, min_periods=1)
        .mean()
        .to_numpy()
    )

    hits = np.flatnonzero(rolling >= window_fill_ratio)
    if hits.size == 0:
        info["message"] = (
            f"No {w}-frame window reaches fill ratio {window_fill_ratio:.2f} "
            f"(peak rolling = {rolling.max():.2f})"
        )
        return 1, info
    candidate = int(hits[0])  # 0-based
    tail = np.flatnonzero(frame_is_in[candidate:])
    start0 = candidate if tail.size == 0 else candidate + int(tail[0])
    return start0 + 1, info  # 1-based
```
- [ ] **Step 4: Run — PASS** (4 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/preprocess/session.py tests/unit/test_detect_session_start.py && git commit -m "feat(python): preprocess.detect_session_start_frame"`

---

### Task 4: preprocess.arena_exclusion_ring

**Files:** Create `src/sphynx/preprocess/arena.py`; Test `tests/unit/test_arena_exclusion_ring.py`.
**Interfaces:** `arena_exclusion_ring(arena_mask, width_px) -> list[dict]` — one dict
per connected ring component, key `"vertices"` (Nx2 [x, y]). Empty list if width<=0 or
no ring. Port of `arenaExclusionRing.m` (scipy.ndimage distance transform + cv2 contours).

- [ ] **Step 1: Failing test** — `tests/unit/test_arena_exclusion_ring.py`:
```python
import numpy as np

from sphynx.preprocess.arena import arena_exclusion_ring


def _circle_mask(h=100, w=100, cx=50, cy=50, r=30):
    yy, xx = np.mgrid[0:h, 0:w]
    return (xx - cx) ** 2 + (yy - cy) ** 2 <= r**2


def test_ring_around_circle():
    regions = arena_exclusion_ring(_circle_mask(), 5)
    assert len(regions) >= 1
    assert max(np.asarray(r["vertices"]).shape[0] for r in regions) > 20


def test_zero_width_empty():
    assert arena_exclusion_ring(_circle_mask(), 0) == []
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** `src/sphynx/preprocess/arena.py`:
```python
"""Polygon ring OUTSIDE the arena boundary. Port of
sphynx.preprocess.arenaExclusionRing (scipy.ndimage EDT + cv2 contours)."""

from __future__ import annotations

import cv2
import numpy as np
from scipy import ndimage


def arena_exclusion_ring(arena_mask, width_px) -> list[dict]:
    if width_px <= 0:
        return []
    mask = np.asarray(arena_mask) > 0
    # distance from each pixel to nearest arena (True) pixel
    dist_outside = ndimage.distance_transform_edt(~mask)
    ring = (dist_outside > 0) & (dist_outside <= width_px)
    if not ring.any():
        return []
    contours, _ = cv2.findContours(
        ring.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE
    )
    regions: list[dict] = []
    for c in contours:
        v = c.reshape(-1, 2)  # cv2 gives (x, y) already
        if v.shape[0] < 3:
            continue
        regions.append({"vertices": v})
    return regions
```
- [ ] **Step 4: Run — PASS** (2 passed), then full suite `python -m pytest -q`.
- [ ] **Step 5: Commit** `git add src/sphynx/preprocess/arena.py tests/unit/test_arena_exclusion_ring.py && git commit -m "feat(python): preprocess.arena_exclusion_ring"`

---

## Done criteria
- `python -m pytest -q` green (M2c 120 + these).
- `sphynx.preprocess.{auto_threshold, kalman_filter_2d, detect_session_start_frame,
  arena_exclusion_ring}` available.

## Next plan
- **M2e:** `clean_body_part` + `apply_per_part_settings` (the per-part orchestrator
  tying likelihood-threshold + outlier + interpolate + smooth). Then the M2
  whole-branch opus review.
