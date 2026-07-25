# Python engine — M5 metrics + OF paradigm Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Port `build_super_table` (multi-session act x stat aggregation) and define the
minimal OF paradigm bundle.

**Architecture:** Approach C — the super-table is a pandas port of MATLAB
`buildSuperTable.m` (much cleaner via pandas pivot). The OF paradigm is a minimal
declarative bundle (the full roles/composites/families/metric-registry system is S2).
Milestone M5.

**Tech Stack:** Python 3.11+, numpy, pandas; pytest.

## Global Constraints
- Python at repo ROOT; MATLAB reference under `matlab/` (do not touch). Commands from root.
- No silent fallbacks (§10): invalid nan_policy raises `SphynxValueError`.
- Behavioural parity with `buildSuperTable.m`'s test contract (`buildSuperTableTest.m`):
  Tidy = sessions x acts x metrics rows; Wide = unique mice rows, `<act>_<metric>_<session>`
  columns + per-session distance/velocity; NaN policy keep|zero.
- Batch-result acts carry snake_case metric keys directly (name, percent, duration, count,
  meantime) — the analyze_session output (M6) will produce these.
- TDD: failing test first.

---

### Task 1: pipeline.build_super_table

**Files:** Create `src/sphynx/pipeline/__init__.py`, `src/sphynx/pipeline/super_table.py`; Test `tests/unit/test_build_super_table.py`.
**Interfaces:** `SuperTable` dataclass (wide, tidy, meta: pd.DataFrame; acts: list[str]);
`build_super_table(batch_results, metadata=None, metrics=("percent","duration","count","meantime"),
nan_policy="keep", name_pattern=..., general_distance_unit="cm") -> SuperTable`. Each
batch result is a dict `{session_name, acts:[{name, <metric>...}], distance, velocity}`.
Port of `buildSuperTable.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_build_super_table.py`:
```python
import pandas as pd
import pytest

from sphynx.pipeline.super_table import build_super_table, SuperTable
from sphynx.exceptions import SphynxValueError


def _batch():
    a1 = {"name": "rest", "percent": 30, "duration": 180, "count": 8, "meantime": 22.5}
    a2 = {"name": "walk", "percent": 50, "duration": 300, "count": 12, "meantime": 25.0}
    a3 = {"name": "locomotion", "percent": 20, "duration": 120, "count": 4, "meantime": 30.0}
    return [
        {"session_name": "WNOF_J01_1D", "acts": [a1, a2, a3], "distance": 1500, "velocity": 2.5},
        {"session_name": "WNOF_J01_2D", "acts": [a1, a2, a3], "distance": 1700, "velocity": 2.8},
        {"session_name": "WNOF_J05_1D", "acts": [a1, a2, a3], "distance": 1300, "velocity": 2.2},
    ]


def test_tidy_has_row_per_act_metric_session():
    st = build_super_table(_batch())
    assert isinstance(st, SuperTable)
    assert len(st.tidy) == 36   # 3 sessions * 3 acts * 4 metrics


def test_wide_has_mouse_column_and_two_rows():
    st = build_super_table(_batch())
    assert "mouse" in st.wide.columns
    assert len(st.wide) == 2


def test_wide_has_act_metric_session_columns():
    cols = list(build_super_table(_batch()).wide.columns)
    assert "rest_percent_1D" in cols
    assert "walk_count_2D" in cols


def test_distance_velocity_columns():
    cols = list(build_super_table(_batch()).wide.columns)
    assert "distance_cm_1D" in cols
    assert "velocity_cm_per_s_1D" in cols


def test_nan_zero_policy():
    st = build_super_table(_batch(), nan_policy="zero")
    j05 = st.wide[st.wide["mouse"] == "J05"]
    assert j05["rest_percent_2D"].iloc[0] == 0


def test_custom_metadata_adds_group_line():
    meta = pd.DataFrame({
        "session_name": ["WNOF_J01_1D", "WNOF_J01_2D", "WNOF_J05_1D"],
        "mouse": ["J01", "J01", "J05"],
        "session": ["1D", "2D", "1D"],
        "group": ["control", "control", "test"],
        "line": ["C57Bl6", "C57Bl6", "C57Bl6"],
    })
    st = build_super_table(_batch(), metadata=meta)
    assert "group" in st.wide.columns
    assert "line" in st.wide.columns


def test_invalid_nan_policy_raises():
    with pytest.raises(SphynxValueError):
        build_super_table(_batch(), nan_policy="bogus")
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement.** `src/sphynx/pipeline/__init__.py`:
```python
"""Pipeline: session analysis orchestration + aggregation."""

from sphynx.pipeline.super_table import SuperTable, build_super_table

__all__ = ["SuperTable", "build_super_table"]
```
`src/sphynx/pipeline/super_table.py`:
```python
"""Reshape a batch of session results into a wide, Prism-friendly table.
Port of sphynx.pipeline.buildSuperTable (pandas)."""

from __future__ import annotations

import re
from dataclasses import dataclass

import numpy as np
import pandas as pd

from sphynx.exceptions import SphynxValueError

_DEFAULT_PATTERN = r"^(?P<exp>[^_]+)_(?P<mouse>[^_]+)_(?P<session>.+)$"


@dataclass
class SuperTable:
    wide: pd.DataFrame
    tidy: pd.DataFrame
    meta: pd.DataFrame
    acts: list


def _parse_metadata(session_names, pattern):
    rows = []
    for sn in session_names:
        m = re.match(pattern, sn)
        mouse = m.group("mouse") if (m and "mouse" in m.groupdict()) else sn
        session = m.group("session") if (m and "session" in m.groupdict()) else ""
        rows.append({"session_name": sn, "mouse": mouse, "session": session})
    return pd.DataFrame(rows)


def build_super_table(
    batch_results, metadata=None,
    metrics=("percent", "duration", "count", "meantime"),
    nan_policy: str = "keep", name_pattern: str = _DEFAULT_PATTERN,
    general_distance_unit: str = "cm",
) -> SuperTable:
    if nan_policy not in ("keep", "zero"):
        raise SphynxValueError(f"nan_policy must be keep|zero; got {nan_policy}")

    session_names = [b["session_name"] for b in batch_results]
    if metadata is None:
        meta = _parse_metadata(session_names, name_pattern)
    else:
        meta = metadata.copy()
    by_name = {r["session_name"]: r for _, r in meta.iterrows()}

    act_names: list = []
    for b in batch_results:
        for a in b["acts"]:
            if a["name"] not in act_names:
                act_names.append(a["name"])

    # --- tidy (long) ---
    tidy_rows = []
    for b in batch_results:
        mr = by_name.get(b["session_name"], {"mouse": b["session_name"], "session": ""})
        for a in b["acts"]:
            for mt in metrics:
                tidy_rows.append({
                    "mouse": mr["mouse"], "session": mr["session"],
                    "act": a["name"], "metric": mt, "value": a.get(mt, np.nan),
                })
    tidy = pd.DataFrame(tidy_rows, columns=["mouse", "session", "act", "metric", "value"])

    # --- wide (pivot) ---
    sessions = list(dict.fromkeys(meta["session"]))
    mice = list(dict.fromkeys(meta["mouse"]))
    wide = pd.DataFrame({"mouse": mice})

    for col in meta.columns:
        if col in ("session_name", "mouse", "session"):
            continue
        first = {}
        for _, r in meta.iterrows():
            first.setdefault(r["mouse"], r[col])
        wide[col] = wide["mouse"].map(first)

    # act_metric_session value lookup
    lut = {(r.mouse, r.session, r.act, r.metric): r.value for r in tidy.itertuples()}
    for act in act_names:
        for mt in metrics:
            for sess in sessions:
                wide[f"{act}_{mt}_{sess}"] = [
                    lut.get((mo, sess, act, mt), np.nan) for mo in mice
                ]

    # per-session distance / velocity
    scal = {}
    for b in batch_results:
        mr = by_name.get(b["session_name"], {"mouse": b["session_name"], "session": ""})
        scal[(mr["mouse"], mr["session"])] = (b.get("distance", np.nan), b.get("velocity", np.nan))
    dscale = 0.01 if general_distance_unit.lower() == "m" else 1.0
    for sess in sessions:
        dcol = f"distance_{general_distance_unit}_{sess}"
        vcol = f"velocity_cm_per_s_{sess}"
        wide[dcol] = [
            (scal[(mo, sess)][0] * dscale) if (mo, sess) in scal else np.nan for mo in mice
        ]
        wide[vcol] = [scal[(mo, sess)][1] if (mo, sess) in scal else np.nan for mo in mice]

    if nan_policy == "zero":
        num_cols = wide.select_dtypes(include="number").columns
        wide[num_cols] = wide[num_cols].fillna(0)

    return SuperTable(wide=wide, tidy=tidy, meta=meta, acts=act_names)
```
- [ ] **Step 4: Run — PASS** (7 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/pipeline/__init__.py src/sphynx/pipeline/super_table.py tests/unit/test_build_super_table.py && git commit -m "feat(python): pipeline.build_super_table"`

---

### Task 2: paradigms.open_field (minimal OF bundle)

**Files:** Create `src/sphynx/paradigms/__init__.py`, `src/sphynx/paradigms/of.py`; Test `tests/unit/test_paradigm_of.py`.
**Interfaces:** `Paradigm` dataclass (name: str, builtin_acts: list[str], metrics: list[str]);
`open_field() -> Paradigm`. Minimal declarative bundle for Open Field (built-in acts
rest/walk/locomotion/freezing/rear; generic metrics distance, mean_speed, occupancy). The
full roles/composites/families/named-metrics system is S2.

- [ ] **Step 1: Failing test** — `tests/unit/test_paradigm_of.py`:
```python
from sphynx.paradigms import Paradigm, open_field


def test_open_field_bundle():
    of = open_field()
    assert isinstance(of, Paradigm)
    assert of.name == "OF"
    for act in ("rest", "walk", "locomotion", "freezing", "rear"):
        assert act in of.builtin_acts
    assert "distance" in of.metrics


def test_paradigm_is_declarative_data():
    of = open_field()
    assert isinstance(of.builtin_acts, list)
    assert isinstance(of.metrics, list)
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement.** `src/sphynx/paradigms/__init__.py`:
```python
"""Experiment paradigms (declarative bundles). OF only in S1; the full
roles/composites/families system is S2."""

from sphynx.paradigms.of import Paradigm, open_field

__all__ = ["Paradigm", "open_field"]
```
`src/sphynx/paradigms/of.py`:
```python
"""Open Field paradigm — minimal declarative bundle. The full paradigm
system (roles, composite zones, act families, named-metric registry,
inheritance) is designed in S2."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class Paradigm:
    name: str
    builtin_acts: list[str] = field(default_factory=list)
    metrics: list[str] = field(default_factory=list)


def open_field() -> Paradigm:
    """Empty arena, no objects: default speed acts + freezing + rear;
    generic metrics distance / mean speed / arena occupancy."""
    return Paradigm(
        name="OF",
        builtin_acts=["rest", "walk", "locomotion", "freezing", "rear"],
        metrics=["distance", "mean_speed", "occupancy"],
    )
```
- [ ] **Step 2: Run — PASS** (2 passed), then full suite `python -m pytest -q`.
- [ ] **Step 5: Commit** `git add src/sphynx/paradigms/__init__.py src/sphynx/paradigms/of.py tests/unit/test_paradigm_of.py && git commit -m "feat(python): paradigms.open_field (minimal OF bundle)"`

---

## Done criteria
- `python -m pytest -q` green (M4 232 + these).
- `sphynx.pipeline.build_super_table` and `sphynx.paradigms.open_field` available.

## Next plan
- **M6:** the pipeline — `analyze_session` (integrator: load -> preprocess -> parts ->
  acts -> act_stats -> result) + `make_act_context` + `run_batch` + `cli`. Produces the
  working end-to-end analysis on Demo NOF_H01_1D (S1 acceptance criteria). Then the M5/M6
  whole-branch opus review.
