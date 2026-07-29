# S2 M3a — Act model v2 part 1: part resolution + post-filters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Explicit body-part fallback chains on acts (miss -> warn + degraded, never a
silent all-false), a median post-filter field, and freezing/rear mode as act properties.

**Architecture:** Slice 3a of S2 (spec layer 4a/4c/4d). Today `acts/apply.py` has SIX
silent-fallback sites: an unresolved body part, an unknown zone, a missing complex
component, or missing freezing/rear parts all return an all-false mask with no signal to
the caller. That is the R31#4 defect class. M3a introduces a resolution layer that reports
what it substituted and what it could not find; `apply_act` records the degradation on the
context instead of hiding it.

**Tech Stack:** Python 3.11+, numpy, scipy.ndimage; pytest.

## Global Constraints
- Python at repo ROOT; commands from root with `PYTHONPATH=src`.
- No silent fallbacks (§10): a missing part is either substituted through a DECLARED chain
  (logged, marked degraded) or reported as missing (logged, marked degraded). Never a
  silent plausible substitution, never a silent all-false.
- ASCII only. TDD: failing test first.
- Backward compatibility: all new `Act` fields are defaulted; `apply_act(act, ctx)` keeps
  its signature and return type (ndarray). Degradation surfaces on `ActContext.degraded`.
- Fallback chains are conservative: only positional proxies that are scientifically
  defensible. Geometry-critical parts (hind limbs, ears) have NO default chain.

---

### Task 1: fallback library + part resolution

**Files:** Create `src/sphynx/bodyparts/fallbacks.py`, `src/sphynx/acts/part_resolution.py`; Modify `src/sphynx/bodyparts/__init__.py`; Test `tests/unit/test_part_resolution.py`.
**Interfaces:**
- `DEFAULT_FALLBACKS: dict[str, list[str]]` — canonical part -> ordered proxy chain.
- `PartResolution(indices: dict, substitutions: dict, missing: list, degraded: bool)` with property `ok -> bool` (True when `missing` is empty).
- `resolve_act_parts(required, body_parts, fallback=None, use_defaults=True) -> PartResolution`.

- [ ] **Step 1: Failing test** — `tests/unit/test_part_resolution.py`:
```python
from sphynx.acts.part_resolution import PartResolution, resolve_act_parts
from sphynx.bodyparts.fallbacks import DEFAULT_FALLBACKS


BP = ["nose", "headcenter", "bodycenter", "tailbase"]


def test_all_parts_present_no_degradation():
    r = resolve_act_parts(["nose", "bodycenter"], BP)
    assert isinstance(r, PartResolution)
    assert r.ok is True
    assert r.degraded is False
    assert r.indices["nose"] == 0
    assert r.indices["bodycenter"] == 2
    assert r.substitutions == {}
    assert r.missing == []


def test_declared_fallback_used_and_marks_degraded():
    bp = ["headcenter", "bodycenter"]           # no nose
    r = resolve_act_parts(["nose"], bp, fallback={"nose": ["headcenter"]})
    assert r.ok is True
    assert r.degraded is True
    assert r.indices["nose"] == 0               # index of the substitute
    assert r.substitutions["nose"] == "headcenter"


def test_declared_fallback_walks_chain_in_order():
    bp = ["bodycenter"]                          # neither nose nor headcenter
    r = resolve_act_parts(
        ["nose"], bp, fallback={"nose": ["headcenter", "bodycenter"]})
    assert r.substitutions["nose"] == "bodycenter"
    assert r.indices["nose"] == 0


def test_missing_without_fallback_is_reported_not_substituted():
    bp = ["bodycenter"]
    r = resolve_act_parts(["lefthindlimb"], bp, use_defaults=False)
    assert r.ok is False
    assert r.degraded is True
    assert r.missing == ["lefthindlimb"]
    assert "lefthindlimb" not in r.indices


def test_defaults_apply_when_no_explicit_chain():
    bp = ["headcenter", "bodycenter"]            # no nose
    r = resolve_act_parts(["nose"], bp)          # use_defaults=True
    assert r.ok is True
    assert r.substitutions["nose"] == "head_center"


def test_explicit_fallback_overrides_defaults():
    bp = ["headcenter", "bodycenter"]
    r = resolve_act_parts(["nose"], bp, fallback={"nose": ["bodycenter"]})
    assert r.substitutions["nose"] == "bodycenter"


def test_use_defaults_false_disables_library():
    bp = ["headcenter"]
    r = resolve_act_parts(["nose"], bp, use_defaults=False)
    assert r.ok is False
    assert r.missing == ["nose"]


def test_geometry_critical_parts_have_no_default_chain():
    # Hind limbs and ears must not be silently proxied -- rear/head-angle geometry.
    for part in ("left_hind_limb", "right_hind_limb", "left_ear", "right_ear"):
        assert part not in DEFAULT_FALLBACKS


def test_empty_required_is_ok():
    r = resolve_act_parts([], BP)
    assert r.ok is True
    assert r.degraded is False
```
- [ ] **Step 2: Run — FAIL** (`PYTHONPATH=src python -m pytest tests/unit/test_part_resolution.py -q`).
- [ ] **Step 3a: Implement fallback library.** `src/sphynx/bodyparts/fallbacks.py`:
```python
"""Default body-part fallback chains (S2 layer 4a).

A chain lists positional proxies to try when the requested part is absent from
the DLC schema. Chains are deliberately conservative: only substitutions that
stay scientifically defensible as a position estimate. Geometry-critical parts
(hind limbs, ears) carry NO default chain -- proxying them would silently
corrupt rear detection and head-angle math (the R31#4 defect class). An act may
always declare its own chain, which overrides these defaults.
"""

from __future__ import annotations

DEFAULT_FALLBACKS: dict[str, list[str]] = {
    "nose": ["head_center"],
    "head_center": ["nose", "center"],
    "center": ["tailbase", "head_center"],
    "tailbase": ["center"],
}
```
- [ ] **Step 3b: Implement resolution.** `src/sphynx/acts/part_resolution.py`:
```python
"""Resolve the body parts an act needs, through declared fallback chains.

Never substitutes silently: every substitution is logged and flips `degraded`;
every unresolvable part lands in `missing` (also logged). Callers decide what a
degraded act means -- this module only reports (S2 layer 4a, section 10).
"""

from __future__ import annotations

from dataclasses import dataclass, field

from sphynx.bodyparts.fallbacks import DEFAULT_FALLBACKS
from sphynx.bodyparts.resolve import resolve_part
from sphynx.logging_setup import get_logger

_log = get_logger()


@dataclass
class PartResolution:
    indices: dict = field(default_factory=dict)        # requested name -> 0-based index
    substitutions: dict = field(default_factory=dict)  # requested name -> name used
    missing: list = field(default_factory=list)        # unresolvable requested names
    degraded: bool = False

    @property
    def ok(self) -> bool:
        return not self.missing


def resolve_act_parts(
    required, body_parts, fallback=None, use_defaults: bool = True
) -> PartResolution:
    res = PartResolution()
    for name in (required or []):
        idx = resolve_part(body_parts, name)
        if idx is not None:
            res.indices[name] = idx
            continue

        if fallback is not None and name in fallback:
            chain = list(fallback[name])          # explicit chain wins outright
        elif use_defaults:
            chain = list(DEFAULT_FALLBACKS.get(name, []))
        else:
            chain = []

        for candidate in chain:
            alt = resolve_part(body_parts, candidate)
            if alt is not None:
                res.indices[name] = alt
                res.substitutions[name] = candidate
                res.degraded = True
                _log.warning(
                    'Body part "%s" absent; falling back to "%s"', name, candidate)
                break
        else:
            res.missing.append(name)
            res.degraded = True
            _log.warning(
                'Body part "%s" absent and no fallback resolved; act degraded', name)
    return res
```
- [ ] **Step 4: Export.** In `src/sphynx/bodyparts/__init__.py` add
  `from sphynx.bodyparts.fallbacks import DEFAULT_FALLBACKS` and add `"DEFAULT_FALLBACKS"`
  to `__all__`.
- [ ] **Step 5: Run — PASS** (9 passed), then full suite `PYTHONPATH=src python -m pytest -q`.
- [ ] **Step 6: Commit** `git add src/sphynx/bodyparts/fallbacks.py src/sphynx/acts/part_resolution.py src/sphynx/bodyparts/__init__.py tests/unit/test_part_resolution.py && git commit -m "feat(python): S2 M3a -- part fallback chains + resolve_act_parts"`

---

### Task 2: Act schema v2 fields + median post-filter

**Files:** Modify `src/sphynx/acts/schema.py`, `src/sphynx/acts/apply.py` (post-filter only), `src/sphynx/acts/__init__.py`; Test `tests/unit/test_act_postfilter.py`.
**Interfaces:**
- `Act` gains `required_parts: list = []`, `fallback: dict = {}`, `median_window_sec: float = 0.0`, `freezing_mode: str = ""` (all defaulted, appended after the existing fields).
- `build_special_act(name, special_kind, body_parts=None, zones=None, freezing_mode="", rear_mode="", threshold_cm=nan, threshold_pxl=nan, rear_auto_threshold=True, speed_max=inf, min_duration_sec=0.25, max_gap_sec=0.25) -> Act`.
- `apply_act` applies a median post-filter BEFORE the min-duration/gap refine when
  `act.median_window_sec > 0`.

- [ ] **Step 1: Failing test** — `tests/unit/test_act_postfilter.py`:
```python
import numpy as np

from sphynx.acts import Act, ActContext, build_special_act


def _ctx(n=40, frame_rate=10.0):
    return ActContext(
        X=np.zeros((1, n)), Y=np.zeros((1, n)),
        velocity_cm_s=np.zeros((1, n)), body_parts=["bodycenter"],
        zones=[], frame_rate=frame_rate,
    )


def test_new_act_fields_default():
    a = Act()
    assert a.required_parts == []
    assert a.fallback == {}
    assert a.median_window_sec == 0.0
    assert a.freezing_mode == ""


def test_act_fields_are_independent_between_instances():
    a, b = Act(), Act()
    a.required_parts.append("nose")
    a.fallback["nose"] = ["head_center"]
    assert b.required_parts == []
    assert b.fallback == {}


def test_build_special_act():
    a = build_special_act("freeze", "freezing", body_parts=["headcenter"],
                          freezing_mode="HeadAndCenter")
    assert a.type == "special"
    assert a.special_kind == "freezing"
    assert a.freezing_mode == "HeadAndCenter"
    assert a.body_parts == ["headcenter"]


def test_median_filter_applied_to_mask(monkeypatch):
    import sphynx.acts.apply as ap

    n = 40
    ctx = _ctx(n)
    spike = np.zeros(n, dtype=bool)
    spike[20] = True
    monkeypatch.setattr(ap, "_apply_simple", lambda act, ctx, n: spike.copy())
    act = Act(name="t", type="simple", median_window_sec=0.5,
              min_duration_sec=0.0, max_gap_sec=0.0)
    out = ap.apply_act(act, ctx)
    assert not out.any()  # isolated spike smoothed away


def test_median_filter_keeps_sustained_run(monkeypatch):
    import sphynx.acts.apply as ap

    n = 40
    ctx = _ctx(n)
    sig = np.zeros(n, dtype=bool)
    sig[10:25] = True
    monkeypatch.setattr(ap, "_apply_simple", lambda act, ctx, n: sig.copy())
    act = Act(name="t", type="simple", median_window_sec=0.5,
              min_duration_sec=0.0, max_gap_sec=0.0)
    out = ap.apply_act(act, ctx)
    assert out.sum() >= 13  # sustained run survives


def test_zero_median_window_is_noop(monkeypatch):
    import sphynx.acts.apply as ap

    n = 20
    ctx = _ctx(n)
    spike = np.zeros(n, dtype=bool)
    spike[10] = True
    monkeypatch.setattr(ap, "_apply_simple", lambda act, ctx, n: spike.copy())
    act = Act(name="t", type="simple", median_window_sec=0.0,
              min_duration_sec=0.0, max_gap_sec=0.0)
    out = ap.apply_act(act, ctx)
    assert out[10]
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3a: Add schema fields.** In `src/sphynx/acts/schema.py`, in the `Act`
  dataclass, append after `max_gap_sec`:
```python
    required_parts: list[str] = field(default_factory=list)
    fallback: dict = field(default_factory=dict)
    median_window_sec: float = 0.0
    freezing_mode: str = ""
```
- [ ] **Step 3b: Add builder.** Append to `src/sphynx/acts/schema.py`:
```python
def build_special_act(
    name: str = "", special_kind: str = "", body_parts=None, zones=None,
    freezing_mode: str = "", rear_mode: str = "",
    threshold_cm: float = _NAN, threshold_pxl: float = _NAN,
    rear_auto_threshold: bool = True, speed_max: float = _INF,
    min_duration_sec: float = 0.25, max_gap_sec: float = 0.25,
) -> Act:
    """Build a special act (freezing / rears / allinzone). Freezing and rear
    modes are act properties, not analysis-level config (S2 layer 4d)."""
    return Act(
        name=name, type="special", special_kind=special_kind.lower(),
        body_parts=list(body_parts or []), zones=list(zones or []),
        freezing_mode=freezing_mode, rear_mode=rear_mode,
        threshold_cm=threshold_cm, threshold_pxl=threshold_pxl,
        rear_auto_threshold=rear_auto_threshold, speed_max=speed_max,
        min_duration_sec=min_duration_sec, max_gap_sec=max_gap_sec,
    )
```
- [ ] **Step 3c: Apply the post-filter.** In `src/sphynx/acts/apply.py`, add the import
  near the top (with the other imports):
```python
from scipy.ndimage import median_filter
```
  and in `apply_act`, insert the median stage between the branch dispatch and the refine
  block, so the tail of `apply_act` reads exactly:
```python
    win = int(round(act.median_window_sec * ctx.frame_rate))
    if win >= 3:
        if win % 2 == 0:
            win += 1
        b = median_filter(b.astype(np.uint8), size=win, mode="nearest") > 0

    dur_sec = max(0.0, act.min_duration_sec)
    gap_sec = max(0.0, act.max_gap_sec)
    min_run = round(dur_sec * ctx.frame_rate)
    max_bridge = round(gap_sec * ctx.frame_rate)
    if min_run > 0 or max_bridge > 0:
        b = refine_act_array(b, min_run, max_bridge)
    return b
```
- [ ] **Step 4: Export.** In `src/sphynx/acts/__init__.py` add `build_special_act` to the
  schema import line and to `__all__`.
- [ ] **Step 5: Run — PASS** (6 passed), then full suite.
- [ ] **Step 6: Commit** `git add src/sphynx/acts/schema.py src/sphynx/acts/apply.py src/sphynx/acts/__init__.py tests/unit/test_act_postfilter.py && git commit -m "feat(python): S2 M3a -- Act v2 fields (required_parts/fallback/median_window/freezing_mode) + median post-filter"`

---

### Task 3: wire resolution into apply.py (kill the silent fallbacks)

**Files:** Modify `src/sphynx/acts/apply.py`, `src/sphynx/acts/schema.py` (`ActContext.degraded`); Test `tests/unit/test_act_degradation.py`.
**Interfaces:**
- `ActContext` gains `degraded: dict = {}` — act name -> list of reason strings.
- `apply_act` records a reason and warns whenever a part, zone, or component cannot be
  resolved, instead of silently returning all-false.

> **NOTE for the controller:** this task is integration/judgment work over six coupled
> call sites. Build it in the main loop, not via a transcribing implementer.

- [ ] **Step 1: Failing test** — `tests/unit/test_act_degradation.py` covering:
  unresolved `body_part` in a simple act records a `degraded` reason and warns (R31#4
  regression); unknown zone name records a reason; missing complex component records a
  reason; freezing/rear with missing parts record a reason; a fully resolvable act leaves
  `ctx.degraded` empty; a declared fallback chain resolves and records a substitution
  reason rather than a missing one.
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement.** Add `degraded: dict = field(default_factory=dict)` to
  `ActContext`; add a module-level helper in `apply.py`:
```python
def _mark(ctx, act, reason):
    ctx.degraded.setdefault(act.name, []).append(reason)
    _log.warning('Act "%s" degraded: %s', act.name, reason)
```
  and replace each silent-return site (`_apply_simple` unresolved part, `_in_any_zone`
  unknown zone, `_apply_complex` unknown component, `_apply_all_in_zone` unknown zone /
  no rows, `_apply_freezing` no rows, `_apply_rears` missing parts) with a `_mark` call
  before the existing all-false return. Simple acts route their part lookup through
  `resolve_act_parts(..., fallback=act.fallback)` so a declared chain is honoured and the
  substitution is recorded.
- [ ] **Step 4: Run — PASS**, then full suite `PYTHONPATH=src python -m pytest -q`.
- [ ] **Step 5: Commit** `git add src/sphynx/acts/apply.py src/sphynx/acts/schema.py tests/unit/test_act_degradation.py && git commit -m "fix(python): S2 M3a -- no silent act degradation (R31#4 class)"`

---

## Done criteria
- `PYTHONPATH=src python -m pytest -q` green (S2 M2 289 + M3a new).
- Every unresolved part / zone / component in `apply_act` warns and lands in
  `ctx.degraded`; declared fallback chains are honoured and recorded.
- `Act` carries required_parts / fallback / median_window_sec / freezing_mode.

## Next plan
- **M3b:** AST expression evaluator (`Or/And/Exclude/Sequence` + act_ref DAG) and migration
  of the flat `components`/`operation` model onto it. Then the M3a+M3b boundary review (opus).
