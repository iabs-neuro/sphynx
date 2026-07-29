# S2 M5 — Named-metric registry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A registry of named metrics carrying EXPLICIT dependencies, evaluation that raises
a clear error instead of returning a silent NaN, and the universal act-derived metrics over
the merged `EventStream` plus a parameterised `ratio_index`.

**Architecture:** Slice 5 of S2 (spec layer 5). Auto `act x stat` metrics are NOT registered
-- they are generated per act by `act_stats` (S1). Only *named* metrics register, and each
declares what it needs: `requires_acts` / `requires_events` / `requires_geometry` /
`paradigm`. Dependencies may be **parameter placeholders** (`"$family"`), so a
parameterised metric like `ratio_index(act_a, act_b)` keeps explicit deps. That is what
turns "silent NaN" into "this metric needs act X, which was not computed".

**Tech Stack:** Python 3.11+, numpy; pytest.

## Global Constraints
- Python at repo ROOT; commands from root with `PYTHONPATH=src`.
- No silent fallbacks (§10). The critical distinction this milestone must preserve:
  - a **missing dependency** (metric cannot be computed) -> RAISE `SphynxMetricError`;
  - a **legitimate negative result** (target declared but never visited; ratio of two
    zero-length acts) -> return NaN, documented at the metric.
  A metric must never return NaN because something upstream was absent.
- ASCII only. TDD: failing test first.
- `ratio_index` must work between ANY two acts; NOR discrimination is a call, not a
  hardcoded metric.

---

### Task 1: registry core

**Files:** Modify `src/sphynx/exceptions.py`; Create `src/sphynx/metrics/__init__.py`, `src/sphynx/metrics/registry.py`; Test `tests/unit/test_metric_registry.py`.
**Interfaces:**
- `SphynxMetricError(SphynxError)`.
- `MetricContext(acts, stats, events, act_defs, zones, frame_rate)`.
- `MetricSpec(name, fn, requires_acts, requires_events, requires_geometry, paradigm, doc)`.
- `register_metric(name, ...)` decorator; `REGISTRY: dict[str, MetricSpec]`.
- `missing_requirements(spec, ctx, params) -> list[str]`.
- `compute_metric(name, ctx, **params)`; `compute_metrics(names, ctx, params_by_name=None, paradigm=None) -> MetricResults`.
- `MetricResults(values: dict, errors: dict)`.

- [ ] **Step 1: Failing test** — `tests/unit/test_metric_registry.py`:
```python
import pytest

from sphynx.exceptions import SphynxError, SphynxMetricError, SphynxValueError
from sphynx.metrics.registry import (
    REGISTRY, MetricContext, MetricResults, compute_metric, compute_metrics,
    missing_requirements, register_metric,
)


@pytest.fixture(autouse=True)
def _isolate_registry():
    saved = dict(REGISTRY)
    REGISTRY.clear()
    yield
    REGISTRY.clear()
    REGISTRY.update(saved)


class _Zone:
    def __init__(self, name, is_target=False, angle=None):
        self.name = name
        self.roles = type("R", (), {"is_target": is_target})()
        self.angle = angle


def _ctx(**kw):
    base = dict(acts={"a": [True]}, stats={"a": object()}, events={"fam": object()},
                act_defs=[], zones=[_Zone("z1")], frame_rate=10.0)
    base.update(kw)
    return MetricContext(**base)


def test_metric_error_is_a_sphynx_error():
    assert issubclass(SphynxMetricError, SphynxError)


def test_register_and_compute():
    @register_metric("double_it", requires_acts=("a",))
    def _m(ctx, k=2):
        return 21 * k

    assert "double_it" in REGISTRY
    assert compute_metric("double_it", _ctx()) == 42


def test_unknown_metric_raises():
    with pytest.raises(SphynxMetricError):
        compute_metric("nope", _ctx())


def test_missing_act_dependency_raises_not_nan():
    @register_metric("needs_b", requires_acts=("b",))
    def _m(ctx):
        return 1.0

    with pytest.raises(SphynxMetricError) as exc:
        compute_metric("needs_b", _ctx())
    assert "b" in str(exc.value)


def test_missing_event_dependency_raises():
    @register_metric("needs_stream", requires_events=("other",))
    def _m(ctx):
        return 1.0

    with pytest.raises(SphynxMetricError):
        compute_metric("needs_stream", _ctx())


def test_missing_geometry_dependency_raises():
    @register_metric("needs_target", requires_geometry=("target_zone",))
    def _m(ctx):
        return 1.0

    with pytest.raises(SphynxMetricError):
        compute_metric("needs_target", _ctx())          # no zone is_target


def test_geometry_dependency_satisfied():
    @register_metric("needs_target2", requires_geometry=("target_zone",))
    def _m(ctx):
        return 7.0

    assert compute_metric("needs_target2", _ctx(zones=[_Zone("t", True)])) == 7.0


def test_unknown_geometry_key_rejected_at_registration():
    with pytest.raises(SphynxValueError):
        @register_metric("bad", requires_geometry=("teleporter",))
        def _m(ctx):
            return 1.0


def test_parameter_placeholder_dependency():
    @register_metric("uses_param", requires_acts=("$which",))
    def _m(ctx, which):
        return 5.0

    assert compute_metric("uses_param", _ctx(), which="a") == 5.0
    with pytest.raises(SphynxMetricError):
        compute_metric("uses_param", _ctx(), which="ghost")


def test_placeholder_without_parameter_raises():
    @register_metric("needs_param", requires_acts=("$which",))
    def _m(ctx, which=None):
        return 1.0

    with pytest.raises(SphynxMetricError):
        compute_metric("needs_param", _ctx())


def test_missing_requirements_lists_all():
    @register_metric("hungry", requires_acts=("x", "y"), requires_events=("s",))
    def _m(ctx):
        return 1.0

    missing = missing_requirements(REGISTRY["hungry"], _ctx(), {})
    assert len(missing) == 3


def test_compute_metrics_reports_values_and_errors():
    @register_metric("ok", requires_acts=("a",))
    def _ok(ctx):
        return 1.0

    @register_metric("bad", requires_acts=("ghost",))
    def _bad(ctx):
        return 2.0

    res = compute_metrics(["ok", "bad"], _ctx())
    assert isinstance(res, MetricResults)
    assert res.values == {"ok": 1.0}
    assert "bad" in res.errors        # recorded, never silently dropped


def test_paradigm_filter():
    @register_metric("barnes_only", paradigm=("Barnes",))
    def _m(ctx):
        return 1.0

    res = compute_metrics(["barnes_only"], _ctx(), paradigm="OF")
    assert res.values == {}
    assert res.errors == {}           # not applicable is not an error
    res2 = compute_metrics(["barnes_only"], _ctx(), paradigm="Barnes")
    assert res2.values == {"barnes_only": 1.0}
```
- [ ] **Step 2: Run — FAIL** (`PYTHONPATH=src python -m pytest tests/unit/test_metric_registry.py -q`).
- [ ] **Step 3a: Add the exception.** Append to `src/sphynx/exceptions.py`:
```python
class SphynxMetricError(SphynxError):
    """A metric could not be computed: an unknown metric, a missing dependency,
    or a malformed parameter. Never raised for a legitimate empty result."""
```
- [ ] **Step 3b: Implement the registry.** `src/sphynx/metrics/registry.py`:
```python
"""Named-metric registry (S2 layer 5).

Auto `act x stat` metrics are NOT registered -- they are generated per act by
sphynx.acts.stats. Only named metrics register, and each declares what it needs.
Explicit dependencies buy three things: a computable evaluation order, a clear
error instead of a silent NaN when something upstream is absent, and per-paradigm
filtering for the GUI.

A dependency may be a parameter placeholder ("$family"), so a parameterised
metric keeps honest dependencies.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from sphynx.exceptions import SphynxMetricError, SphynxValueError

# geometry requirement -> predicate over the context
_GEOMETRY_CHECKS = {
    "zones": lambda ctx: bool(ctx.zones),
    "target_zone": lambda ctx: any(
        getattr(getattr(z, "roles", None), "is_target", False) for z in ctx.zones),
    "zone_angles": lambda ctx: bool(ctx.zones) and all(
        getattr(z, "angle", None) is not None for z in ctx.zones),
}


@dataclass
class MetricContext:
    """Everything a named metric may read."""

    acts: dict = field(default_factory=dict)       # act name -> per-frame mask
    stats: dict = field(default_factory=dict)      # act name -> ActStats
    events: dict = field(default_factory=dict)     # family name -> EventStream
    act_defs: list = field(default_factory=list)   # Act objects (provenance)
    zones: list = field(default_factory=list)
    frame_rate: float = 30.0


@dataclass
class MetricSpec:
    name: str
    fn: object
    requires_acts: tuple = ()
    requires_events: tuple = ()
    requires_geometry: tuple = ()
    paradigm: tuple = ()
    doc: str = ""


@dataclass
class MetricResults:
    values: dict = field(default_factory=dict)
    errors: dict = field(default_factory=dict)     # metric name -> message


REGISTRY: dict = {}


def register_metric(name, requires_acts=(), requires_events=(),
                    requires_geometry=(), paradigm=(), doc=""):
    """Register a named metric with its explicit dependencies."""
    for key in requires_geometry:
        if key not in _GEOMETRY_CHECKS:
            raise SphynxValueError(
                f'metric "{name}": unknown geometry requirement "{key}"; '
                f"known: {sorted(_GEOMETRY_CHECKS)}")

    def decorator(fn):
        REGISTRY[name] = MetricSpec(
            name=name, fn=fn, requires_acts=tuple(requires_acts),
            requires_events=tuple(requires_events),
            requires_geometry=tuple(requires_geometry),
            paradigm=tuple(paradigm), doc=doc or (fn.__doc__ or ""),
        )
        return fn

    return decorator


def _resolve(dep, params, metric_name):
    """Resolve a "$param" placeholder against the call's parameters."""
    if isinstance(dep, str) and dep.startswith("$"):
        key = dep[1:]
        if key not in params or params[key] is None:
            raise SphynxMetricError(
                f'metric "{metric_name}" needs parameter "{key}"')
        return params[key]
    return dep


def missing_requirements(spec: MetricSpec, ctx: MetricContext, params) -> list:
    """Human-readable list of everything the metric needs but cannot see."""
    params = params or {}
    missing = []
    for dep in spec.requires_acts:
        name = _resolve(dep, params, spec.name)
        if name not in ctx.acts and name not in ctx.stats:
            missing.append(f'act "{name}"')
    for dep in spec.requires_events:
        name = _resolve(dep, params, spec.name)
        if name not in ctx.events:
            missing.append(f'event stream "{name}"')
    for key in spec.requires_geometry:
        if not _GEOMETRY_CHECKS[key](ctx):
            missing.append(f"geometry: {key}")
    return missing


def applies_to(spec: MetricSpec, paradigm) -> bool:
    return not spec.paradigm or paradigm is None or paradigm in spec.paradigm


def compute_metric(name, ctx: MetricContext, **params):
    """Compute one metric. Raises SphynxMetricError when it CANNOT be computed;
    a metric that legitimately has no value returns NaN itself."""
    spec = REGISTRY.get(name)
    if spec is None:
        raise SphynxMetricError(f'unknown metric "{name}"')
    missing = missing_requirements(spec, ctx, params)
    if missing:
        raise SphynxMetricError(
            f'metric "{name}" cannot be computed; missing ' + ", ".join(missing))
    return spec.fn(ctx, **params)


def compute_metrics(names, ctx: MetricContext, params_by_name=None,
                    paradigm=None) -> MetricResults:
    """Compute several metrics. Failures are RECORDED in `errors`, never dropped;
    metrics that do not apply to `paradigm` are skipped without an error."""
    params_by_name = params_by_name or {}
    out = MetricResults()
    for name in names:
        spec = REGISTRY.get(name)
        if spec is not None and not applies_to(spec, paradigm):
            continue
        try:
            out.values[name] = compute_metric(
                name, ctx, **params_by_name.get(name, {}))
        except SphynxMetricError as e:
            out.errors[name] = str(e)
    return out
```
- [ ] **Step 3c: Package init.** `src/sphynx/metrics/__init__.py`:
```python
"""Named metrics: registry + built-ins (S2 layer 5)."""

from sphynx.metrics.registry import (
    REGISTRY,
    MetricContext,
    MetricResults,
    MetricSpec,
    compute_metric,
    compute_metrics,
    missing_requirements,
    register_metric,
)

__all__ = [
    "REGISTRY", "MetricContext", "MetricResults", "MetricSpec",
    "compute_metric", "compute_metrics", "missing_requirements",
    "register_metric",
]
```
- [ ] **Step 4: Run — PASS** (13 passed), then full suite `PYTHONPATH=src python -m pytest -q`.
- [ ] **Step 5: Commit** `git add src/sphynx/exceptions.py src/sphynx/metrics tests/unit/test_metric_registry.py && git commit -m "feat(python): S2 M5 -- named-metric registry with explicit dependencies"`

---

### Task 2: universal act-derived metrics + ratio_index

**Files:** Create `src/sphynx/metrics/builtins.py`; Modify `src/sphynx/metrics/__init__.py`; Test `tests/unit/test_metric_builtins.py`.
**Interfaces (all registered):** `visit_order(family)`, `latency_to_target(family)`,
`primary_errors(family)`, `time_to_first(family, label=None)`,
`time_to_completion(family)`, `ratio_index(act_a, act_b, stat="duration_s")`.

- [ ] **Step 1: Failing test** — `tests/unit/test_metric_builtins.py`:
```python
import math

import numpy as np
import pytest

from sphynx.acts import Act, EventStream, family_event_stream
from sphynx.acts.stats import act_stats
from sphynx.exceptions import SphynxMetricError
from sphynx.metrics import MetricContext, compute_metric
import sphynx.metrics.builtins  # noqa: F401  (registers the built-ins)

FPS = 10.0


class _Zone:
    def __init__(self, name, is_target=False):
        self.name = name
        self.roles = type("R", (), {"is_target": is_target})()
        self.angle = None


def _member(name, zone, index, is_target=False):
    return Act(name=name, type="simple", family="holes",
               zone_name=zone, zone_index=index, is_target=is_target)


def _acts():
    return [_member("h1", "hole_a", 1),
            _member("h2", "hole_b", 2, is_target=True),
            _member("h3", "hole_c", 3)]


def _results():
    r = {n: np.zeros(30, dtype=bool) for n in ("h1", "h2", "h3")}
    r["h3"][2:4] = True        # hole_c first, at frame 2
    r["h2"][10:12] = True      # target hole_b at frame 10
    r["h1"][20:22] = True      # hole_a last
    return r


def _ctx(results=None, acts=None, zones=None):
    acts = _acts() if acts is None else acts
    results = _results() if results is None else results
    stream = family_event_stream(acts, results, FPS, family="holes")
    return MetricContext(
        acts=dict(results),
        stats={n: act_stats(m, FPS) for n, m in results.items()},
        events={"holes": stream}, act_defs=acts,
        zones=zones if zones is not None else [
            _Zone("hole_a"), _Zone("hole_b", True), _Zone("hole_c")],
        frame_rate=FPS,
    )


def test_visit_order():
    assert compute_metric("visit_order", _ctx(), family="holes") == [
        "hole_c", "hole_b", "hole_a"]


def test_latency_to_target():
    assert compute_metric("latency_to_target", _ctx(), family="holes") == pytest.approx(1.0)


def test_primary_errors_counts_distinct_holes_before_target():
    assert compute_metric("primary_errors", _ctx(), family="holes") == 1.0


def test_primary_errors_counts_a_recheck_once():
    r = _results()
    r["h3"][6:8] = True                       # hole_c re-checked before target
    assert compute_metric("primary_errors", _ctx(results=r), family="holes") == 1.0


def test_target_never_visited_is_nan_not_an_error():
    r = _results()
    r["h2"][:] = False                        # target declared, never found
    assert math.isnan(compute_metric("latency_to_target", _ctx(results=r), family="holes"))
    assert math.isnan(compute_metric("primary_errors", _ctx(results=r), family="holes"))


def test_no_target_declared_raises_rather_than_nan():
    # The section-10 distinction: "not declared" is a setup error, not a result.
    ctx = _ctx(zones=[_Zone("hole_a"), _Zone("hole_b"), _Zone("hole_c")])
    with pytest.raises(SphynxMetricError):
        compute_metric("latency_to_target", ctx, family="holes")


def test_time_to_first_any():
    assert compute_metric("time_to_first", _ctx(), family="holes") == pytest.approx(0.2)


def test_time_to_first_labelled():
    got = compute_metric("time_to_first", _ctx(), family="holes", label="hole_a")
    assert got == pytest.approx(2.0)


def test_time_to_first_unvisited_label_is_nan():
    got = compute_metric("time_to_first", _ctx(), family="holes", label="ghost")
    assert math.isnan(got)


def test_time_to_completion():
    # last distinct zone (hole_a) first seen at frame 20
    assert compute_metric("time_to_completion", _ctx(), family="holes") == pytest.approx(2.0)


def test_time_to_completion_incomplete_is_nan():
    r = _results()
    r["h1"][:] = False
    assert math.isnan(compute_metric("time_to_completion", _ctx(results=r), family="holes"))


def test_ratio_index_between_any_two_acts():
    r = _results()
    ctx = _ctx(results=r)
    # h3 and h2 both fire for 2 frames -> equal -> 0.0
    assert compute_metric("ratio_index", ctx, act_a="h3", act_b="h2") == pytest.approx(0.0)


def test_ratio_index_favours_a():
    r = _results()
    r["h3"][2:8] = True                        # longer
    ctx = _ctx(results=r)
    got = compute_metric("ratio_index", ctx, act_a="h3", act_b="h2")
    assert got > 0


def test_ratio_index_both_zero_is_nan():
    r = {n: np.zeros(30, dtype=bool) for n in ("h1", "h2", "h3")}
    ctx = _ctx(results=r)
    assert math.isnan(compute_metric("ratio_index", ctx, act_a="h1", act_b="h2"))


def test_ratio_index_unknown_act_raises():
    with pytest.raises(SphynxMetricError):
        compute_metric("ratio_index", _ctx(), act_a="ghost", act_b="h2")


def test_ratio_index_unknown_stat_raises():
    with pytest.raises(SphynxMetricError):
        compute_metric("ratio_index", _ctx(), act_a="h1", act_b="h2", stat="nonsense")


def test_missing_family_stream_raises():
    with pytest.raises(SphynxMetricError):
        compute_metric("visit_order", _ctx(), family="ghost_family")
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement.** `src/sphynx/metrics/builtins.py`:
```python
"""Universal act-derived metrics (S2 layer 5).

Every metric here is generic: it works over the merged EventStream of ANY act
family, so `visit_order` replaces the hardcoded order_barnes and `ratio_index`
replaces a bespoke novel/familiar discrimination index.

NaN policy: a metric returns NaN only for a legitimate empty result (a declared
target that was never visited, a family never completed, a ratio of two
zero-length acts). Anything the metric CANNOT compute raises SphynxMetricError
via the registry's dependency check.
"""

from __future__ import annotations

from sphynx.exceptions import SphynxMetricError
from sphynx.metrics.registry import register_metric

_NAN = float("nan")


@register_metric("visit_order", requires_events=("$family",))
def visit_order(ctx, family):
    """Zone labels in order of first visit. Replaces order_barnes."""
    return ctx.events[family].unique_labels()


@register_metric("time_to_first", requires_events=("$family",))
def time_to_first(ctx, family, label=None):
    """Seconds to the first episode of the family, or of `label` when given.
    NaN when it never happened."""
    stream = ctx.events[family]
    event = stream.first() if label is None else stream.first_where(
        lambda e: e.label == label)
    if event is None:
        return _NAN
    return event.start_frame / ctx.frame_rate


@register_metric("latency_to_target", requires_events=("$family",),
                 requires_geometry=("target_zone",))
def latency_to_target(ctx, family):
    """Seconds to the first visit of the target zone. NaN when the target was
    declared but never visited (no target declared at all is a dependency
    error, raised by the registry)."""
    event = ctx.events[family].first_where(lambda e: e.is_target)
    if event is None:
        return _NAN
    return event.start_frame / ctx.frame_rate


@register_metric("primary_errors", requires_events=("$family",),
                 requires_geometry=("target_zone",))
def primary_errors(ctx, family):
    """Distinct non-target zones checked before the target was first found.
    A re-check of the same zone counts once. NaN when the target was never
    visited."""
    stream = ctx.events[family]
    event = stream.first_where(lambda e: e.is_target)
    if event is None:
        return _NAN
    return float(len(stream.distinct_labels_before(event)))


@register_metric("time_to_completion", requires_events=("$family",))
def time_to_completion(ctx, family):
    """Seconds until every member zone of the family had been visited at least
    once. NaN when the family was never completed."""
    members = [a for a in ctx.act_defs if a.family == family]
    if not members:
        raise SphynxMetricError(f'family "{family}" has no member acts')
    total = len(members)
    seen = []
    for event in ctx.events[family].events:
        if event.label not in seen:
            seen.append(event.label)
            if len(seen) == total:
                return event.start_frame / ctx.frame_rate
    return _NAN


def _stat_value(ctx, act_name, stat):
    stats = ctx.stats.get(act_name)
    if stats is None:
        raise SphynxMetricError(f'no stats computed for act "{act_name}"')
    if not hasattr(stats, stat):
        raise SphynxMetricError(f'ActStats has no field "{stat}"')
    return float(getattr(stats, stat))


@register_metric("ratio_index", requires_acts=("$act_a", "$act_b"))
def ratio_index(ctx, act_a, act_b, stat="duration_s"):
    """(A - B) / (A + B) between ANY two acts, over any ActStats field.
    NOR discrimination is this metric called with the two object acts.
    NaN when both acts are zero -- the index is undefined, not zero."""
    a = _stat_value(ctx, act_a, stat)
    b = _stat_value(ctx, act_b, stat)
    total = a + b
    if total == 0:
        return _NAN
    return (a - b) / total
```
- [ ] **Step 4: Export.** In `src/sphynx/metrics/__init__.py` add
  `from sphynx.metrics import builtins as builtins  # noqa: F401  (registers built-ins)`
  as the LAST import line, and add `"builtins"` to `__all__`.
- [ ] **Step 5: Run — PASS** (16 passed), then full suite.
- [ ] **Step 6: Commit** `git add src/sphynx/metrics/builtins.py src/sphynx/metrics/__init__.py tests/unit/test_metric_builtins.py && git commit -m "feat(python): S2 M5 -- universal act-derived metrics + ratio_index"`

---

## Done criteria
- `PYTHONPATH=src python -m pytest -q` green (M4 389 + M5 new).
- A metric with an absent dependency raises a message naming what is missing; NaN appears
  only for legitimate empty results.
- `ratio_index` works between any two acts; `visit_order` / `primary_errors` work over any
  family's stream.

## Next plan
- **M6:** paradigm hierarchy (declarative bundles with inheritance), validation-as-data,
  and New-paradigm save/load. Then the M5+M6 boundary review (opus).
