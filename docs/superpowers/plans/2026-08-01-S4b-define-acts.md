# S4b — Define Acts + etogram Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A working Define Acts tab: build simple acts and act families, save them as a JSON
library, merge that library over the paradigm's acts, and preview an act on the loaded
session as numbers plus an etogram.

**Architecture:** The library format and the merge live in the engine, so a library works
from the CLI too; the tab is a thin editor over `Act`. Spec:
`docs/superpowers/specs/2026-08-01-S4b-define-acts-design.md`.

**Tech Stack:** Python 3.11+, PySide6, matplotlib, numpy; pytest, pytest-qt.

## Global Constraints
- Python at repo ROOT; commands from root with `PYTHONPATH=src`.
- `sphynx` must not import Qt (a test enforces it). Only `sphynx_gui` may.
- No silent fallbacks (§10): a library act overriding a paradigm act is REPORTED as a
  validation issue, never applied quietly. Unknown JSON fields and schema versions raise.
- **The body-part fallback chain is not user-editable.** The editor sets `body_part`;
  `required_parts` follows from it and `fallback` stays empty, so a missing part degrades
  honestly instead of being proxied.
- Preview computes over the frames actually loaded and states the range.
- ASCII only, including UI strings. TDD: failing test first.

## File Structure
- Create `src/sphynx/io/jsonio.py` — shared JSON helpers, extracted from `paradigms/io.py`.
- Create `src/sphynx/acts/library_io.py` — `ActLibrary` + JSON round trip.
- Modify `src/sphynx/pipeline/paradigm_bridge.py` — `library=` parameter and override reporting.
- Create `src/sphynx/plot/etogram.py` — `draw_etogram(axes, acts, frame_rate)`.
- Modify `src/sphynx_gui/plot_grid.py` — etogram as a fifth panel.
- Create `src/sphynx_gui/act_editor.py` — form <-> `Act`.
- Create `src/sphynx_gui/acts_tab.py`, `src/sphynx_gui/acts_controller.py`.
- Modify `src/sphynx_gui/main_window.py`, `src/sphynx_gui/state.py`.

---

### Task 1: shared JSON helpers + act library format

**Files:** Create `src/sphynx/io/jsonio.py`, `src/sphynx/acts/library_io.py`; Modify `src/sphynx/paradigms/io.py`; Test `tests/unit/test_acts_library_io.py`.
**Interfaces:**
- Produces `sphynx.io.jsonio`: `encode_specials(value)`, `decode_specials(value)`,
  `check_keys(data, known, what)`, `from_fields(cls, data, what)`, `write_json(payload, path)`,
  `read_json(path)`.
- Produces `ActLibrary(acts: list, families: list)`, `library_to_dict`, `library_from_dict`,
  `save_library(library, path) -> str`, `load_library(path) -> ActLibrary`, `SCHEMA_VERSION = 1`.
- Consumes `Act`, `ActFamily`, `ZoneSelector`.

- [ ] **Step 1: Write the failing test** — `tests/unit/test_acts_library_io.py`:
```python
import json

import pytest

from sphynx.acts import Act, ActFamily
from sphynx.acts.library_io import (
    ActLibrary, library_from_dict, library_to_dict, load_library, save_library,
)
from sphynx.exceptions import SphynxIOError, SphynxValueError
from sphynx.zones import ZoneSelector


def _library():
    return ActLibrary(
        acts=[Act(name="nose_in_centre", type="simple", body_part="nose",
                  required_parts=["nose"], zones=["Center"], speed_min=0.0,
                  min_duration_sec=0.4, max_gap_sec=0.2, median_window_sec=0.3)],
        families=[ActFamily(
            name="nose_at_object",
            selector=ZoneSelector(zone_class="object_area"),
            template=Act(name="nose_at_object", type="simple", body_part="nose",
                         required_parts=["nose"]),
            name_pattern="{family}{index}")],
    )


def test_dict_round_trip_preserves_acts_and_families():
    back = library_from_dict(library_to_dict(_library()))
    assert [a.name for a in back.acts] == ["nose_in_centre"]
    act = back.acts[0]
    assert act.body_part == "nose"
    assert act.zones == ["Center"]
    assert act.min_duration_sec == 0.4
    assert act.median_window_sec == 0.3
    family = back.families[0]
    assert family.selector.zone_class == "object_area"
    assert family.name_pattern == "{family}{index}"
    assert family.template.body_part == "nose"


def test_file_round_trip(tmp_path):
    path = tmp_path / "nested" / "acts.json"
    save_library(_library(), path)
    assert path.is_file()
    back = load_library(path)
    assert [a.name for a in back.acts] == ["nose_in_centre"]


def test_saved_file_is_portable_json(tmp_path):
    # Act defaults carry inf and NaN, which bare json writes in a form other
    # readers reject.
    path = tmp_path / "acts.json"
    save_library(_library(), path)
    raw = path.read_text(encoding="utf-8")
    assert "Infinity" not in raw and "NaN" not in raw
    assert json.loads(raw)["schema_version"] == 1
    import math
    assert math.isinf(load_library(path).acts[0].speed_max)


def test_unknown_top_level_field_raises():
    data = library_to_dict(_library())
    data["actz"] = data.pop("acts")
    with pytest.raises(SphynxValueError):
        library_from_dict(data)


def test_unknown_act_field_raises():
    data = library_to_dict(_library())
    data["acts"][0]["speed_mim"] = 1.0
    with pytest.raises(SphynxValueError):
        library_from_dict(data)


def test_missing_schema_version_raises():
    data = library_to_dict(_library())
    del data["schema_version"]
    with pytest.raises(SphynxValueError):
        library_from_dict(data)


def test_unknown_schema_version_raises():
    data = library_to_dict(_library())
    data["schema_version"] = 99
    with pytest.raises(SphynxValueError):
        library_from_dict(data)


def test_expression_tree_cannot_be_saved():
    from sphynx.acts.expr import Leaf

    library = ActLibrary(acts=[Act(name="c", type="complex", expr=Leaf("other"))])
    with pytest.raises(SphynxValueError):
        library_to_dict(library)


def test_missing_file_raises():
    with pytest.raises(SphynxIOError):
        load_library("no_such_library.json")


def test_malformed_json_raises(tmp_path):
    path = tmp_path / "bad.json"
    path.write_text("{not json", encoding="utf-8")
    with pytest.raises(SphynxIOError):
        load_library(path)


def test_empty_library_round_trips():
    back = library_from_dict(library_to_dict(ActLibrary()))
    assert back.acts == []
    assert back.families == []
```
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_acts_library_io.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'sphynx.acts.library_io'`

- [ ] **Step 3: Extract the shared helpers.** Create `src/sphynx/io/jsonio.py`:
```python
"""JSON helpers shared by the paradigm and act-library codecs.

Two properties matter for files a researcher may edit by hand: a typo must
raise rather than silently drop a section, and the file must be readable by
something other than Python -- so non-finite floats are encoded explicitly
instead of written as bare Infinity/NaN.
"""

from __future__ import annotations

import json
from dataclasses import fields
from pathlib import Path

from sphynx.exceptions import SphynxIOError, SphynxValueError

_INF, _NEG_INF, _NAN_TAG = "__inf__", "__-inf__", "__nan__"


def encode_specials(value):
    if isinstance(value, float):
        if value == float("inf"):
            return _INF
        if value == float("-inf"):
            return _NEG_INF
        if value != value:
            return _NAN_TAG
        return value
    if isinstance(value, dict):
        return {k: encode_specials(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [encode_specials(v) for v in value]
    return value


def decode_specials(value):
    if isinstance(value, str):
        if value == _INF:
            return float("inf")
        if value == _NEG_INF:
            return float("-inf")
        if value == _NAN_TAG:
            return float("nan")
        return value
    if isinstance(value, dict):
        return {k: decode_specials(v) for k, v in value.items()}
    if isinstance(value, list):
        return [decode_specials(v) for v in value]
    return value


def check_keys(data, known, what) -> None:
    if not isinstance(data, dict):
        raise SphynxValueError(f"{what} must be an object; got {type(data).__name__}")
    unknown = set(data) - set(known)
    if unknown:
        raise SphynxValueError(
            f"{what} has unknown field(s) {sorted(unknown)}; known: {sorted(known)}")


def from_fields(cls, data, what):
    """Build a dataclass from a dict, rejecting unknown keys loudly."""
    check_keys(data, {f.name for f in fields(cls)}, what)
    return cls(**data)


def write_json(payload, path) -> str:
    """Write through a temporary file so a failure cannot truncate a good one."""
    target = Path(path)
    tmp = target.with_name(target.name + ".tmp")
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as handle:
            json.dump(encode_specials(payload), handle, indent=2, sort_keys=False,
                      allow_nan=False)
        tmp.replace(target)
    except (OSError, TypeError, ValueError) as e:
        tmp.unlink(missing_ok=True)
        raise SphynxIOError(f"cannot write {target}: {e}") from e
    return str(target)


def read_json(path):
    source = Path(path)
    if not source.is_file():
        raise SphynxIOError(f"file not found: {source}")
    try:
        with open(source, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except json.JSONDecodeError as e:
        raise SphynxIOError(f"malformed JSON in {source}: {e}") from e
    except OSError as e:
        raise SphynxIOError(f"cannot read {source}: {e}") from e
    return decode_specials(data)
```
- [ ] **Step 4: Write the act library codec.** Create `src/sphynx/acts/library_io.py`:
```python
"""Act library as JSON (S4b).

The same rules as the paradigm codec: schema version required, unknown fields
rejected, non-finite floats encoded explicitly. Expression trees cannot be
saved -- `asdict` would flatten a tree into anonymous dicts that reload as
unknown nodes and evaluate to all-false.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field

from sphynx.acts.families import ActFamily
from sphynx.acts.schema import Act
from sphynx.exceptions import SphynxValueError
from sphynx.io.jsonio import check_keys, from_fields, read_json, write_json
from sphynx.zones.select import ZoneSelector

SCHEMA_VERSION = 1

_TOP_LEVEL = {"schema_version", "acts", "families"}
_FAMILY_KEYS = {"name", "selector", "template", "name_pattern"}


@dataclass
class ActLibrary:
    acts: list = field(default_factory=list)        # Act
    families: list = field(default_factory=list)    # ActFamily


def _act_to_dict(act, what):
    if getattr(act, "expr", None) is not None:
        raise SphynxValueError(
            f'{what} "{act.name}" carries an expression tree, which cannot be '
            "saved yet; declare it with the flat components/operation fields")
    return asdict(act)


def library_to_dict(library: ActLibrary) -> dict:
    return {
        "schema_version": SCHEMA_VERSION,
        "acts": [_act_to_dict(a, "act") for a in library.acts],
        "families": [
            {"name": f.name, "selector": asdict(f.selector),
             "template": _act_to_dict(f.template, "family template"),
             "name_pattern": f.name_pattern}
            for f in library.families
        ],
    }


def library_from_dict(data: dict) -> ActLibrary:
    check_keys(data, _TOP_LEVEL, "act library")
    if "schema_version" not in data:
        raise SphynxValueError("act library has no schema_version")
    if data["schema_version"] != SCHEMA_VERSION:
        raise SphynxValueError(
            f"unsupported act library schema version {data['schema_version']}; "
            f"this build reads version {SCHEMA_VERSION}")

    families = []
    for entry in data.get("families", []):
        check_keys(entry, _FAMILY_KEYS, "act family")
        families.append(ActFamily(
            name=entry.get("name", ""),
            selector=from_fields(ZoneSelector, entry.get("selector", {}),
                                 "family selector"),
            template=from_fields(Act, entry.get("template", {}), "act template"),
            name_pattern=entry.get("name_pattern", "{family}{index}"),
        ))
    return ActLibrary(
        acts=[from_fields(Act, a, "act") for a in data.get("acts", [])],
        families=families,
    )


def save_library(library: ActLibrary, path) -> str:
    return write_json(library_to_dict(library), path)


def load_library(path) -> ActLibrary:
    return library_from_dict(read_json(path))
```
- [ ] **Step 5: Point the paradigm codec at the shared helpers.** In
  `src/sphynx/paradigms/io.py`, delete the local `_encode_specials`, `_decode_specials`,
  `_check_keys`, `_from_fields` definitions and the `_INF`/`_NEG_INF`/`_NAN_TAG` constants,
  add `from sphynx.io.jsonio import check_keys, decode_specials, encode_specials, from_fields`,
  and rename every call site (`_check_keys` -> `check_keys`, `_from_fields` -> `from_fields`,
  `_encode_specials` -> `encode_specials`, `_decode_specials` -> `decode_specials`). Leave
  `save_paradigm`/`load_paradigm` as they are.
- [ ] **Step 6: Export.** In `src/sphynx/acts/__init__.py` add
  `from sphynx.acts.library_io import ActLibrary, load_library, save_library` and add
  `"ActLibrary"`, `"load_library"`, `"save_library"` to `__all__`.
- [ ] **Step 7: Run tests to verify they pass**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_acts_library_io.py tests/unit/test_paradigm_io.py -q`
Expected: PASS (11 new + the 20 paradigm-io tests unchanged). Then the full suite.

- [ ] **Step 8: Commit**
```bash
git add src/sphynx/io/jsonio.py src/sphynx/acts/library_io.py src/sphynx/paradigms/io.py src/sphynx/acts/__init__.py tests/unit/test_acts_library_io.py
git commit -m "feat(python): S4b -- act library JSON codec on shared helpers"
```

---

### Task 2: etogram plot

**Files:** Create `src/sphynx/plot/etogram.py`; Modify `src/sphynx/plot/__init__.py`; Test `tests/unit/test_etogram.py`.
**Interfaces:** `draw_etogram(axes, acts, frame_rate, max_acts=None) -> list[str]` — draws one
row of episode bars per act and returns the act names in row order (top to bottom). `acts` are
objects with `.name` and `.array`.

- [ ] **Step 1: Write the failing test** — `tests/unit/test_etogram.py`:
```python
import matplotlib
matplotlib.use("Agg")

import numpy as np
import pytest
from matplotlib.figure import Figure

from sphynx.exceptions import SphynxValueError
from sphynx.plot.etogram import draw_etogram


class _Act:
    def __init__(self, name, array):
        self.name = name
        self.array = np.asarray(array, dtype=float)


def _axes():
    return Figure().add_subplot(111)


def _acts():
    a = np.zeros(100)
    a[10:20] = 1
    a[40:45] = 1
    b = np.zeros(100)
    b[60:80] = 1
    return [_Act("rest", a), _Act("walk", b)]


def test_returns_act_names_in_row_order():
    assert draw_etogram(_axes(), _acts(), 10.0) == ["rest", "walk"]


def test_draws_one_collection_per_act():
    axes = _axes()
    draw_etogram(axes, _acts(), 10.0)
    assert len(axes.collections) == 2


def test_x_axis_is_seconds():
    axes = _axes()
    draw_etogram(axes, _acts(), 10.0)
    assert axes.get_xlim()[1] == pytest.approx(10.0)      # 100 frames at 10 fps
    assert "time" in axes.get_xlabel().lower()


def test_act_without_episodes_still_gets_a_row():
    acts = _acts() + [_Act("never", np.zeros(100))]
    axes = _axes()
    assert draw_etogram(axes, acts, 10.0) == ["rest", "walk", "never"]
    assert [t.get_text() for t in axes.get_yticklabels()] == ["rest", "walk", "never"]


def test_empty_act_list_is_labelled_not_blank():
    axes = _axes()
    assert draw_etogram(axes, [], 10.0) == []
    assert axes.texts                     # says there is nothing to show


def test_max_acts_truncates_and_says_so():
    acts = _acts() * 6                    # 12 acts
    axes = _axes()
    rows = draw_etogram(axes, acts, 10.0, max_acts=5)
    assert len(rows) == 5
    assert any("12" in t.get_text() for t in axes.texts)   # states what was dropped


def test_bad_frame_rate_raises():
    with pytest.raises(SphynxValueError):
        draw_etogram(_axes(), _acts(), 0)
```
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_etogram.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'sphynx.plot.etogram'`

- [ ] **Step 3: Write the implementation.** Create `src/sphynx/plot/etogram.py`:
```python
"""Etogram: one row of episode bars per act along the session timeline (S4b)."""

from __future__ import annotations

import numpy as np

from sphynx.acts.refine import refine_act
from sphynx.exceptions import SphynxValueError

_BAR_COLOUR = (0.20, 0.45, 0.75)


def draw_etogram(axes, acts, frame_rate, max_acts=None) -> list:
    """Draw the acts onto `axes` and return the names in row order.

    Truncation is stated on the plot rather than left silent: a chart that
    quietly shows five of twelve acts reads as the whole picture."""
    if not frame_rate > 0:
        raise SphynxValueError(f"frame_rate must be positive; got {frame_rate}")

    acts = list(acts or [])
    total = len(acts)
    if max_acts is not None and total > max_acts:
        acts = acts[:max_acts]

    if not acts:
        axes.text(0.5, 0.5, "No acts to show", ha="center", va="center",
                  transform=axes.transAxes)
        axes.set_yticks([])
        return []

    names = []
    duration = 0.0
    for row, act in enumerate(acts):
        mask = np.asarray(getattr(act, "array", []), dtype=float)
        duration = max(duration, mask.size / frame_rate)
        _, runs = refine_act(mask.astype(bool), 0, 0)
        spans = [(run.frame_in / frame_rate, run.duration / frame_rate)
                 for run in runs]
        axes.broken_barh(spans, (row - 0.4, 0.8), facecolors=_BAR_COLOUR)
        names.append(str(getattr(act, "name", "")))

    axes.set_yticks(range(len(names)))
    axes.set_yticklabels(names, fontsize=8)
    axes.invert_yaxis()
    axes.set_ylim(len(names) - 0.5, -0.5)
    axes.set_xlim(0, duration)
    axes.set_xlabel("time, s")

    if max_acts is not None and total > max_acts:
        axes.text(0.99, 1.02, f"showing {len(names)} of {total} acts",
                  ha="right", va="bottom", transform=axes.transAxes, fontsize=8)
    return names
```
- [ ] **Step 4: Export.** In `src/sphynx/plot/__init__.py` add
  `from sphynx.plot.etogram import draw_etogram` and `"draw_etogram"` to `__all__`.
- [ ] **Step 5: Run tests to verify they pass**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_etogram.py -q`
Expected: PASS (7 passed). Then the full suite.

- [ ] **Step 6: Commit**
```bash
git add src/sphynx/plot/etogram.py src/sphynx/plot/__init__.py tests/unit/test_etogram.py
git commit -m "feat(python): S4b -- etogram plot"
```

---

### Task 3: merge an act library over the paradigm

**Files:** Modify `src/sphynx/pipeline/paradigm_bridge.py`, `src/sphynx/pipeline/analyze.py`; Test `tests/unit/test_library_merge.py`.
**Interfaces:**
- `apply_paradigm(result, paradigm, registry=None, library=None) -> None`.
- `analyze_session(config, paradigm=None, library=None) -> SessionResult`.
- An override records `ValidationIssue(code="act_overridden", level="info", ...)`.

- [ ] **Step 1: Write the failing test** — `tests/unit/test_library_merge.py`:
```python
import numpy as np
import pytest

from sphynx.acts import Act, ActFamily
from sphynx.acts.library_io import ActLibrary
from sphynx.paradigms import PARADIGMS, register_builtin_paradigms
from sphynx.pipeline.paradigm_bridge import apply_paradigm
from sphynx.bodyparts.identify import Point
from sphynx.config import Config
from sphynx.pipeline.analyze import SessionAct, SessionResult
from sphynx.zones import Zone, ZoneRoles, ZoneSelector

N = 60
FPS = 10.0


class _Options:
    FrameRate = FPS
    pxl2sm = 10.0
    Width = 100
    Height = 100


class _Trace:
    def __init__(self, name, x, y, v):
        self.name = name
        self.x_smooth = x
        self.y_smooth = y
        self.velocity = v


def _hole(name, cx, cy, is_target=False):
    mask = np.zeros((100, 100), dtype=bool)
    mask[cy - 3:cy + 3, cx - 3:cx + 3] = True
    return Zone(name, "area", mask, zone_class="hole",
                roles=ZoneRoles(is_target=is_target), angle=0.0)


def _zones():
    zs = [_hole("hole_a", 20, 20, is_target=True), _hole("hole_b", 80, 20)]
    for i, z in enumerate(zs, start=1):
        z.index = i
    return zs


def _result(zones):
    x = np.full(N, 90.0)
    y = np.full(N, 90.0)
    x[10:20] = 20.0
    y[10:20] = 20.0
    traces = [_Trace("nose", x, y, np.zeros(N)),
              _Trace("bodycenter", x, y, np.zeros(N))]
    return SessionResult(
        body_parts_names=["nose", "bodycenter"], body_parts_traces=traces,
        point=Point(nose=0, center=1),
        acts=[SessionAct("rest", np.ones(N), "builtin")],
        options=_Options(), zones=zones, arena_and_objects=None,
        n_frames=N, config=Config.default(),
    )


@pytest.fixture(autouse=True)
def _builtins():
    saved = dict(PARADIGMS)
    PARADIGMS.clear()
    register_builtin_paradigms()
    yield
    PARADIGMS.clear()
    PARADIGMS.update(saved)


def _library_family(name="nose_at_hole", zone_class="hole"):
    return ActLibrary(families=[ActFamily(
        name=name, selector=ZoneSelector(zone_class=zone_class),
        template=Act(name=name, type="simple", body_part="nose",
                     required_parts=["nose"], min_duration_sec=0.0,
                     max_gap_sec=0.0))])


def test_library_acts_are_added():
    result = _result(_zones())
    library = ActLibrary(acts=[Act(name="my_act", type="simple",
                                   body_part="bodycenter", zones=["hole_a"],
                                   min_duration_sec=0.0, max_gap_sec=0.0)])
    apply_paradigm(result, "OF", library=library)
    assert "my_act" in [a.name for a in result.acts]


def test_library_family_expands():
    result = _result(_zones())
    apply_paradigm(result, "OF", library=_library_family("sniff", "hole"))
    names = [a.name for a in result.acts]
    assert "sniff1" in names and "sniff2" in names


def test_same_name_library_act_overrides_the_paradigm_act():
    result = _result(_zones())
    apply_paradigm(result, "Barnes", library=_library_family("nose_at_hole"))
    # exactly one act per member name survives
    names = [a.name for a in result.acts]
    assert names.count("nose_at_hole1") == 1


def test_the_override_is_reported_not_silent():
    result = _result(_zones())
    apply_paradigm(result, "Barnes", library=_library_family("nose_at_hole"))
    issues = [i for i in result.validation.issues if i.code == "act_overridden"]
    assert issues
    assert issues[0].level == "info"
    assert "nose_at_hole1" in " ".join(i.message for i in issues)


def test_no_library_leaves_the_paradigm_untouched():
    result = _result(_zones())
    apply_paradigm(result, "Barnes")
    assert not [i for i in result.validation.issues if i.code == "act_overridden"]


def test_unbuildable_library_family_is_reported():
    result = _result(_zones())
    apply_paradigm(result, "OF", library=_library_family("ghost", "no_such_class"))
    assert "family_failed" in [i.code for i in result.validation.issues]


def test_library_act_appears_in_the_event_streams_of_its_family():
    result = _result(_zones())
    apply_paradigm(result, "OF", library=_library_family("sniff", "hole"))
    assert "sniff" in result.event_streams
```
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_library_merge.py -q`
Expected: FAIL with `TypeError: apply_paradigm() got an unexpected keyword argument 'library'`

- [ ] **Step 3: Implement the merge.** In `src/sphynx/pipeline/paradigm_bridge.py`:
  change the signature to `def apply_paradigm(result, paradigm, registry=None, library=None) -> None:`,
  and replace the block that builds `concrete` (`concrete = _expand_families(resolved, zones, report)`)
  with:
```python
    concrete = _expand_families(resolved.families, zones, report)
    concrete.extend(resolved.acts)

    if library is not None:
        from_library = _expand_families(library.families, zones, report)
        from_library.extend(library.acts)
        concrete = _merge_library(concrete, from_library, report)
```
  add the merge helper next to `_expand_families`:
```python
def _merge_library(paradigm_acts, library_acts, report):
    """Library acts are added; a same-named act replaces the paradigm's.

    The replacement is REPORTED: a run that quietly measured something other
    than the paradigm declared is indistinguishable from one that did not."""
    by_name = {a.name: a for a in paradigm_acts}
    order = [a.name for a in paradigm_acts]
    for act in library_acts:
        if act.name in by_name:
            report.issues.append(ValidationIssue(
                code="act_overridden", level="info",
                message=f'act "{act.name}" from the paradigm was replaced by '
                        "the act of the same name in your library",
                where=act.name))
        else:
            order.append(act.name)
        by_name[act.name] = act
    return [by_name[name] for name in order]
```
  and change `_expand_families` to take a family list rather than the paradigm:
```python
def _expand_families(families, zones, report):
    concrete = []
    for family in families:
        try:
            concrete.extend(expand_family(family, zones))
        except SphynxError as e:
            _issue(report, "family_failed",
                   f'act family "{family.name}" could not be expanded: {e}',
                   where=family.name)
    return concrete
```
  Finally, replace the event-stream loop so it covers library families too:
```python
        for family in list(resolved.families) + list(
                library.families if library is not None else []):
            members = [a for a in concrete if a.family == family.name]
            if members:
                result.event_streams[family.name] = family_event_stream(
                    members, masks, frame_rate, family=family.name)
```
- [ ] **Step 4: Thread it through analyze_session.** In `src/sphynx/pipeline/analyze.py`
  change the signature to `def analyze_session(config: Config, paradigm=None, library=None) -> SessionResult:`
  and the application at the end to:
```python
    if paradigm is not None or library is not None:
        from sphynx.pipeline.paradigm_bridge import apply_paradigm

        apply_paradigm(result, paradigm or "OF", library=library)
```
- [ ] **Step 5: Run tests to verify they pass**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_library_merge.py -q`
Expected: PASS (7 passed). Then the full suite.

- [ ] **Step 6: Commit**
```bash
git add src/sphynx/pipeline tests/unit/test_library_merge.py
git commit -m "feat(python): S4b -- act library merged over the paradigm, overrides reported"
```

---

### Task 4: etogram in the plot grid

**Files:** Modify `src/sphynx_gui/plot_grid.py`; Test `tests/gui/test_plot_grid.py` (append).
**Interfaces:** `PlotGrid.canvases` gains `"etogram"`; it spans the full bottom row.

- [ ] **Step 1: Write the failing test** — append to `tests/gui/test_plot_grid.py`:
```python
def test_etogram_is_the_fifth_panel(qtbot):
    grid = PlotGrid()
    qtbot.addWidget(grid)
    assert "etogram" in grid.canvases


def test_etogram_is_drawn_from_the_acts(qtbot):
    import numpy as np

    from sphynx.pipeline.analyze import SessionAct

    class _R(_Result):
        def __init__(self):
            super().__init__()
            mask = np.zeros(100)
            mask[10:30] = 1
            self.acts = [SessionAct("rest", mask, "builtin")]

    grid = PlotGrid()
    qtbot.addWidget(grid)
    grid.show_result(_R())
    assert grid.canvases["etogram"].figure.axes


def test_etogram_survives_a_result_without_acts(qtbot):
    grid = PlotGrid()
    qtbot.addWidget(grid)
    grid.show_result(_Result())          # no `acts` attribute at all
    assert grid.canvases["etogram"].figure.axes
```
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/gui/test_plot_grid.py -q`
Expected: FAIL with `assert 'etogram' in grid.canvases`

- [ ] **Step 3: Implement.** In `src/sphynx_gui/plot_grid.py`:
  add `"etogram"` to `PLOT_NAMES`, `_TITLES` (`"etogram": "Etogram"`) and `_POSITIONS`
  (`"etogram": (2, 0)`); when adding widgets, give the etogram a column span:
```python
            row, column = _POSITIONS[name]
            span = 2 if name == "etogram" else 1
            self._layout.addWidget(canvas, row, column, 1, span)
```
  add the import `from sphynx.plot.etogram import draw_etogram`, and at the end of
  `show_result` (before the `draw_idle` loop) add:
```python
        self._draw_etogram(getattr(result, "acts", None), frame_rate)
```
  with:
```python
    def _draw_etogram(self, acts, frame_rate):
        axes = self._axes("etogram")
        draw_etogram(axes, [a for a in (acts or []) if a.array is not None],
                     frame_rate, max_acts=12)
```
- [ ] **Step 4: Run tests to verify they pass**

Run: `PYTHONPATH=src python -m pytest tests/gui/test_plot_grid.py -q`
Expected: PASS (9 passed). Then the full suite.

- [ ] **Step 5: Commit**
```bash
git add src/sphynx_gui/plot_grid.py tests/gui/test_plot_grid.py
git commit -m "feat(gui): S4b -- etogram panel in the plot grid"
```

---

### Task 5: act editor widget

**Files:** Create `src/sphynx_gui/act_editor.py`; Test `tests/gui/test_act_editor.py`.
**Interfaces:** `ActEditor(parent=None)` (QWidget) with `.set_zones(zones)`,
`.set_body_parts(names)`, `.load_act(act)`, `.to_act() -> Act`, `.binding` (QComboBox:
"single zone" / "zone class"), and signal `changed`.

- [ ] **Step 1: Write the failing test** — `tests/gui/test_act_editor.py`:
```python
import numpy as np
import pytest

from sphynx.acts import Act
from sphynx.zones import Zone
from sphynx_gui.act_editor import ActEditor


def _zones():
    mask = np.zeros((4, 4), dtype=bool)
    return [Zone("Center", "area", mask, zone_class="center"),
            Zone("Object1RealOut", "area", mask, zone_class="object_area", index=1),
            Zone("Object2RealOut", "area", mask, zone_class="object_area", index=2)]


def _editor(qtbot):
    editor = ActEditor()
    qtbot.addWidget(editor)
    editor.set_zones(_zones())
    editor.set_body_parts(["nose", "bodycenter", "tailbase"])
    return editor


def test_zone_list_comes_from_the_preset(qtbot):
    editor = _editor(qtbot)
    editor.binding.setCurrentText("single zone")
    items = [editor.zone_box.itemText(i) for i in range(editor.zone_box.count())]
    assert "Center" in items and "Object1RealOut" in items


def test_class_list_is_the_distinct_zone_classes(qtbot):
    editor = _editor(qtbot)
    editor.binding.setCurrentText("zone class")
    items = [editor.zone_box.itemText(i) for i in range(editor.zone_box.count())]
    assert "object_area" in items
    assert items.count("object_area") == 1          # distinct, not per zone


def test_round_trip_of_a_simple_act(qtbot):
    editor = _editor(qtbot)
    act = Act(name="nose_in_centre", type="simple", body_part="nose",
              zones=["Center"], speed_min=1.0, speed_max=8.0,
              min_duration_sec=0.4, max_gap_sec=0.2, median_window_sec=0.3)
    editor.load_act(act)
    back = editor.to_act()
    assert back.name == "nose_in_centre"
    assert back.body_part == "nose"
    assert back.zones == ["Center"]
    assert back.speed_min == 1.0
    assert back.speed_max == 8.0
    assert back.min_duration_sec == 0.4
    assert back.max_gap_sec == 0.2
    assert back.median_window_sec == 0.3


def test_required_parts_follow_the_chosen_body_part(qtbot):
    # The fallback chain is not a user setting; required_parts is simply what
    # the user declared.
    editor = _editor(qtbot)
    editor.load_act(Act(name="a", type="simple", body_part="nose"))
    back = editor.to_act()
    assert back.required_parts == ["nose"]
    assert back.fallback == {}


def test_editor_exposes_no_fallback_control(qtbot):
    editor = _editor(qtbot)
    assert not hasattr(editor, "fallback_box")


def test_class_binding_produces_a_family_selector_name(qtbot):
    editor = _editor(qtbot)
    editor.binding.setCurrentText("zone class")
    editor.zone_box.setCurrentText("object_area")
    editor.name_box.setText("nose_at_object")
    assert editor.is_family() is True
    assert editor.family_zone_class() == "object_area"


def test_single_binding_is_not_a_family(qtbot):
    editor = _editor(qtbot)
    editor.binding.setCurrentText("single zone")
    assert editor.is_family() is False


def test_changing_a_field_emits_changed(qtbot):
    editor = _editor(qtbot)
    with qtbot.waitSignal(editor.changed, timeout=500):
        editor.name_box.setText("renamed")
```
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/gui/test_act_editor.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'sphynx_gui.act_editor'`

- [ ] **Step 3: Write the implementation.** Create `src/sphynx_gui/act_editor.py`:
```python
"""Editor for one act: a form over the Act dataclass (S4b).

Deliberately absent: the body-part fallback chain. Choosing an arbitrary proxy
for a missing part is the silent substitution the engine exists to prevent, so
it is a curated decision rather than a control. The form sets `body_part`, and
`required_parts` follows from it.
"""

from __future__ import annotations

from PySide6.QtCore import Signal
from PySide6.QtWidgets import (
    QComboBox, QDoubleSpinBox, QFormLayout, QLineEdit, QWidget,
)

from sphynx.acts.schema import Act

SINGLE_ZONE = "single zone"
ZONE_CLASS = "zone class"


class ActEditor(QWidget):
    changed = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._zones: list = []

        self.name_box = QLineEdit()
        self.binding = QComboBox()
        self.binding.addItems([SINGLE_ZONE, ZONE_CLASS])
        self.zone_box = QComboBox()
        self.body_part_box = QComboBox()

        self.speed_min_box = QDoubleSpinBox()
        self.speed_min_box.setRange(0.0, 1000.0)
        self.speed_max_box = QDoubleSpinBox()
        self.speed_max_box.setRange(0.0, 1000.0)
        self.speed_max_box.setSpecialValueText("no limit")

        self.min_duration_box = QDoubleSpinBox()
        self.min_duration_box.setRange(0.0, 60.0)
        self.min_duration_box.setSingleStep(0.05)
        self.max_gap_box = QDoubleSpinBox()
        self.max_gap_box.setRange(0.0, 60.0)
        self.max_gap_box.setSingleStep(0.05)
        self.median_window_box = QDoubleSpinBox()
        self.median_window_box.setRange(0.0, 60.0)
        self.median_window_box.setSingleStep(0.05)

        form = QFormLayout(self)
        form.addRow("Name", self.name_box)
        form.addRow("Binding", self.binding)
        form.addRow("Zone / class", self.zone_box)
        form.addRow("Body part", self.body_part_box)
        form.addRow("Speed min, cm/s", self.speed_min_box)
        form.addRow("Speed max, cm/s", self.speed_max_box)
        form.addRow("Min duration, s", self.min_duration_box)
        form.addRow("Bridge gaps up to, s", self.max_gap_box)
        form.addRow("Median window, s", self.median_window_box)

        self.binding.currentTextChanged.connect(self._refill_zone_box)
        for widget in (self.name_box,):
            widget.textChanged.connect(self.changed)
        for widget in (self.binding, self.zone_box, self.body_part_box):
            widget.currentTextChanged.connect(self.changed)
        for widget in (self.speed_min_box, self.speed_max_box,
                       self.min_duration_box, self.max_gap_box,
                       self.median_window_box):
            widget.valueChanged.connect(self.changed)

    # --- inputs from the session ---
    def set_zones(self, zones) -> None:
        self._zones = list(zones or [])
        self._refill_zone_box()

    def set_body_parts(self, names) -> None:
        current = self.body_part_box.currentText()
        self.body_part_box.clear()
        self.body_part_box.addItems([str(n) for n in (names or [])])
        if current:
            self.body_part_box.setCurrentText(current)

    def _refill_zone_box(self) -> None:
        current = self.zone_box.currentText()
        self.zone_box.clear()
        if self.binding.currentText() == ZONE_CLASS:
            classes = []
            for zone in self._zones:
                zone_class = str(getattr(zone, "zone_class", "") or "")
                if zone_class and zone_class not in classes:
                    classes.append(zone_class)
            self.zone_box.addItems(classes)
        else:
            self.zone_box.addItems([str(getattr(z, "name", "")) for z in self._zones])
        if current:
            self.zone_box.setCurrentText(current)

    # --- model <-> form ---
    def is_family(self) -> bool:
        return self.binding.currentText() == ZONE_CLASS

    def family_zone_class(self) -> str:
        return self.zone_box.currentText() if self.is_family() else ""

    def load_act(self, act) -> None:
        self.name_box.setText(act.name)
        self.binding.setCurrentText(SINGLE_ZONE)
        self._refill_zone_box()
        if act.zones:
            self.zone_box.setCurrentText(str(act.zones[0]))
        if act.body_part:
            self.body_part_box.setCurrentText(str(act.body_part))
        self.speed_min_box.setValue(float(act.speed_min))
        self.speed_max_box.setValue(
            0.0 if act.speed_max == float("inf") else float(act.speed_max))
        self.min_duration_box.setValue(float(act.min_duration_sec))
        self.max_gap_box.setValue(float(act.max_gap_sec))
        self.median_window_box.setValue(float(act.median_window_sec))

    def to_act(self) -> Act:
        body_part = self.body_part_box.currentText()
        speed_max = self.speed_max_box.value()
        return Act(
            name=self.name_box.text().strip(),
            type="simple",
            zones=[] if self.is_family() else [self.zone_box.currentText()],
            body_part=body_part,
            required_parts=[body_part] if body_part else [],
            speed_min=self.speed_min_box.value(),
            speed_max=float("inf") if speed_max == 0.0 else speed_max,
            min_duration_sec=self.min_duration_box.value(),
            max_gap_sec=self.max_gap_box.value(),
            median_window_sec=self.median_window_box.value(),
        )
```
- [ ] **Step 4: Run tests to verify they pass**

Run: `PYTHONPATH=src python -m pytest tests/gui/test_act_editor.py -q`
Expected: PASS (8 passed)

- [ ] **Step 5: Commit**
```bash
git add src/sphynx_gui/act_editor.py tests/gui/test_act_editor.py
git commit -m "feat(gui): S4b -- act editor form"
```

---

### Task 6: Define Acts tab and controller

**Files:** Create `src/sphynx_gui/acts_controller.py`, `src/sphynx_gui/acts_tab.py`; Modify `src/sphynx_gui/state.py`; Test `tests/gui/test_acts_tab.py`.
**Interfaces:**
- `AppState` gains `library` (an `ActLibrary`, default empty) and signal `library_changed`.
- `ActsTab(state)` with `.list_widget`, `.editor`, `.preview_button`, `.preview_label`,
  `.preview_canvas`, `.controller`, `.new_button`, `.delete_button`, `.save_button`,
  `.load_button`.
- `ActsController(state, tab)` with `.refresh_list()`, `.rows` (list of
  `(name, source, overridden_by)`), `.add_act()`, `.delete_selected()`, `.apply_editor()`,
  `.preview()`.

> **NOTE for the controller:** this task wires the library, the paradigm and the loaded
> session together. Build it in the main loop, not via a transcribing implementer.

- [ ] **Step 1: Write the failing test** — `tests/gui/test_acts_tab.py` covering: the list
  shows built-in, paradigm and library acts with their source; a library act of the same
  name marks the paradigm row as overridden; adding an act puts it in
  `state.library.acts`; deleting removes it; preview without a loaded session says so;
  preview with a session reports percent/episodes/duration and states the frame range;
  saving and loading a library round-trips through a file.
- [ ] **Step 2: Run tests to verify they fail**
- [ ] **Step 3: Implement** the controller and the tab per the interfaces above. The
  source of each row: `builtin` for `acts_library_defaults`, `paradigm` for the resolved
  paradigm's acts and families, `library` for `state.library`. Preview evaluates the edited
  act against `state.result` through `apply_act` with an `ActContext` built from the
  session's traces and zones, then draws a one-row etogram.
- [ ] **Step 4: Run tests to verify they pass**, then the full suite.
- [ ] **Step 5: Commit**
```bash
git add src/sphynx_gui/acts_tab.py src/sphynx_gui/acts_controller.py src/sphynx_gui/state.py tests/gui/test_acts_tab.py
git commit -m "feat(gui): S4b -- Define Acts tab with preview"
```

---

### Task 7: make the tab live and check the slice end to end

**Files:** Modify `src/sphynx_gui/main_window.py`, `src/sphynx_gui/analyze_controller.py`; Test `tests/gui/test_main_window.py` (append), `tests/integration/test_library_on_demo.py`.
**Interfaces:** `MainWindow.acts_tab` is an `ActsTab`; the Analyze run passes
`state.library` to the engine.

- [ ] **Step 1: Write the failing tests** — append to `tests/gui/test_main_window.py`:
```python
def test_define_acts_tab_is_live(qtbot):
    from sphynx_gui.acts_tab import ActsTab

    window = MainWindow()
    qtbot.addWidget(window)
    assert isinstance(window.acts_tab, ActsTab)
    assert window.acts_tab.state is window.state


def test_four_tabs_remain_placeholders(qtbot):
    window = MainWindow()
    qtbot.addWidget(window)
    placeholders = [window.tabs.widget(i) for i in range(window.tabs.count())
                    if isinstance(window.tabs.widget(i), PlaceholderTab)]
    assert len(placeholders) == 4
```
  and `tests/integration/test_library_on_demo.py`:
```python
"""S4b acceptance: a hand-written library runs on the real demo session."""

from pathlib import Path

import pytest

from sphynx.acts import Act, ActFamily
from sphynx.acts.library_io import ActLibrary
from sphynx.config import Config
from sphynx.paradigms import PARADIGMS, register_builtin_paradigms
from sphynx.pipeline import analyze_session
from sphynx.zones import ZoneSelector

_ROOT = Path(__file__).resolve().parents[2]
_DLC = _ROOT / "Demo/DLC/NOF_H01_1DDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv"
_PRESET = _ROOT / "Demo/Preset_v2/NOF_H01_1D_Preset_v2.mat"

pytestmark = pytest.mark.skipif(
    not (_DLC.is_file() and _PRESET.is_file()),
    reason="Demo NOF_H01_1D data not present",
)


@pytest.fixture(autouse=True)
def _builtins():
    saved = dict(PARADIGMS)
    PARADIGMS.clear()
    register_builtin_paradigms()
    yield
    PARADIGMS.clear()
    PARADIGMS.update(saved)


@pytest.fixture(scope="module")
def _config():
    config = Config.default()
    config.paths.dlc = str(_DLC)
    config.paths.preset = str(_PRESET)
    config.io.save_workspace = False
    config.frames.end_frame = 3000
    config.verbose = "warn"
    return config


def test_library_family_runs_alongside_the_paradigm(_config):
    library = ActLibrary(families=[ActFamily(
        name="tail_at_object",
        selector=ZoneSelector(zone_class="object_area"),
        template=Act(name="tail_at_object", type="simple", body_part="tailbase",
                     required_parts=["tailbase"]))])
    result = analyze_session(_config, paradigm="EOF", library=library)
    names = [a.name for a in result.acts]
    assert "nose_at_object1" in names          # the paradigm's
    assert "tail_at_object1" in names          # the library's
    assert result.validation.ok is True


def test_overriding_a_paradigm_act_is_reported(_config):
    library = ActLibrary(families=[ActFamily(
        name="nose_at_object",
        selector=ZoneSelector(zone_class="object_area"),
        template=Act(name="nose_at_object", type="simple", body_part="nose",
                     required_parts=["nose"], min_duration_sec=1.0))])
    result = analyze_session(_config, paradigm="EOF", library=library)
    codes = [i.code for i in result.validation.issues]
    assert "act_overridden" in codes
    assert [a.name for a in result.acts].count("nose_at_object1") == 1
```
- [ ] **Step 2: Run tests to verify they fail**
- [ ] **Step 3: Implement.** In `main_window.py` build `self.acts_tab = ActsTab(self.state)`
  and put it in the "Define Acts" slot, dropping that entry from `_PLACEHOLDERS`. In
  `analyze_controller.py` pass the library into the worker:
  `AnalysisWorker(config, paradigm=..., library=self.state.library)`, and thread it through
  `AnalysisWorker.__init__`/`run` into `analyze_session`.
- [ ] **Step 4: Run tests to verify they pass**, then the full suite.
- [ ] **Step 5: Launch the app by hand**

Run: `PYTHONPATH=src python -m sphynx_gui.app`
Expected: Define Acts is live; building an act and pressing Preview shows numbers and an
etogram; the act then appears in the Analyze table after a run.

- [ ] **Step 6: Commit**
```bash
git add -A src/sphynx_gui tests
git commit -m "feat(gui): S4b -- Define Acts live, library used by the analysis"
```

---

## Task order

Dispatch 1, 2, 3, 4, 5, 6, 7 in order: Task 6 needs the editor from Task 5 and the merge
from Task 3; Task 7 needs the tab from Task 6.

## Done criteria
- `PYTHONPATH=src python -m pytest -q` green (616 + new).
- An act built in Define Acts previews on the loaded session with an etogram, saves to JSON,
  and takes part in the next Analyze run.
- A library act overriding a paradigm act is visible in the warnings panel.
- The etogram appears in the Analyze plot grid.
