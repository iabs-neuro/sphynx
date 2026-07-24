# Python engine — M2e preprocess orchestrator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Port `clean_body_part`, `per_part_default`, and the per-part orchestrator
`apply_per_part_settings` that ties clean+outlier+interp+smooth together.

**Architecture:** Approach C — mirror MATLAB `+preprocess`. Completes milestone M2.
Depends on all M2b/M2c/M2d functions (interpolate_gaps, smooth_trace,
velocity_jump_filter, hampel_filter, kalman_filter_2d). matplotlib.path replaces
inpolygon; scipy.ndimage.gaussian_filter1d replaces smoothdata 'gaussian'.

**Tech Stack:** Python 3.11+, numpy, pandas, scipy, matplotlib; pytest.

## Global Constraints
- Python at repo ROOT; MATLAB reference under `matlab/` (do not touch). Commands from root.
- No silent fallbacks (§10): unknown smoothing method raises `SphynxValueError`.
- Behavioural parity with MATLAB sources; tests ported from `matlab/tests/unit/`.
- "Bad" frame = NaN raw OR likelihood < threshold OR out of frame bounds; set to NaN.
- TDD: failing test first.

---

### Task 1: preprocess.clean_body_part

**Files:** Create `src/sphynx/preprocess/cleaning.py`; Test `tests/unit/test_clean_body_part.py`.
**Interfaces:** `CleanResult` dataclass (X, Y: np.ndarray; percent_nan,
percent_low_likelihood, percent_bad_combined: float; status: str);
`clean_body_part(raw_x, raw_y, likelihood, frame_width=inf, frame_height=inf,
likelihood_threshold=0.95, missing_threshold_pct=90) -> CleanResult`. Port of `cleanBodyPart.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_clean_body_part.py`:
```python
import numpy as np
import pytest

from sphynx.preprocess.cleaning import clean_body_part, CleanResult


def test_clean_input_unchanged():
    rng = np.random.default_rng(0)
    x = 1 + rng.random(100) * 100
    y = 1 + rng.random(100) * 100
    out = clean_body_part(x, y, np.ones(100))
    assert isinstance(out, CleanResult)
    assert np.array_equal(out.X, x)
    assert out.status == "Good"
    assert out.percent_bad_combined == 0


def test_nan_input_becomes_nan():
    out = clean_body_part(np.array([10.0, np.nan, 30]), np.array([10.0, 20, 30]), np.ones(3))
    assert np.isnan(out.X[1]) and np.isnan(out.Y[1])


def test_low_likelihood_masked():
    out = clean_body_part(np.array([10.0, 20, 30]), np.array([10.0, 20, 30]),
                          np.array([0.99, 0.5, 0.99]), likelihood_threshold=0.95)
    assert np.isnan(out.X[1])
    assert out.percent_low_likelihood == pytest.approx(round(100 / 3, 2))


def test_out_of_bounds_masked():
    out = clean_body_part(np.array([10.0, 200, 30]), np.array([10.0, 20, 30]),
                          np.ones(3), frame_width=100, frame_height=100)
    assert np.isnan(out.X[1])


def test_status_not_found_when_mostly_bad():
    out = clean_body_part(np.random.default_rng(1).random(100) * 100,
                          np.random.default_rng(2).random(100) * 100, np.zeros(100))
    assert out.status == "NotFound"
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** `src/sphynx/preprocess/cleaning.py`:
```python
"""Clean a raw DLC trace (NaN/bounds/likelihood mask). Port of
sphynx.preprocess.cleanBodyPart."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np


@dataclass
class CleanResult:
    X: np.ndarray
    Y: np.ndarray
    percent_nan: float
    percent_low_likelihood: float
    percent_bad_combined: float
    status: str


def clean_body_part(
    raw_x, raw_y, likelihood, frame_width=np.inf, frame_height=np.inf,
    likelihood_threshold: float = 0.95, missing_threshold_pct: float = 90,
) -> CleanResult:
    x = np.asarray(raw_x, dtype=float).ravel()
    y = np.asarray(raw_y, dtype=float).ravel()
    lk = np.asarray(likelihood, dtype=float).ravel()
    n = x.size

    is_nan = np.isnan(x) | np.isnan(y)
    low = lk < likelihood_threshold
    out_of_bounds = (x < 1) | (y < 1) | (x > frame_width) | (y > frame_height)
    bad = is_nan | low | out_of_bounds

    xc = x.copy()
    yc = y.copy()
    xc[bad] = np.nan
    yc[bad] = np.nan

    percent_bad = round(100.0 * bad.sum() / n, 2)
    status = "NotFound" if percent_bad > missing_threshold_pct else "Good"
    return CleanResult(
        X=xc, Y=yc,
        percent_nan=round(100.0 * is_nan.sum() / n, 2),
        percent_low_likelihood=round(100.0 * low.sum() / n, 2),
        percent_bad_combined=percent_bad,
        status=status,
    )
```
- [ ] **Step 4: Run — PASS** (5 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/preprocess/cleaning.py tests/unit/test_clean_body_part.py && git commit -m "feat(python): preprocess.clean_body_part"`

---

### Task 2: preprocess.per_part_default (+ PartSettings, PartContext)

**Files:** Create `src/sphynx/preprocess/settings.py`; Test `tests/unit/test_per_part_default.py`.
**Interfaces:** `PartSettings` dataclass (likelihood_threshold, smooth_window_sec,
interpolation_method, smoothing_method, smoothing_poly_order, not_found_threshold_pct);
`PartContext` dataclass (frame_width, frame_height, frame_rate, pixels_per_cm, x_kcorr,
part_name, outlier, manual_regions); `per_part_default(part_name, config=None) ->
PartSettings`. Port of `perPartDefault.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_per_part_default.py`:
```python
from sphynx.preprocess.settings import per_part_default, PartSettings
from sphynx.config import Config


def test_big_vs_small_window():
    cfg = Config.default()
    s_big = per_part_default("bodycenter", cfg)
    s_small = per_part_default("nose", cfg)
    assert s_big.smooth_window_sec == cfg.preprocess.smooth_window_big_sec
    assert s_small.smooth_window_sec == cfg.preprocess.smooth_window_small_sec


def test_defaults_from_config():
    s = per_part_default("nose")
    assert isinstance(s, PartSettings)
    assert s.likelihood_threshold == 0.95
    assert s.smoothing_method == "sgolay"
    assert s.not_found_threshold_pct == 90


def test_big_part_case_insensitive():
    # 'mouse_center' is in the big-parts list
    s = per_part_default("MOUSE_CENTER")
    assert s.smooth_window_sec == Config.default().preprocess.smooth_window_big_sec
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** `src/sphynx/preprocess/settings.py`:
```python
"""Per-part preprocessing settings + runtime context. Port of
sphynx.preprocess.perPartDefault (+ the ctx struct fields)."""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

from sphynx.config import Config


@dataclass
class PartSettings:
    likelihood_threshold: float = 0.95
    smooth_window_sec: float = 0.25
    interpolation_method: str = "pchip"
    smoothing_method: str = "sgolay"
    smoothing_poly_order: int = 3
    not_found_threshold_pct: float = 90


@dataclass
class PartContext:
    frame_width: float = np.inf
    frame_height: float = np.inf
    frame_rate: float = 30.0
    pixels_per_cm: float | None = None
    x_kcorr: float = 1.0
    part_name: str = ""
    outlier: dict | None = None
    manual_regions: list | None = None


def per_part_default(part_name, config: Config | None = None) -> PartSettings:
    if config is None:
        config = Config.default()
    pp = config.preprocess.per_part
    is_big = any(str(part_name).lower() == b.lower() for b in pp.big_parts)
    win_sec = (
        config.preprocess.smooth_window_big_sec
        if is_big else config.preprocess.smooth_window_small_sec
    )
    return PartSettings(
        likelihood_threshold=config.preprocess.likelihood_threshold,
        smooth_window_sec=win_sec,
        interpolation_method=config.preprocess.interpolation_method,
        smoothing_method=pp.smoothing_method,
        smoothing_poly_order=pp.smoothing_poly_order,
        not_found_threshold_pct=pp.not_found_threshold_pct,
    )
```
- [ ] **Step 4: Run — PASS** (3 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/preprocess/settings.py tests/unit/test_per_part_default.py && git commit -m "feat(python): preprocess.per_part_default + PartSettings/PartContext"`

---

### Task 3: preprocess.apply_per_part_settings

**Files:** Create `src/sphynx/preprocess/orchestrator.py`; Test `tests/unit/test_apply_per_part_settings.py`.
**Interfaces:** `PartResult` dataclass (x_clean, y_clean, x_interp, y_interp, x_smooth,
y_smooth: np.ndarray; percent_nan, percent_low_likelihood, percent_bad_combined,
percent_outliers, percent_manual: float; status: str);
`apply_per_part_settings(raw_x, raw_y, likelihood, settings: PartSettings,
ctx: PartContext) -> PartResult`. Port of `applyPerPartSettings.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_apply_per_part_settings.py`:
```python
import numpy as np

from sphynx.preprocess.orchestrator import apply_per_part_settings, PartResult
from sphynx.preprocess.settings import per_part_default, PartContext


def _ctx(**kw):
    return PartContext(frame_width=800, frame_height=600, frame_rate=30, **kw)


def test_clean_interp_smooth_pipeline():
    n = 600
    t = np.arange(1, n + 1)
    x = 100 + 0.05 * t**1.5
    y = 200 - 0.02 * t
    lk = np.ones(n) * 0.99
    bad = [49, 50, 51, 199, 200]  # 0-based
    lk[bad] = 0.1
    x[bad] += 50
    y[bad] -= 50
    out = apply_per_part_settings(x, y, lk, per_part_default("nose"), _ctx())
    assert out.status == "Good"
    assert out.x_smooth.size == n and out.y_smooth.size == n
    assert not np.isnan(out.x_smooth).any()
    assert not np.isnan(out.y_smooth).any()
    assert abs(out.x_smooth[49] - x[44]) < 30
    assert abs(out.y_smooth[49] - y[44]) < 30


def test_not_found_when_all_bad():
    n = 200
    rng = np.random.default_rng(0)
    s = per_part_default("nose")
    s.not_found_threshold_pct = 50
    out = apply_per_part_settings(
        rng.standard_normal(n) * 10 + 100, rng.standard_normal(n) * 10 + 100,
        np.zeros(n), s, _ctx())
    assert out.status == "NotFound"
    assert np.isnan(out.x_smooth).all()


def test_all_smoothing_methods_valid():
    n = 300
    x = np.sin(np.arange(1, n + 1) / 20) * 50 + 200
    y = np.cos(np.arange(1, n + 1) / 20) * 50 + 200
    lk = np.ones(n)
    for m in ("sgolay", "movmean", "movmedian", "gaussian", "kalman"):
        s = per_part_default("nose")
        s.smoothing_method = m
        out = apply_per_part_settings(x, y, lk, s, _ctx())
        assert out.x_smooth.size == n, m
        assert not np.isnan(out.x_smooth).any(), m


def test_manual_region_exclusion():
    n = 500
    x = np.linspace(50, 450, n)
    y = np.full(n, 250.0)
    ctx = _ctx(part_name="nose",
               manual_regions=[{"vertices": np.array([[200, 200], [300, 200],
                                                       [300, 300], [200, 300]]),
                                "applies_to": "all"}])
    out = apply_per_part_settings(x, y, np.ones(n), per_part_default("nose"), ctx)
    assert out.percent_bad_combined > 0
    assert out.status == "Good"


def test_manual_region_applies_to_other_part():
    n = 500
    x = np.linspace(50, 450, n)
    y = np.full(n, 250.0)
    ctx = _ctx(part_name="nose",
               manual_regions=[{"vertices": np.array([[200, 200], [300, 200],
                                                       [300, 300], [200, 300]]),
                                "applies_to": "tailbase"}])
    out = apply_per_part_settings(x, y, np.ones(n), per_part_default("nose"), ctx)
    assert out.percent_bad_combined == 0


def test_frame_bounds_clamping_all_oob_not_found():
    n = 100
    s = per_part_default("nose")
    s.likelihood_threshold = 0.5
    out = apply_per_part_settings(np.full(n, 1500.0), np.full(n, 100.0),
                                  np.ones(n), s, _ctx())
    assert out.status == "NotFound"
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** `src/sphynx/preprocess/orchestrator.py`:
```python
"""Per-part preprocessing orchestrator. Port of
sphynx.preprocess.applyPerPartSettings."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd
from matplotlib.path import Path
from scipy.ndimage import gaussian_filter1d

from sphynx.exceptions import SphynxValueError
from sphynx.preprocess.cleaning import clean_body_part
from sphynx.preprocess.filters import hampel_filter, velocity_jump_filter
from sphynx.preprocess.interpolation import interpolate_gaps
from sphynx.preprocess.kalman import kalman_filter_2d
from sphynx.preprocess.settings import PartContext, PartSettings
from sphynx.preprocess.smoothing import smooth_trace


@dataclass
class PartResult:
    x_clean: np.ndarray
    y_clean: np.ndarray
    x_interp: np.ndarray
    y_interp: np.ndarray
    x_smooth: np.ndarray
    y_smooth: np.ndarray
    percent_nan: float
    percent_low_likelihood: float
    percent_bad_combined: float
    percent_outliers: float
    percent_manual: float
    status: str


def _make_odd(w: int) -> int:
    w = int(w)
    if w < 3:
        w = 3
    if w % 2 == 0:
        w += 1
    return w


def _clamp(x, lo, hi):
    return np.clip(x, lo, hi)


def _apply_smoothing(x, win, settings: PartSettings):
    if x.size < win:
        return x
    m = settings.smoothing_method.lower()
    if m == "sgolay":
        return smooth_trace(x, win, poly_order=settings.smoothing_poly_order)
    if m == "movmean":
        return pd.Series(x).rolling(win, center=True, min_periods=1).mean().to_numpy()
    if m == "movmedian":
        return pd.Series(x).rolling(win, center=True, min_periods=1).median().to_numpy()
    if m == "gaussian":
        return gaussian_filter1d(x, sigma=max(1.0, win / 5.0))
    raise SphynxValueError(f"Unknown smoothing method: {settings.smoothing_method}")


def apply_per_part_settings(
    raw_x, raw_y, likelihood, settings: PartSettings, ctx: PartContext
) -> PartResult:
    raw_x = np.asarray(raw_x, dtype=float).ravel()
    raw_y = np.asarray(raw_y, dtype=float).ravel()
    likelihood = np.asarray(likelihood, dtype=float).ravel()
    n = raw_x.size

    cleaned = clean_body_part(
        raw_x, raw_y, likelihood,
        frame_width=ctx.frame_width, frame_height=ctx.frame_height,
        likelihood_threshold=settings.likelihood_threshold,
        missing_threshold_pct=settings.not_found_threshold_pct,
    )

    res = PartResult(
        x_clean=cleaned.X, y_clean=cleaned.Y,
        x_interp=np.full(n, np.nan), y_interp=np.full(n, np.nan),
        x_smooth=np.full(n, np.nan), y_smooth=np.full(n, np.nan),
        percent_nan=cleaned.percent_nan,
        percent_low_likelihood=cleaned.percent_low_likelihood,
        percent_bad_combined=cleaned.percent_bad_combined,
        percent_outliers=0.0, percent_manual=0.0, status=cleaned.status,
    )
    if res.status == "NotFound":
        return res

    # --- outlier filters (pre-interp) ---
    outliers = np.zeros(n, dtype=bool)
    o = ctx.outlier or {}
    vj = o.get("velocity_jump") if isinstance(o, dict) else None
    if vj and vj.get("enabled") and ctx.pixels_per_cm:
        res.x_clean, res.y_clean, bad_v = velocity_jump_filter(
            res.x_clean, res.y_clean, ctx.frame_rate, ctx.pixels_per_cm,
            vj.get("max_velocity_cm_s", 50.0), ctx.x_kcorr)
        outliers |= bad_v
    hp = o.get("hampel") if isinstance(o, dict) else None
    if hp and hp.get("enabled"):
        if hp.get("window_sec"):
            hp_win = max(1, round(hp["window_sec"] * ctx.frame_rate))
        else:
            hp_win = hp.get("window_size", 7)
        res.x_clean, res.y_clean, bad_h = hampel_filter(
            res.x_clean, res.y_clean, hp_win, hp.get("n_sigma", 3))
        outliers |= bad_h
    res.percent_outliers = round(100.0 * outliers.sum() / n, 2)

    # --- manual regions ---
    manual = np.zeros(n, dtype=bool)
    for reg in (ctx.manual_regions or []):
        applies = reg.get("applies_to") == "all" or (
            ctx.part_name and reg.get("applies_to", "").lower() == ctx.part_name.lower())
        if not applies:
            continue
        v = np.asarray(reg.get("vertices"))
        if v.size == 0 or v.ndim != 2 or v.shape[1] != 2:
            continue
        pts = np.column_stack([res.x_clean, res.y_clean])
        inside = Path(v).contains_points(pts)
        manual |= inside
        res.x_clean[inside] = np.nan
        res.y_clean[inside] = np.nan
    res.percent_manual = round(100.0 * manual.sum() / n, 2)

    res.percent_bad_combined = round(
        100.0 * (np.isnan(res.x_clean) | np.isnan(res.y_clean)).sum() / n, 2)

    # --- interpolate ---
    res.x_interp = interpolate_gaps(res.x_clean, method=settings.interpolation_method)
    res.y_interp = interpolate_gaps(res.y_clean, method=settings.interpolation_method)
    res.x_interp = _clamp(res.x_interp, 1, ctx.frame_width)
    res.y_interp = _clamp(res.y_interp, 1, ctx.frame_height)

    # --- smooth ---
    win = _make_odd(round(ctx.frame_rate * settings.smooth_window_sec))
    if settings.smoothing_method.lower() == "kalman":
        kp = {"process_noise": 1e-2, "meas_noise_scale": 1.0}
        if isinstance(o, dict) and isinstance(o.get("kalman"), dict):
            kp.update(o["kalman"])
        res.x_smooth, res.y_smooth = kalman_filter_2d(
            res.x_interp, res.y_interp, likelihood,
            kp["process_noise"], kp["meas_noise_scale"])
    else:
        res.x_smooth = _apply_smoothing(res.x_interp, win, settings)
        res.y_smooth = _apply_smoothing(res.y_interp, win, settings)

    res.x_smooth = _clamp(res.x_smooth, 1, ctx.frame_width)
    res.y_smooth = _clamp(res.y_smooth, 1, ctx.frame_height)
    return res
```
- [ ] **Step 4: Run — PASS** (6 passed), then full suite `python -m pytest -q`.
- [ ] **Step 5: Commit** `git add src/sphynx/preprocess/orchestrator.py tests/unit/test_apply_per_part_settings.py && git commit -m "feat(python): preprocess.apply_per_part_settings (per-part orchestrator)"`

---

## Done criteria
- `python -m pytest -q` green (M2d 141 + these). Milestone M2 (preprocess + angles +
  bodyparts) COMPLETE — followed by a whole-branch opus review.
- `sphynx.preprocess.{clean_body_part, per_part_default, apply_per_part_settings}` available.

## Next
- M2 whole-branch opus review (M2a..M2e). Then M3: `zones` + `preset` geometry.
