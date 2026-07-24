# Python engine — M4c apply_act + schema Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Port the act schema (`Act`, `build_simple_act`, `build_complex_act`,
`ActContext`), `auto_rear_threshold_cm`, and the act evaluator (`apply_act` +
`eval_acts_library`).

**Architecture:** Approach C — mirror MATLAB `+acts/{emptyAct,buildSimpleAct,
buildComplexAct,applyAct,evalActsLibrary,autoRearThresholdCm}`. Uses resolve_part
(bodyparts) and refine_act_array (M4a). Continues M4. Frame indices 0-based; body-part
lookups alias-tolerant via resolve_part.

**Tech Stack:** Python 3.11+, numpy; pytest.

## Global Constraints
- Python at repo ROOT; MATLAB reference under `matlab/` (do not touch). Commands from root.
- No silent fallbacks (§10) beyond documented act degradation (unresolved body parts ->
  degrade to resolvable ones / empty act; unknown act type/special-kind -> empty act,
  mirroring MATLAB).
- Behavioural parity with MATLAB sources; tests ported from `matlab/tests/unit/applyActTest.m`
  with frame indices 1-based -> 0-based and speed bands preserved.
- Zone-mask point lookup: coords are 1-based image coords; a point is inside when the
  rounded (x, y) lands on a True mask pixel.
- TDD: failing test first.

---

### Task 1: acts schema — Act, build_simple_act, build_complex_act, ActContext

**Files:** Create `src/sphynx/acts/schema.py`; Modify `src/sphynx/acts/__init__.py` (export); Test `tests/unit/test_act_schema.py`.
**Interfaces:** `Act` dataclass (name, type, zones, zone_op, body_part, body_parts,
speed_min, speed_max, components, operation, seq_delay_sec, special_kind, rear_mode,
threshold_cm, threshold_pxl, rear_auto_threshold, min_duration_sec, max_gap_sec);
`build_simple_act(...) -> Act`; `build_complex_act(...) -> Act`; `ActContext` dataclass
(X, Y, velocity_cm_s, body_parts, zones, frame_rate, pixels_per_cm=1.0, x_kcorr=1.0,
all_acts, results_by_name). Ports of emptyAct/buildSimpleAct/buildComplexAct + the ctx struct.

- [ ] **Step 1: Failing test** — `tests/unit/test_act_schema.py`:
```python
import math

from sphynx.acts.schema import Act, build_simple_act, build_complex_act, ActContext


def test_empty_act_defaults():
    a = Act()
    assert a.type == "simple"
    assert a.zone_op == "OR"
    assert a.speed_min == 0 and math.isinf(a.speed_max)
    assert a.min_duration_sec == 0.25 and a.max_gap_sec == 0.25
    assert a.rear_auto_threshold is True


def test_build_simple_act():
    a = build_simple_act(name="rest", body_part="bodycenter", speed_min=0, speed_max=1)
    assert a.type == "simple"
    assert a.name == "rest"
    assert a.body_part == "bodycenter"
    assert a.speed_max == 1
    assert a.zones == []


def test_build_simple_act_string_zone_becomes_list():
    a = build_simple_act(name="c", zones="center", zone_op="and")
    assert a.zones == ["center"]
    assert a.zone_op == "AND"


def test_build_complex_act():
    a = build_complex_act(name="either", components=["a1", "a2"], operation="Union")
    assert a.type == "complex"
    assert a.components == ["a1", "a2"]
    assert a.operation == "union"


def test_act_context_defaults():
    import numpy as np
    ctx = ActContext(X=np.zeros((2, 3)), Y=np.zeros((2, 3)),
                     velocity_cm_s=np.zeros((2, 3)), body_parts=["a", "b"],
                     zones=[], frame_rate=30)
    assert ctx.pixels_per_cm == 1.0
    assert ctx.x_kcorr == 1.0
    assert ctx.all_acts == [] and ctx.results_by_name == {}
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** `src/sphynx/acts/schema.py`:
```python
"""Act schema + builders + evaluation context. Ports of emptyAct,
buildSimpleAct, buildComplexAct and the applyAct ctx struct."""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

_INF = float("inf")
_NAN = float("nan")


@dataclass
class Act:
    name: str = ""
    type: str = "simple"          # 'simple' | 'complex' | 'special'
    zones: list[str] = field(default_factory=list)
    zone_op: str = "OR"           # AND | OR | EXCLUDE
    body_part: str = ""
    body_parts: list[str] = field(default_factory=list)
    speed_min: float = 0.0
    speed_max: float = _INF
    components: list[str] = field(default_factory=list)
    operation: str = ""           # intersect | union | exclude | sequence
    seq_delay_sec: float = 0.0
    special_kind: str = ""        # freezing | rears | allinzone
    rear_mode: str = ""
    threshold_cm: float = _NAN
    threshold_pxl: float = _NAN
    rear_auto_threshold: bool = True
    min_duration_sec: float = 0.25
    max_gap_sec: float = 0.25


def build_simple_act(
    name: str = "", zones=None, zone_op: str = "OR", body_part: str = "",
    speed_min: float = 0.0, speed_max: float = _INF,
    min_duration_sec: float = 0.25, max_gap_sec: float = 0.25,
) -> Act:
    if zones is None:
        zones = []
    elif isinstance(zones, str):
        zones = [zones]
    return Act(
        name=name, type="simple", zones=list(zones), zone_op=zone_op.upper(),
        body_part=body_part, speed_min=speed_min, speed_max=speed_max,
        min_duration_sec=min_duration_sec, max_gap_sec=max_gap_sec,
    )


def build_complex_act(
    name: str = "", components=None, operation: str = "intersect",
    seq_delay_sec: float = 0.0, min_duration_sec: float = 0.25, max_gap_sec: float = 0.25,
) -> Act:
    return Act(
        name=name, type="complex", components=list(components or []),
        operation=operation.lower(), seq_delay_sec=seq_delay_sec,
        min_duration_sec=min_duration_sec, max_gap_sec=max_gap_sec,
    )


@dataclass
class ActContext:
    X: np.ndarray          # HxN smoothed x per body part
    Y: np.ndarray          # HxN
    velocity_cm_s: np.ndarray  # HxN cm/s
    body_parts: list[str]
    zones: list            # objects with .name and .maskfilled
    frame_rate: float
    pixels_per_cm: float = 1.0
    x_kcorr: float = 1.0
    all_acts: list = field(default_factory=list)
    results_by_name: dict = field(default_factory=dict)
```
Update `src/sphynx/acts/__init__.py` to export `Act, build_simple_act, build_complex_act, ActContext`.
- [ ] **Step 4: Run — PASS** (5 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/acts/schema.py src/sphynx/acts/__init__.py tests/unit/test_act_schema.py && git commit -m "feat(python): acts schema (Act, build_simple_act, build_complex_act, ActContext)"`

---

### Task 2: acts.auto_rear_threshold_cm

**Files:** Create `src/sphynx/acts/rear_threshold.py`; Modify `src/sphynx/acts/__init__.py` (export); Test `tests/unit/test_auto_rear_threshold.py`.
**Interfaces:** `auto_rear_threshold_cm(sum_dist_cm, pctl=7, std_k=1.5, clamp_min_cm=1.5,
clamp_max_cm=3.5) -> float`. Robust per-session rear threshold. Returns NaN on empty/all-NaN.
Port of `autoRearThresholdCm.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_auto_rear_threshold.py`:
```python
import math

import numpy as np

from sphynx.acts.rear_threshold import auto_rear_threshold_cm


def test_empty_returns_nan():
    assert math.isnan(auto_rear_threshold_cm(np.array([])))
    assert math.isnan(auto_rear_threshold_cm(np.array([np.nan, np.nan])))


def test_within_clamp_range():
    rng = np.random.default_rng(0)
    # main mode ~4 cm with a small left tail near 2 cm
    s = np.concatenate([4.0 + rng.standard_normal(900) * 0.4, 2.0 + rng.standard_normal(100) * 0.2])
    thr = auto_rear_threshold_cm(s)
    assert 1.5 <= thr <= 3.5


def test_clamps_to_floor():
    # A distribution whose robust threshold would go below the 1.5 floor.
    s = np.full(500, 0.5)
    thr = auto_rear_threshold_cm(s)
    assert thr == 1.5
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** `src/sphynx/acts/rear_threshold.py`:
```python
"""Robust per-session rear threshold from the tailbase->hindlimb sum
distribution. Port of sphynx.acts.autoRearThresholdCm."""

from __future__ import annotations

import numpy as np


def auto_rear_threshold_cm(
    sum_dist_cm, pctl: float = 7, std_k: float = 1.5,
    clamp_min_cm: float = 1.5, clamp_max_cm: float = 3.5,
) -> float:
    s = np.asarray(sum_dist_cm, dtype=float).ravel()
    s = s[np.isfinite(s)]
    if s.size == 0:
        return float("nan")
    pctl_thr = float(np.percentile(s, pctl))
    std = float(np.std(s, ddof=1)) if s.size > 1 else 0.0
    std_thr = float(np.median(s)) - std_k * std
    thr = min(pctl_thr, std_thr)
    return max(clamp_min_cm, min(clamp_max_cm, thr))
```
Update `src/sphynx/acts/__init__.py` to export `auto_rear_threshold_cm`.
- [ ] **Step 4: Run — PASS** (3 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/acts/rear_threshold.py src/sphynx/acts/__init__.py tests/unit/test_auto_rear_threshold.py && git commit -m "feat(python): acts.auto_rear_threshold_cm"`

---

### Task 3: acts.apply_act + eval_acts_library

**Files:** Create `src/sphynx/acts/apply.py`; Modify `src/sphynx/acts/__init__.py` (export); Test `tests/unit/test_apply_act.py`.
**Interfaces:** `apply_act(act: Act, ctx: ActContext) -> np.ndarray` (1D bool, length N);
`eval_acts_library(acts: list[Act], ctx: ActContext) -> dict[str, np.ndarray]` (two-pass:
simple/special first, complex second). Port of `applyAct.m` + `evalActsLibrary.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_apply_act.py`:
```python
import numpy as np

from sphynx.acts.apply import apply_act, eval_acts_library
from sphynx.acts.schema import Act, ActContext, build_simple_act, build_complex_act
from sphynx.zones import Zone


def _ctx():
    n = 100
    bp = ["nose", "bodycenter", "tailbase", "lefthindlimb", "righthindlimb", "headcenter"]
    h = len(bp)
    x = np.tile(np.arange(1, n + 1) * 5.0, (h, 1))
    y = np.full((h, n), 100.0)
    v = np.zeros((h, n))
    v[:, 0:30] = 0.5    # rest
    v[:, 30:60] = 3     # walk
    v[:, 60:90] = 8     # loc
    v[:, 90:100] = 0.3  # rest tail
    zones = [Zone("arena", "area", np.ones((200, 600), bool))]
    return ActContext(x, y, v, bp, zones, 30, 5)


def test_simple_speed_act():
    a = build_simple_act(name="rest", body_part="bodycenter", speed_min=0, speed_max=1)
    b = apply_act(a, _ctx())
    assert int(b.sum()) == 40   # frames 0:30 + 90:100


def test_complex_union():
    a1 = build_simple_act(name="a1", body_part="bodycenter", speed_min=0, speed_max=1)
    a2 = build_simple_act(name="a2", body_part="bodycenter", speed_min=7, speed_max=float("inf"))
    c = build_complex_act(name="either", components=["a1", "a2"], operation="union")
    res = eval_acts_library([a1, a2, c], _ctx())
    assert "either" in res
    assert int(res["either"].sum()) == 40 + 30


def test_complex_exclude():
    a1 = build_simple_act(name="low", body_part="bodycenter", speed_min=0, speed_max=5)
    a2 = build_simple_act(name="rest_only", body_part="bodycenter", speed_min=0, speed_max=1)
    c = build_complex_act(name="walking", components=["low", "rest_only"], operation="exclude")
    res = eval_acts_library([a1, a2, c], _ctx())
    assert int(res["walking"].sum()) == 30   # only the walk band


def test_freezing_special():
    a = Act(name="freeze", type="special", special_kind="freezing",
            body_parts=["headcenter", "bodycenter"], speed_max=1)
    b = apply_act(a, _ctx())
    assert int(b.sum()) == 40
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** `src/sphynx/acts/apply.py`:
```python
"""Evaluate one act on a session's data. Port of sphynx.acts.applyAct +
evalActsLibrary."""

from __future__ import annotations

import numpy as np

from sphynx.acts.rear_threshold import auto_rear_threshold_cm
from sphynx.acts.refine import refine_act_array
from sphynx.acts.schema import Act, ActContext
from sphynx.bodyparts import resolve_part
from sphynx.geom import hypot_kcorr
from sphynx.util.smoothing import smooth_derived


def _find_zone(zones, name):
    for i, z in enumerate(zones):
        if z.name == name:
            return i
    return None


def _points_in_mask(xs, ys, mask):
    h, w = mask.shape
    xi = np.round(xs)
    yi = np.round(ys)
    valid = np.isfinite(xi) & np.isfinite(yi) & (xi >= 1) & (xi <= w) & (yi >= 1) & (yi <= h)
    out = np.zeros(xs.shape[0] if xs.ndim else np.size(xs), dtype=bool)
    if valid.any():
        vy = yi[valid].astype(int) - 1
        vx = xi[valid].astype(int) - 1
        out[valid] = mask[vy, vx]
    return out


def apply_act(act: Act, ctx: ActContext) -> np.ndarray:
    n_frames = ctx.X.shape[1]
    t = act.type.lower()
    if t == "simple":
        b = _apply_simple(act, ctx, n_frames)
    elif t == "complex":
        b = _apply_complex(act, ctx, n_frames)
    elif t == "special":
        b = _apply_special(act, ctx, n_frames)
    else:
        b = np.zeros(n_frames, dtype=bool)

    dur_sec = max(0.0, act.min_duration_sec)
    gap_sec = max(0.0, act.max_gap_sec)
    min_run = round(dur_sec * ctx.frame_rate)
    max_bridge = round(gap_sec * ctx.frame_rate)
    if min_run > 0 or max_bridge > 0:
        b = refine_act_array(b, min_run, max_bridge)
    return b


def _apply_simple(act, ctx, n):
    part = resolve_part(ctx.body_parts, act.body_part)
    if part is None:
        return np.zeros(n, dtype=bool)
    v = ctx.velocity_cm_s[part, :]
    speed_ok = (v >= act.speed_min) & (v <= act.speed_max)
    return speed_ok & _in_any_zone(act, ctx, part, n)


def _in_any_zone(act, ctx, part, n):
    if not act.zones:
        return np.ones(n, dtype=bool)
    masks = np.zeros((len(act.zones), n), dtype=bool)
    for k, zname in enumerate(act.zones):
        zi = _find_zone(ctx.zones, zname)
        if zi is None:
            continue
        zm = ctx.zones[zi].maskfilled
        zm = zm if zm.dtype == bool else (zm > 0)
        masks[k, :] = _points_in_mask(ctx.X[part, :], ctx.Y[part, :], zm)
    op = act.zone_op.upper()
    if op == "AND":
        return masks.all(axis=0)
    if op == "EXCLUDE":
        return masks[0, :] & ~masks[1:, :].any(axis=0)
    return masks.any(axis=0)


def _apply_complex(act, ctx, n):
    comps = act.components
    if not comps:
        return np.zeros(n, dtype=bool)
    cmasks = np.zeros((len(comps), n), dtype=bool)
    for k, name in enumerate(comps):
        if name in ctx.results_by_name:
            cmasks[k, :] = ctx.results_by_name[name]
        else:
            j = next((i for i, a in enumerate(ctx.all_acts) if a.name == name), None)
            if j is not None:
                cmasks[k, :] = apply_act(ctx.all_acts[j], ctx)
    op = act.operation.lower()
    if op == "intersect":
        return cmasks.all(axis=0)
    if op == "union":
        return cmasks.any(axis=0)
    if op == "exclude":
        return cmasks[0, :] & ~cmasks[1:, :].any(axis=0)
    if op == "sequence":
        if cmasks.shape[0] < 2:
            return cmasks[0] if cmasks.shape[0] else np.zeros(n, dtype=bool)
        delay = max(1, round(act.seq_delay_sec * ctx.frame_rate))
        a = cmasks[0, :]
        window = np.zeros(n, dtype=bool)
        for k in range(n):
            if a[k]:
                window[k + 1 : min(n, k + delay + 1)] = True
        b = window & cmasks[1, :]
        for j in range(2, cmasks.shape[0]):
            b = b & cmasks[j, :]
        return b
    return np.zeros(n, dtype=bool)


def _apply_special(act, ctx, n):
    kind = act.special_kind.lower()
    if kind == "freezing":
        return _apply_freezing(act, ctx, n)
    if kind == "rears":
        return _apply_rears(act, ctx, n)
    if kind == "allinzone":
        return _apply_all_in_zone(act, ctx, n)
    return np.zeros(n, dtype=bool)


def _apply_all_in_zone(act, ctx, n):
    if not act.zones or not act.body_parts:
        return np.zeros(n, dtype=bool)
    zi = _find_zone(ctx.zones, act.zones[0])
    if zi is None:
        return np.zeros(n, dtype=bool)
    zm = ctx.zones[zi].maskfilled
    zm = zm if zm.dtype == bool else (zm > 0)
    rows = []
    for name in act.body_parts:
        part = resolve_part(ctx.body_parts, name)
        if part is None:
            continue
        rows.append(_points_in_mask(ctx.X[part, :], ctx.Y[part, :], zm))
    if not rows:
        return np.zeros(n, dtype=bool)
    return np.vstack(rows).all(axis=0)


def _apply_freezing(act, ctx, n):
    parts = act.body_parts or ["headcenter", "bodycenter"]
    rows = []
    for name in parts:
        idx = resolve_part(ctx.body_parts, name)
        if idx is None:
            continue
        rows.append(ctx.velocity_cm_s[idx, :] < act.speed_max)
    if not rows:
        return np.zeros(n, dtype=bool)
    return np.vstack(rows).all(axis=0)


def _apply_rears(act, ctx, n):
    mode = act.rear_mode
    if mode.lower() == "tailbasepaws" or mode == "":
        t = resolve_part(ctx.body_parts, "tailbase")
        left = resolve_part(ctx.body_parts, "lefthindlimb")
        right = resolve_part(ctx.body_parts, "righthindlimb")
        if t is None or left is None or right is None:
            return np.zeros(n, dtype=bool)
        xk = ctx.x_kcorr
        d_l = hypot_kcorr(ctx.X[t, :] - ctx.X[left, :], ctx.Y[t, :] - ctx.Y[left, :], xk)
        d_r = hypot_kcorr(ctx.X[t, :] - ctx.X[right, :], ctx.Y[t, :] - ctx.Y[right, :], xk)
        sum_px = d_l + d_r
        if ctx.frame_rate > 0:
            win = max(3, 2 * int(np.ceil(ctx.frame_rate / 4)) + 1)
            sum_px = smooth_derived(sum_px, win)
        sum_cm = np.asarray(sum_px) / ctx.pixels_per_cm
        if act.rear_auto_threshold:
            thr_cm = auto_rear_threshold_cm(sum_cm)
            if not np.isfinite(thr_cm):
                thr_cm = act.threshold_cm
        else:
            thr_cm = act.threshold_cm
        return sum_cm < thr_cm
    idx = resolve_part(ctx.body_parts, "bodycenter")
    if idx is None:
        return np.zeros(n, dtype=bool)
    return ctx.Y[idx, :] < act.threshold_pxl


def eval_acts_library(acts, ctx: ActContext) -> dict:
    """Evaluate every act; simple/special first so complex acts can reference them."""
    results: dict = {}
    if not acts:
        return results
    for a in acts:
        if a.type.lower() != "complex":
            ctx.all_acts = acts
            ctx.results_by_name = results
            results[a.name] = apply_act(a, ctx)
    for a in acts:
        if a.type.lower() == "complex":
            ctx.all_acts = acts
            ctx.results_by_name = results
            results[a.name] = apply_act(a, ctx)
    return results
```
Update `src/sphynx/acts/__init__.py` to export `apply_act, eval_acts_library`.
- [ ] **Step 4: Run — PASS** (4 passed), then full suite `python -m pytest -q`.
- [ ] **Step 5: Commit** `git add src/sphynx/acts/apply.py src/sphynx/acts/__init__.py tests/unit/test_apply_act.py && git commit -m "feat(python): acts.apply_act + eval_acts_library"`

---

## Done criteria
- `python -m pytest -q` green (M4b 210 + these).
- `sphynx.acts.{Act, build_simple_act, build_complex_act, ActContext, auto_rear_threshold_cm,
  apply_act, eval_acts_library}` available.

## Next plan
- **M4d:** standalone `freezing` + `rear` (built-ins used by the pipeline) + acts library
  defaults + make_act_context. Then the M4 whole-branch opus review.
