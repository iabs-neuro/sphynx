# Python engine — M4b speed_acts + act_stats Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Port `speed_acts` (rest/walk/locomotion classification) and `act_stats`
(per-act numeric statistics).

**Architecture:** Approach C — mirror MATLAB `+acts/{speedActs,actStats}`. Both build
on `refine_act` (M4a). Field names are snake_case per spec section 5 (ActStats). Continues M4.

**Tech Stack:** Python 3.11+, numpy; pytest.

## Global Constraints
- Python at repo ROOT; MATLAB reference under `matlab/` (do not touch). Commands from root.
- No silent fallbacks (§10): the speed partition invariant failing raises `SphynxError`;
  non-positive frame_rate raises `SphynxValueError`.
- Behavioural parity with MATLAB sources; tests ported from `matlab/tests/unit/`.
  Episode boundaries use 0-based run frames (frame_in/frame_rate), matching MATLAB's
  (frameIn-1)/frameRate. MATLAB `std` = sample std (ddof=1); `mad` = mean abs deviation.
- TDD: failing test first.

---

### Task 1: acts.speed_acts

**Files:** Create `src/sphynx/acts/speed.py`; Modify `src/sphynx/acts/__init__.py` (export); Test `tests/unit/test_speed_acts.py`.
**Interfaces:** `SpeedActs` dataclass (rest, walk, locomotion: np.ndarray bool);
`speed_acts(velocity, rest_threshold_cm_s, loc_threshold_cm_s, min_run_frames) ->
SpeedActs`. Mutually-exclusive partition of frames; short dropped runs reassigned to
rest/locomotion by mean velocity. Port of `speedActs.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_speed_acts.py`:
```python
import numpy as np

from sphynx.acts.speed import speed_acts, SpeedActs


def test_stationary_all_rest():
    out = speed_acts(np.zeros(100), 1, 5, 5)
    assert isinstance(out, SpeedActs)
    assert out.rest.all()
    assert not out.walk.any()
    assert not out.locomotion.any()


def test_fast_all_locomotion():
    out = speed_acts(np.full(100, 20.0), 1, 5, 5)
    assert out.locomotion.all()


def test_mid_speed_all_walk():
    out = speed_acts(np.full(100, 3.0), 1, 5, 5)
    assert out.walk.all()


def test_partition_invariant():
    rng = np.random.default_rng(0)
    v = np.abs(rng.standard_normal(200)) * 5
    out = speed_acts(v, 1, 5, 5)
    assert int(out.rest.sum() + out.walk.sum() + out.locomotion.sum()) == 200
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** `src/sphynx/acts/speed.py`:
```python
"""Rest/walk/locomotion classification from velocity. Port of
sphynx.acts.speedActs."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from sphynx.acts.refine import refine_act
from sphynx.exceptions import SphynxError


@dataclass
class SpeedActs:
    rest: np.ndarray
    walk: np.ndarray
    locomotion: np.ndarray


def speed_acts(velocity, rest_threshold_cm_s, loc_threshold_cm_s, min_run_frames) -> SpeedActs:
    v = np.asarray(velocity, dtype=float).ravel()

    raw_rest = v < rest_threshold_cm_s
    raw_loc = v > loc_threshold_cm_s

    refined_rest, _ = refine_act(raw_rest, min_run_frames, min_run_frames)
    raw_loc_nonrest = raw_loc & ~refined_rest
    refined_loc, _ = refine_act(raw_loc_nonrest, min_run_frames, min_run_frames)
    raw_walk = ~(refined_rest | refined_loc)
    refined_walk, _ = refine_act(raw_walk, min_run_frames, min_run_frames)

    leftover = raw_walk & ~refined_walk
    mid = (rest_threshold_cm_s + loc_threshold_cm_s) / 2.0
    _, leftover_runs = refine_act(leftover, 0, 0)
    for r in leftover_runs:
        seg = v[r.frame_in : r.frame_out + 1]
        if np.mean(seg) > mid:
            refined_loc[r.frame_in : r.frame_out + 1] = True
        else:
            refined_rest[r.frame_in : r.frame_out + 1] = True

    total = refined_rest.astype(int) + refined_walk.astype(int) + refined_loc.astype(int)
    if not np.all(total == 1):
        raise SphynxError("rest+walk+locomotion does not partition the frames")

    return SpeedActs(refined_rest, refined_walk, refined_loc)
```
Update `src/sphynx/acts/__init__.py` to export `speed_acts, SpeedActs`.
- [ ] **Step 4: Run — PASS** (4 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/acts/speed.py src/sphynx/acts/__init__.py tests/unit/test_speed_acts.py && git commit -m "feat(python): acts.speed_acts"`

---

### Task 2: acts.act_stats

**Files:** Create `src/sphynx/acts/stats.py`; Modify `src/sphynx/acts/__init__.py` (export); Test `tests/unit/test_act_stats.py`.
**Interfaces:** `ActStats` dataclass (snake_case fields: count, percent, duration_s,
mean_time, median_time, std_time, mad_time, first_start_s, first_end_s, last_start_s,
last_end_s, first_duration_s, rest_duration_s, distance_cm, mean_distance_cm,
mean_velocity, max_velocity, min_velocity, velocity);
`act_stats(act_mask, frame_rate, velocity=None) -> ActStats`. Port of `actStats.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_act_stats.py`:
```python
import math

import numpy as np
import pytest

from sphynx.acts.stats import act_stats, ActStats


def test_empty_act_has_zeros_and_nans():
    s = act_stats(np.zeros(100, bool), 30)
    assert isinstance(s, ActStats)
    assert s.count == 0
    assert s.percent == 0
    assert s.duration_s == 0
    assert math.isnan(s.first_start_s)
    assert math.isnan(s.last_end_s)


def test_full_act_stats():
    mask = np.zeros(100, bool)
    mask[9:30] = True   # MATLAB mask(10:30): 21 frames
    mask[59:80] = True  # MATLAB mask(60:80): 21 frames
    s = act_stats(mask, 30)
    assert s.count == 2
    assert round(s.percent) == 42
    assert s.mean_time == pytest.approx(0.7, abs=0.05)


def test_mean_velocity_is_actual_mean():
    n, fps = 100, 30
    mask = np.zeros(n, bool)
    mask[10:60] = True
    vel = np.zeros(n)
    vel[10:60] = np.linspace(10, 20, 50)
    s = act_stats(mask, fps, velocity=vel)
    assert s.mean_velocity == pytest.approx(np.mean(np.linspace(10, 20, 50)), abs=0.05)
    assert s.velocity == s.mean_velocity


def test_distance_is_sum_over_fps():
    n, fps = 60, 30
    mask = np.zeros(n, bool)
    mask[0:30] = True
    s = act_stats(mask, fps, velocity=np.full(n, 6.0))
    assert s.distance_cm == pytest.approx(6.0, abs=0.05)


def test_episode_boundaries():
    n, fps = 100, 30
    mask = np.zeros(n, bool)
    mask[30:40] = True   # MATLAB mask(31:40)
    mask[80:90] = True   # MATLAB mask(81:90)
    s = act_stats(mask, fps, velocity=np.ones(n))
    assert s.count == 2
    assert s.first_start_s == pytest.approx(30 / fps, abs=0.01)
    assert s.first_end_s == pytest.approx(39 / fps, abs=0.01)
    assert s.last_start_s == pytest.approx(80 / fps, abs=0.01)
    assert s.last_end_s == pytest.approx(89 / fps, abs=0.01)


def test_first_and_rest_duration_split():
    n, fps = 100, 10
    mask = np.zeros(n, bool)
    mask[10:20] = True   # 10 frames -> 1.0 s
    mask[30:50] = True   # 20 frames -> 2.0 s
    mask[70:80] = True   # 10 frames -> 1.0 s
    s = act_stats(mask, fps)
    assert s.count == 3
    assert s.duration_s == pytest.approx(4.0, abs=0.05)
    assert s.first_duration_s == pytest.approx(1.0, abs=0.05)
    assert s.rest_duration_s == pytest.approx(3.0, abs=0.05)


def test_single_episode_rest_zero():
    n, fps = 50, 10
    mask = np.zeros(n, bool)
    mask[4:14] = True
    s = act_stats(mask, fps)
    assert s.count == 1
    assert s.first_duration_s == pytest.approx(1.0, abs=0.05)
    assert s.rest_duration_s == 0


def test_max_min_velocity():
    n = 50
    mask = np.zeros(n, bool)
    mask[10:30] = True
    vel = np.zeros(n)
    vel[10:30] = [3, 7, 9, 5, 6, 8, 12, 4, 10, 7, 5, 6, 9, 8, 7, 6, 5, 4, 3, 11]
    s = act_stats(mask, 30, velocity=vel)
    assert s.max_velocity == 12
    assert s.min_velocity == 3
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** `src/sphynx/acts/stats.py`:
```python
"""Per-act numeric statistics. Port of sphynx.acts.actStats. Field names are
snake_case (spec section 5)."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from sphynx.acts.refine import refine_act
from sphynx.exceptions import SphynxValueError

_NAN = float("nan")


@dataclass
class ActStats:
    count: int
    percent: float
    duration_s: float
    mean_time: float
    median_time: float
    std_time: float
    mad_time: float
    first_start_s: float
    first_end_s: float
    last_start_s: float
    last_end_s: float
    first_duration_s: float
    rest_duration_s: float
    distance_cm: float
    mean_distance_cm: float
    mean_velocity: float
    max_velocity: float
    min_velocity: float
    velocity: float


def act_stats(act_mask, frame_rate, velocity=None) -> ActStats:
    if not frame_rate > 0:
        raise SphynxValueError(f"frame_rate must be positive; got {frame_rate}")
    mask = np.asarray(act_mask).astype(bool).ravel()
    n = mask.size
    _, runs = refine_act(mask, 0, 0)
    durations = np.array([r.duration for r in runs], dtype=float)

    count = len(runs)
    percent = round(100.0 * mask.sum() / max(n, 1), 2)
    duration_s = round(mask.sum() / frame_rate, 2)

    if durations.size == 0:
        mean_time = median_time = std_time = mad_time = 0.0
    else:
        dur_sec = durations / frame_rate
        mean_time = round(float(np.mean(dur_sec)), 2)
        median_time = round(float(np.median(dur_sec)), 2)
        std_time = round(float(np.std(dur_sec, ddof=1)) if dur_sec.size > 1 else 0.0, 2)
        mad_time = round(float(np.mean(np.abs(dur_sec - np.mean(dur_sec)))), 2)

    if not runs:
        first_start_s = first_end_s = last_start_s = last_end_s = _NAN
        first_duration_s = rest_duration_s = _NAN
    else:
        first_start_s = round(runs[0].frame_in / frame_rate, 2)
        first_end_s = round(runs[0].frame_out / frame_rate, 2)
        last_start_s = round(runs[-1].frame_in / frame_rate, 2)
        last_end_s = round(runs[-1].frame_out / frame_rate, 2)
        first_dur = runs[0].duration / frame_rate
        first_duration_s = round(first_dur, 2)
        rest_duration_s = round(max(0.0, duration_s - first_dur), 2)

    if velocity is None or not mask.any():
        return ActStats(
            count, percent, duration_s, mean_time, median_time, std_time, mad_time,
            first_start_s, first_end_s, last_start_s, last_end_s,
            first_duration_s, rest_duration_s, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        )

    v = np.asarray(velocity, dtype=float).ravel()
    v_in = v[mask]
    mean_velocity = round(float(np.nanmean(v_in)), 2)
    max_velocity = round(float(np.nanmax(v_in)), 2)
    min_velocity = round(float(np.nanmin(v_in)), 2)
    distance_cm = round(float(np.nansum(v_in)) / frame_rate, 2)
    mean_distance_cm = round(distance_cm / count, 2) if count > 0 else 0.0
    return ActStats(
        count, percent, duration_s, mean_time, median_time, std_time, mad_time,
        first_start_s, first_end_s, last_start_s, last_end_s,
        first_duration_s, rest_duration_s, distance_cm, mean_distance_cm,
        mean_velocity, max_velocity, min_velocity, mean_velocity,
    )
```
Update `src/sphynx/acts/__init__.py` to export `act_stats, ActStats`.
- [ ] **Step 4: Run — PASS** (8 passed), then full suite `python -m pytest -q`.
- [ ] **Step 5: Commit** `git add src/sphynx/acts/stats.py src/sphynx/acts/__init__.py tests/unit/test_act_stats.py && git commit -m "feat(python): acts.act_stats"`

---

## Done criteria
- `python -m pytest -q` green (M4a 198 + these).
- `sphynx.acts.{speed_acts, SpeedActs, act_stats, ActStats}` available.

## Next plan
- **M4c:** freezing, rear, apply_act (dispatch), make_act_context, eval_acts_library.
  Then the M4 whole-branch opus review.
