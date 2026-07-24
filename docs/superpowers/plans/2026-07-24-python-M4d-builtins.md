# Python engine — M4d built-in acts + library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Port the standalone built-in acts the pipeline calls directly — `freezing`
and `rear` — and the default acts library `acts_library_defaults`.

**Architecture:** Approach C — mirror MATLAB `+acts/{freezing,rear,actsLibraryDefaults}`.
Uses refine_act (M4a), hypot_kcorr, smooth_derived, auto_rear_threshold_cm (M4c), and
the Point/Act types. Completes milestone M4. `make_act_context` is deferred to M6 (it
assembles ActContext from the analyzeSession result, which does not exist until M6).

**Tech Stack:** Python 3.11+, numpy; pytest.

## Global Constraints
- Python at repo ROOT; MATLAB reference under `matlab/` (do not touch). Commands from root.
- No silent fallbacks (§10): unknown freezing/rear mode raises `SphynxValueError`; missing
  pixels_per_cm for rear raises. Documented mode degradation (NoseAndCenter/HeadAndCenter ->
  AllBodyParts, TailbasePaws -> AllBodyParts when parts unresolved) is intentional.
- Behavioural parity with MATLAB sources. Point fields are snake_case (from identify_parts).
- TDD: failing test first.

---

### Task 1: acts.freezing (standalone built-in)

**Files:** Create `src/sphynx/acts/builtins.py`; Modify `src/sphynx/acts/__init__.py` (export); Test `tests/unit/test_builtin_freezing.py`.
**Interfaces:** `freezing(body_parts_velocity, point, mode, rest_threshold_cm_s,
min_run_frames) -> np.ndarray`. mode AllBodyParts|NoseAndCenter|HeadAndCenter with
graceful degradation to AllBodyParts. Port of `freezing.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_builtin_freezing.py`:
```python
import numpy as np
import pytest

from sphynx.acts.builtins import freezing
from sphynx.bodyparts import Point
from sphynx.exceptions import SphynxValueError


def test_head_and_center_freeze_band():
    n = 100
    bpv = np.full((2, n), 5.0)
    bpv[:, 10:40] = 0.5   # both parts slow -> freeze
    p = Point(head_center=0, center=1)
    fm = freezing(bpv, p, "HeadAndCenter", 1, 5)
    assert int(fm.sum()) == 30


def test_degrades_to_all_body_parts():
    n = 50
    bpv = np.full((3, n), 0.1)  # sum 0.3 < 1*3
    fm = freezing(bpv, Point(), "HeadAndCenter", 1, 3)  # no head/center -> AllBodyParts
    assert fm.all()


def test_unknown_mode_raises():
    with pytest.raises(SphynxValueError):
        freezing(np.zeros((2, 10)), Point(), "Bogus", 1, 5)
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** `src/sphynx/acts/builtins.py`:
```python
"""Standalone built-in acts called directly by the pipeline (freezing, rear).
Ports of sphynx.acts.freezing and sphynx.acts.rear."""

from __future__ import annotations

import numpy as np

from sphynx.acts.refine import refine_act
from sphynx.acts.rear_threshold import auto_rear_threshold_cm
from sphynx.bodyparts import Point
from sphynx.exceptions import SphynxValueError
from sphynx.geom import hypot_kcorr
from sphynx.util.smoothing import smooth_derived


def freezing(body_parts_velocity, point: Point, mode: str, rest_threshold_cm_s, min_run_frames) -> np.ndarray:
    """Per-frame freezing. mode AllBodyParts|NoseAndCenter|HeadAndCenter; the
    latter two degrade to AllBodyParts when their parts are unresolved."""
    if mode not in ("AllBodyParts", "NoseAndCenter", "HeadAndCenter"):
        raise SphynxValueError(
            f"mode must be AllBodyParts|NoseAndCenter|HeadAndCenter; got {mode}")
    bpv = np.asarray(body_parts_velocity, dtype=float)
    parts, n = bpv.shape

    eff = mode
    if mode == "NoseAndCenter" and (point.nose is None or point.center is None):
        eff = "AllBodyParts"
    elif mode == "HeadAndCenter" and (point.head_center is None or point.center is None):
        eff = "AllBodyParts"

    if eff == "AllBodyParts":
        total_v = bpv.sum(axis=0)
        raw = total_v < rest_threshold_cm_s * parts
    elif eff == "NoseAndCenter":
        raw = (bpv[point.nose, :] < rest_threshold_cm_s * 2) & (
            bpv[point.center, :] < rest_threshold_cm_s)
    else:  # HeadAndCenter
        raw = (bpv[point.head_center, :] < rest_threshold_cm_s) & (
            bpv[point.center, :] < rest_threshold_cm_s)

    refined, _ = refine_act(raw, min_run_frames, min_run_frames)
    return refined
```
Update `src/sphynx/acts/__init__.py` to export `freezing`.
- [ ] **Step 4: Run — PASS** (3 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/acts/builtins.py src/sphynx/acts/__init__.py tests/unit/test_builtin_freezing.py && git commit -m "feat(python): acts.freezing (standalone built-in)"`

---

### Task 2: acts.rear (standalone built-in)

**Files:** Modify `src/sphynx/acts/builtins.py` (append `rear` + `_make_odd`); Modify `src/sphynx/acts/__init__.py` (export); Test `tests/unit/test_builtin_rear.py`.
**Interfaces:** `rear(bpx, bpy, point, mode, pixels_per_cm,
all_body_parts_threshold_pxl=170, tailbase_paws_threshold_cm=2.8, auto_threshold=False,
smooth_window_frames=None, min_run_frames=5, frame_rate=30, x_kcorr=1.0) -> np.ndarray`.
mode AllBodyParts|TailbasePaws (degrades to AllBodyParts when parts unresolved). Raises
`SphynxValueError` on unknown mode / missing pixels_per_cm. Port of `rear.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_builtin_rear.py`:
```python
import numpy as np
import pytest

from sphynx.acts.builtins import rear
from sphynx.bodyparts import Point
from sphynx.exceptions import SphynxValueError


def _pt():
    return Point(tailbase=0, left_hind_limb=1, right_hind_limb=2, center=0)


def test_tailbase_paws_all_rear():
    n, parts = 100, 5
    bpx = np.zeros((parts, n))
    bpy = np.zeros((parts, n))
    bpx[1, :] = 0.5   # left hind 0.5 from tailbase
    bpx[2, :] = 0.5   # right hind 0.5 from tailbase -> sum 1.0 cm < 2.8
    rm = rear(bpx, bpy, _pt(), "TailbasePaws", pixels_per_cm=1,
              tailbase_paws_threshold_cm=2.8, min_run_frames=5, frame_rate=30)
    assert rm.all()


def test_tailbase_paws_none():
    n, parts = 100, 5
    bpx = np.zeros((parts, n))
    bpy = np.zeros((parts, n))
    bpx[1, :] = 5
    bpx[2, :] = 5   # sum 10 cm > 2.8
    rm = rear(bpx, bpy, _pt(), "TailbasePaws", pixels_per_cm=1,
              tailbase_paws_threshold_cm=2.8, min_run_frames=5, frame_rate=30)
    assert not rm.any()


def test_unknown_mode_raises():
    with pytest.raises(SphynxValueError):
        rear(np.zeros((2, 10)), np.zeros((2, 10)), Point(), "Bogus", 1)


def test_missing_pixels_per_cm_raises():
    with pytest.raises(SphynxValueError):
        rear(np.zeros((3, 10)), np.zeros((3, 10)), _pt(), "TailbasePaws", None)
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement.** Append to `src/sphynx/acts/builtins.py`:
```python
def _make_odd(w: int) -> int:
    w = int(w)
    if w % 2 == 0:
        w += 1
    if w < 3:
        w = 3
    return w


def rear(
    bpx, bpy, point: Point, mode: str, pixels_per_cm,
    all_body_parts_threshold_pxl: float = 170, tailbase_paws_threshold_cm: float = 2.8,
    auto_threshold: bool = False, smooth_window_frames=None, min_run_frames: int = 5,
    frame_rate: float = 30, x_kcorr: float = 1.0,
) -> np.ndarray:
    """Per-frame rear. mode AllBodyParts|TailbasePaws; TailbasePaws degrades to
    AllBodyParts when tailbase/hindlimbs are unresolved. Port of rear.m."""
    if mode not in ("AllBodyParts", "TailbasePaws"):
        raise SphynxValueError(f"mode must be AllBodyParts|TailbasePaws; got {mode}")
    if pixels_per_cm is None or pixels_per_cm <= 0:
        raise SphynxValueError("pixels_per_cm is required")
    bpx = np.asarray(bpx, dtype=float)
    bpy = np.asarray(bpy, dtype=float)
    n = bpx.shape[1]

    eff = mode
    if mode == "TailbasePaws" and (
        point.tailbase is None or point.left_hind_limb is None or point.right_hind_limb is None
    ):
        eff = "AllBodyParts"

    if eff == "AllBodyParts":
        if point.center is None:
            return np.zeros(n, dtype=bool)
        cx = bpx[point.center, :]
        cy = bpy[point.center, :]
        sum_dist = np.zeros(n)
        for part in range(bpx.shape[0]):
            sum_dist += hypot_kcorr(cx - bpx[part, :], cy - bpy[part, :], x_kcorr)
        win = smooth_window_frames if smooth_window_frames else _make_odd(round(frame_rate))
        smoothed = np.asarray(smooth_derived(sum_dist, win))
        raw = smoothed < all_body_parts_threshold_pxl
    else:  # TailbasePaws
        tx = bpx[point.tailbase, :]
        ty = bpy[point.tailbase, :]
        sum_dist = np.zeros(n)
        for part in (point.left_hind_limb, point.right_hind_limb):
            sum_dist += hypot_kcorr(tx - bpx[part, :], ty - bpy[part, :], x_kcorr)
        win = smooth_window_frames if smooth_window_frames else _make_odd(int(np.ceil(frame_rate / 2)))
        smoothed = np.asarray(smooth_derived(sum_dist, win))
        if auto_threshold:
            thr_cm = auto_rear_threshold_cm(smoothed / pixels_per_cm)
            if not np.isfinite(thr_cm):
                thr_cm = tailbase_paws_threshold_cm
        else:
            thr_cm = tailbase_paws_threshold_cm
        raw = smoothed < thr_cm * pixels_per_cm

    refined, _ = refine_act(raw, min_run_frames, min_run_frames)
    return refined
```
Update `src/sphynx/acts/__init__.py` to export `rear`.
- [ ] **Step 4: Run — PASS** (4 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/acts/builtins.py src/sphynx/acts/__init__.py tests/unit/test_builtin_rear.py && git commit -m "feat(python): acts.rear (standalone built-in)"`

---

### Task 3: acts.acts_library_defaults

**Files:** Create `src/sphynx/acts/library.py`; Modify `src/sphynx/acts/__init__.py` (export); Test `tests/unit/test_acts_library_defaults.py`.
**Interfaces:** `acts_library_defaults(config=None) -> list[Act]` (rest, walk,
locomotion, freezing, rear). Port of `actsLibraryDefaults.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_acts_library_defaults.py`:
```python
import math

from sphynx.acts.library import acts_library_defaults
from sphynx.config import Config


def test_default_library_acts():
    acts = acts_library_defaults()
    assert [a.name for a in acts] == ["rest", "walk", "locomotion", "freezing", "rear"]
    cfg = Config.default()
    assert acts[0].speed_max == cfg.acts.rest_threshold_cm_s          # rest
    assert acts[1].speed_min == cfg.acts.rest_threshold_cm_s          # walk
    assert acts[1].speed_max == cfg.acts.loc_threshold_cm_s
    assert acts[2].speed_min == cfg.acts.loc_threshold_cm_s and math.isinf(acts[2].speed_max)
    assert acts[3].type == "special" and acts[3].special_kind == "freezing"
    assert acts[4].type == "special" and acts[4].special_kind == "rears"
    assert acts[4].rear_mode == "TailbasePaws"
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** `src/sphynx/acts/library.py`:
```python
"""Default acts library (rest/walk/locomotion/freezing/rear). Port of
sphynx.acts.actsLibraryDefaults."""

from __future__ import annotations

from sphynx.acts.schema import Act, build_simple_act
from sphynx.config import Config


def acts_library_defaults(config: Config | None = None) -> list[Act]:
    if config is None:
        config = Config.default()
    rest = config.acts.rest_threshold_cm_s
    loc = config.acts.loc_threshold_cm_s
    rear_tbc = config.acts.rear_threshold_tailbase_paws_cm
    rear_abp = config.acts.rear_threshold_all_body_parts_pxl

    return [
        build_simple_act(name="rest", body_part="bodycenter", speed_min=0, speed_max=rest),
        build_simple_act(name="walk", body_part="bodycenter", speed_min=rest, speed_max=loc),
        build_simple_act(name="locomotion", body_part="bodycenter", speed_min=loc,
                         speed_max=float("inf")),
        Act(name="freezing", type="special", special_kind="freezing",
            body_parts=["headcenter", "bodycenter"], speed_max=rest),
        Act(name="rear", type="special", special_kind="rears", rear_mode="TailbasePaws",
            threshold_cm=rear_tbc, threshold_pxl=rear_abp, rear_auto_threshold=True),
    ]
```
Update `src/sphynx/acts/__init__.py` to export `acts_library_defaults`.
- [ ] **Step 4: Run — PASS** (1 passed), then full suite `python -m pytest -q`.
- [ ] **Step 5: Commit** `git add src/sphynx/acts/library.py src/sphynx/acts/__init__.py tests/unit/test_acts_library_defaults.py && git commit -m "feat(python): acts.acts_library_defaults"`

---

## Done criteria
- `python -m pytest -q` green (M4c 222 + these).
- Milestone M4 (acts + events) COMPLETE — followed by a whole-branch opus review.
- `sphynx.acts.{freezing, rear, acts_library_defaults}` available.

## Next
- M4 whole-branch opus review. Then M5: `metrics` (generic act x stat) + OF paradigm.
