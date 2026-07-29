# S2 M7 — Barnes metrics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** The Barnes maze metric set, computed from the M4 family `EventStream` plus M1
geometry (`is_target`, `angle`) and the trajectory -- registered named metrics with explicit
dependencies, wired into the Barnes paradigm.

**Architecture:** Slice 7 of S2 (spec layer 8). Nothing here is Barnes-specific *machinery*:
the events come from a generic act family, the ordinal and error queries come from M5, and
the ring geometry comes from each zone's own `angle`. That is what removes the MATLAB
`NumObjects=19` leak (docs/TODO.md line 89): the ring step is derived from the holes the
preset actually has, never from a constant.

**Tech Stack:** Python 3.11+, numpy; pytest.

## Global Constraints
- Python at repo ROOT; commands from root with `PYTHONPATH=src`.
- No silent fallbacks (§10): a missing dependency (no target member, holes without angles,
  no trajectory) RAISES `SphynxMetricError`. NaN only for legitimate empty results (the
  target was never found; no hole was ever checked).
- ASCII only. TDD: failing test first.
- Metric list source: docs/TODO.md "Barnes maze metrics" (training-day + test-day).
- Angles come from `Zone.angle` (M1, radians, relative to the arena centre); all reported
  angular distances are DEGREES in [0, 180].

> **NOTE for the controller:** the whole milestone is judgment work (angular conventions,
> error definitions, strategy classification). Build it in the main loop, not via a
> transcribing implementer.

---

### Task 1: trajectory in the metric context

**Files:** Modify `src/sphynx/metrics/registry.py`; Test `tests/unit/test_metric_registry.py` (append).
**Interfaces:** `MetricContext` gains `trajectory: tuple | None = None` — `(x_cm, y_cm)`;
`_GEOMETRY_CHECKS` gains `"trajectory"`.

- [ ] **Step 1: Failing test** — a metric declaring `requires_geometry=("trajectory",)`
  raises when the context carries none, and computes when it does.
- [ ] **Step 2: Run — FAIL**. **Step 3: Implement.** **Step 4: Run — PASS**, full suite.
- [ ] **Step 5: Commit** `git commit -m "feat(python): S2 M7 -- trajectory dependency in MetricContext"`

---

### Task 2: Barnes metrics module

**Files:** Create `src/sphynx/metrics/barnes.py`; Modify `src/sphynx/metrics/__init__.py`; Test `tests/unit/test_metric_barnes.py`.
**Interfaces (all registered with `paradigm=("Barnes",)`):**

| metric | meaning | empty result |
|---|---|---|
| `total_latency(family)` | seconds to the first episode of the *entry* family (mouse inside the target hole) | NaN if never entered |
| `total_errors(family)` | count of ALL episodes at non-target holes (repeats included) | 0.0 |
| `target_checks(family)` | count of episodes at the target hole | 0.0 |
| `non_target_checks(family)` | alias of `total_errors`, test-day naming | 0.0 |
| `time_near_target(family)` | summed duration of target-hole episodes, seconds | 0.0 |
| `target_ordinal(family)` | 0-based visit ordinal of the target among checked holes | NaN if never found |
| `angular_distance_first(family)` | degrees between the first checked hole and the target | NaN if nothing checked |
| `mean_angular_distance(family)` | mean degrees over the DISTINCT checked holes | NaN if nothing checked |
| `path_length(...)` | trajectory length in cm (whole trial) | NaN if the trace is empty |
| `path_length_to_target(family)` | trajectory length up to the first target visit | NaN if never found |
| `search_strategy(family, ...)` | "direct" / "serial" / "random" (Pitts 2018) | "none" if nothing checked |

`primary_latency` and `primary_errors` are already generic (M5 `latency_to_target` /
`primary_errors`) and are NOT redefined here.

**Search strategy (Pitts 2018), operationalised explicitly:**
- **direct** — the target is found having checked at most `max_direct_errors` (default 3)
  distinct wrong holes, AND every checked hole lies within `direct_arc_deg` (default 60)
  of the target.
- **serial** — the checked holes advance around the ring in one rotational direction in a
  run of at least `min_serial_run` (default 3) adjacent holes.
- **random** — anything else that checked at least one hole.
Thresholds are parameters, not magic numbers, and appear in the returned rationale.

- [ ] **Step 1: Failing test** — `tests/unit/test_metric_barnes.py` covering each metric on a
  synthetic 8-hole ring: a direct search, a serial sweep, a random search; the target never
  found (NaN, not an error); holes without angles (raises); no trajectory (raises); no target
  member in the family (raises); repeats counted by `total_errors` but not by `primary_errors`.
- [ ] **Step 2: Run — FAIL**. **Step 3: Implement** `src/sphynx/metrics/barnes.py` and export
  it from `src/sphynx/metrics/__init__.py` (imported for its registration side effect).
- [ ] **Step 4: Run — PASS**, full suite.
- [ ] **Step 5: Commit** `git commit -m "feat(python): S2 M7 -- Barnes metrics over the family event stream"`

---

### Task 3: wire the metrics into the Barnes paradigm

**Files:** Modify `src/sphynx/paradigms/builtins.py`; Test `tests/unit/test_paradigm_builtins.py` (append).
**Interfaces:** `barnes_maze()` gains the M7 metric refs (parameterised with the
`nose_at_hole` family, and the entry family for `total_latency`) plus an `inside_hole`
family so `total_latency` has a stream to read.

- [ ] **Step 1: Failing test** — the resolved Barnes paradigm declares the `inside_hole`
  family and metric refs for the M7 metrics, each carrying its family parameter; every ref
  names a metric that is actually registered.
- [ ] **Step 2: Run — FAIL**. **Step 3: Implement.** **Step 4: Run — PASS**, full suite.
- [ ] **Step 5: Commit** `git commit -m "feat(python): S2 M7 -- Barnes paradigm declares its metric set"`

---

## Done criteria
- `PYTHONPATH=src python -m pytest -q` green (M6 498 + M7 new).
- Every Barnes metric is computed from the generic family stream + geometry; no hole-count
  constant exists anywhere; each metric raises rather than returning a silent NaN when a
  dependency is absent.

## After M7
- Whole-branch opus review, fix Critical/Important, then push the branch. S2 complete.
