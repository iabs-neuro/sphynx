# S2 M4 — Act families Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Bind an act template to a zone CLASS and expand it into N concrete acts (one per
matching zone, inheriting that zone's roles/index), then merge the family's masks into ONE
labelled `EventStream`.

**Architecture:** Slice 4 of S2 (spec layer 3). This is the mechanism that removes the
MATLAB hardcodes: `NumObjects=19` disappears because a family expands over the zones that
actually exist, and `order_barnes` disappears because visit order is a generic query over a
merged `EventStream` (M5). A family declares a `ZoneSelector` (M2), never a zone name.

**Tech Stack:** Python 3.11+, numpy; pytest.

## Global Constraints
- Python at repo ROOT; commands from root with `PYTHONPATH=src`.
- No silent fallbacks (§10): a selector matching no zones RAISES `SphynxValueError`; a
  family member whose mask has not been computed RAISES rather than contributing nothing.
- ASCII only. TDD: failing test first.
- Acts and families never name a concrete zone: the binding is a selector. Concrete acts
  produced by expansion DO carry their source zone name -- that is provenance, not binding.
- Expansion must deep-copy the template: concrete acts must not share the template's
  mutable fields (`zones`, `fallback`, `required_parts`).

---

### Task 1: act provenance fields + ActFamily + expand_family

**Files:** Modify `src/sphynx/acts/schema.py` (Act provenance fields); Create `src/sphynx/acts/families.py`; Modify `src/sphynx/acts/__init__.py`; Test `tests/unit/test_act_families.py`.
**Interfaces:**
- `Act` gains `family: str = ""`, `zone_name: str = ""`, `zone_index: int | None = None`,
  `is_target: bool = False` (all defaulted, appended last).
- `ActFamily(name: str, selector: ZoneSelector, template: Act, name_pattern: str = "{family}{index}")`.
- `expand_family(family, zones) -> list[Act]`.

- [ ] **Step 1: Failing test** — `tests/unit/test_act_families.py`:
```python
import numpy as np
import pytest

from sphynx.acts import Act, ActFamily, expand_family
from sphynx.exceptions import SphynxValueError
from sphynx.zones import Zone, ZoneRoles, ZoneSelector
from sphynx.zones.geometry import assign_zone_indices


def _m():
    a = np.zeros((8, 8), dtype=bool)
    a[1:3, 1:3] = True
    return a


def _zones():
    zs = [
        Zone("hole_a", "area", _m(), zone_class="hole"),
        Zone("hole_b", "area", _m(), zone_class="hole",
             roles=ZoneRoles(is_target=True)),
        Zone("hole_c", "area", _m(), zone_class="hole"),
        Zone("obj", "area", _m(), zone_class="object"),
    ]
    assign_zone_indices(zs)
    return zs


def _family(**kw):
    template = Act(name="template", type="simple", body_part="nose",
                   min_duration_sec=0.0, max_gap_sec=0.0)
    kw.setdefault("name", "nose_at_hole")
    kw.setdefault("selector", ZoneSelector(zone_class="hole"))
    kw.setdefault("template", template)
    return ActFamily(**kw)


def test_expands_one_act_per_matching_zone():
    acts = expand_family(_family(), _zones())
    assert len(acts) == 3                       # three holes, not the object
    assert [a.name for a in acts] == [
        "nose_at_hole1", "nose_at_hole2", "nose_at_hole3"]


def test_each_act_binds_its_own_zone():
    acts = expand_family(_family(), _zones())
    assert [a.zones for a in acts] == [["hole_a"], ["hole_b"], ["hole_c"]]


def test_provenance_carries_zone_identity_and_roles():
    acts = expand_family(_family(), _zones())
    assert [a.zone_name for a in acts] == ["hole_a", "hole_b", "hole_c"]
    assert [a.zone_index for a in acts] == [1, 2, 3]
    assert [a.is_target for a in acts] == [False, True, False]
    assert all(a.family == "nose_at_hole" for a in acts)


def test_template_fields_are_inherited():
    acts = expand_family(_family(), _zones())
    assert all(a.body_part == "nose" for a in acts)
    assert all(a.type == "simple" for a in acts)


def test_expansion_deep_copies_mutable_template_fields():
    template = Act(name="t", type="simple", body_part="nose",
                   required_parts=["nose"], fallback={"nose": ["headcenter"]})
    acts = expand_family(_family(template=template), _zones())
    acts[0].required_parts.append("tailbase")
    acts[0].fallback["nose"].append("bodycenter")
    assert acts[1].required_parts == ["nose"]
    assert acts[1].fallback["nose"] == ["headcenter"]
    assert template.required_parts == ["nose"]


def test_family_count_follows_the_geometry_not_a_constant():
    # The point of the milestone: no NumObjects hardcode.
    zs = _zones()[:2] + [Zone("hole_d", "area", _m(), zone_class="hole")]
    assign_zone_indices(zs)
    assert len(expand_family(_family(), zs)) == 3
    assert len(expand_family(_family(), _zones())) == 3


def test_role_selector_expands_to_the_target_only():
    fam = _family(name="nose_at_target",
                  selector=ZoneSelector(zone_class="hole", is_target=True))
    acts = expand_family(fam, _zones())
    assert len(acts) == 1
    assert acts[0].zone_name == "hole_b"
    assert acts[0].is_target is True


def test_custom_name_pattern():
    fam = _family(name_pattern="{family}_{zone}")
    acts = expand_family(fam, _zones())
    assert acts[0].name == "nose_at_hole_hole_a"


def test_empty_selection_raises():
    fam = _family(selector=ZoneSelector(zone_class="wall"))
    with pytest.raises(SphynxValueError):
        expand_family(fam, _zones())


def test_missing_zone_index_falls_back_to_position():
    zs = [Zone("h1", "area", _m(), zone_class="hole"),
          Zone("h2", "area", _m(), zone_class="hole")]      # indices never assigned
    acts = expand_family(_family(), zs)
    assert [a.zone_index for a in acts] == [1, 2]
```
- [ ] **Step 2: Run — FAIL** (`PYTHONPATH=src python -m pytest tests/unit/test_act_families.py -q`).
- [ ] **Step 3a: Add provenance fields.** In `src/sphynx/acts/schema.py`, in the `Act`
  dataclass, append after the `expr` field:
```python
    # Provenance, set when a family expands over the geometry (S2 layer 3).
    family: str = ""
    zone_name: str = ""
    zone_index: int | None = None
    is_target: bool = False
```
- [ ] **Step 3b: Implement families.** `src/sphynx/acts/families.py`:
```python
"""Act families: one template bound to a zone CLASS, expanded over the geometry.

A family declares a ZoneSelector, never a zone name. Expansion produces one
concrete act per matching zone, inheriting that zone's identity and roles, which
is what removes the MATLAB `NumObjects=19` hardcode: the family is as large as
the preset actually is (S2 layer 3).
"""

from __future__ import annotations

import copy
from dataclasses import dataclass, field

from sphynx.acts.schema import Act
from sphynx.exceptions import SphynxValueError
from sphynx.logging_setup import get_logger
from sphynx.zones.select import ZoneSelector, select

_log = get_logger()


@dataclass
class ActFamily:
    name: str = ""
    selector: ZoneSelector = field(default_factory=ZoneSelector)
    template: Act = field(default_factory=Act)
    name_pattern: str = "{family}{index}"


def expand_family(family: ActFamily, zones) -> list[Act]:
    """Expand a family into one concrete act per zone matching its selector."""
    chosen = select(zones, family.selector)
    if not chosen:
        raise SphynxValueError(
            f'act family "{family.name}": selector matched no zones')

    acts: list[Act] = []
    for position, z in enumerate(chosen, start=1):
        # deep copy so members never share the template's mutable fields
        act = copy.deepcopy(family.template)
        idx = z.index
        if idx is None:
            _log.warning(
                'Zone "%s" has no class index; numbering family "%s" by position',
                z.name, family.name)
            idx = position
        act.name = family.name_pattern.format(
            family=family.name, index=idx, zone=z.name)
        act.zones = [z.name]
        act.family = family.name
        act.zone_name = z.name
        act.zone_index = idx
        act.is_target = bool(z.roles.is_target)
        acts.append(act)
    return acts
```
- [ ] **Step 4: Export.** In `src/sphynx/acts/__init__.py` add
  `from sphynx.acts.families import ActFamily, expand_family` and add `"ActFamily"`,
  `"expand_family"` to `__all__`.
- [ ] **Step 5: Run — PASS** (10 passed), then full suite `PYTHONPATH=src python -m pytest -q`.
- [ ] **Step 6: Commit** `git add src/sphynx/acts/schema.py src/sphynx/acts/families.py src/sphynx/acts/__init__.py tests/unit/test_act_families.py && git commit -m "feat(python): S2 M4 -- act families expand over the geometry"`

---

### Task 2: merged family EventStream

**Files:** Modify `src/sphynx/acts/events.py`, `src/sphynx/acts/families.py`; Modify `src/sphynx/acts/__init__.py`; Test `tests/unit/test_family_events.py`.
**Interfaces:**
- `Event` gains `is_target: bool = False`.
- `events_from_act(..., is_target: bool = False)`.
- `family_event_stream(acts, results, frame_rate, family=None) -> EventStream` — merges
  every family member's episodes into ONE time-ordered stream, each event labelled with its
  source zone. Raises `SphynxValueError` when a member's mask is absent from `results`.

- [ ] **Step 1: Failing test** — `tests/unit/test_family_events.py`:
```python
import numpy as np
import pytest

from sphynx.acts import Act, EventStream, family_event_stream
from sphynx.exceptions import SphynxValueError

FPS = 10.0


def _member(name, zone, index, is_target=False):
    return Act(name=name, type="simple", family="nose_at_hole",
               zone_name=zone, zone_index=index, is_target=is_target)


def _acts():
    return [
        _member("nose_at_hole1", "hole_a", 1),
        _member("nose_at_hole2", "hole_b", 2, is_target=True),
        _member("nose_at_hole3", "hole_c", 3),
    ]


def _results():
    a = np.zeros(20, dtype=bool)
    a[10:12] = True                     # third visit
    b = np.zeros(20, dtype=bool)
    b[5:7] = True                       # second visit (the target)
    c = np.zeros(20, dtype=bool)
    c[1:3] = True                       # first visit
    return {"nose_at_hole1": a, "nose_at_hole2": b, "nose_at_hole3": c}


def test_merged_stream_is_time_ordered():
    st = family_event_stream(_acts(), _results(), FPS)
    assert isinstance(st, EventStream)
    assert [e.start_frame for e in st.events] == [1, 5, 10]


def test_events_carry_zone_provenance():
    st = family_event_stream(_acts(), _results(), FPS)
    assert [e.label for e in st.events] == ["hole_c", "hole_b", "hole_a"]
    assert [e.index for e in st.events] == [3, 2, 1]
    assert [e.is_target for e in st.events] == [False, True, False]


def test_visit_order_is_a_generic_query():
    # This is what replaces the hardcoded order_barnes.
    st = family_event_stream(_acts(), _results(), FPS)
    assert st.unique_labels() == ["hole_c", "hole_b", "hole_a"]
    assert st.order_of("hole_b") == 1


def test_labels_before_the_target_is_a_generic_query():
    # And this is what replaces bespoke primary-error counting.
    st = family_event_stream(_acts(), _results(), FPS)
    target = st.first_where(lambda e: e.is_target)
    assert target is not None
    assert st.labels_before(target) == ["hole_c"]


def test_family_filter_selects_members():
    acts = _acts() + [Act(name="other", type="simple", family="rear_at_wall",
                          zone_name="wall_a", zone_index=1)]
    results = dict(_results())
    results["other"] = np.ones(20, dtype=bool)
    st = family_event_stream(acts, results, FPS, family="nose_at_hole")
    assert all(e.act.startswith("nose_at_hole") for e in st.events)


def test_missing_member_result_raises():
    results = _results()
    del results["nose_at_hole2"]
    with pytest.raises(SphynxValueError):
        family_event_stream(_acts(), results, FPS)


def test_durations_use_the_frame_rate():
    st = family_event_stream(_acts(), _results(), FPS)
    assert st.events[0].duration_s == pytest.approx(0.2)   # 2 frames at 10 fps


def test_empty_family_yields_empty_stream():
    st = family_event_stream([], {}, FPS)
    assert st.events == []


def test_no_events_when_no_member_fires():
    results = {k: np.zeros(20, dtype=bool) for k in _results()}
    st = family_event_stream(_acts(), results, FPS)
    assert st.events == []
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3a: Add is_target to the events layer.** In `src/sphynx/acts/events.py`, add
  to the `Event` dataclass after `index`:
```python
    is_target: bool = False
```
  and change `events_from_act` to accept and pass it, so its signature and body read:
```python
def events_from_act(
    act_mask, frame_rate: float, act_name: str = "", label: str | None = None,
    index: int | None = None, is_target: bool = False,
) -> list[Event]:
    """Derive episodes from a binary act trace (no refinement applied here)."""
    _, runs = refine_act(act_mask, 0, 0)
    return [
        Event(act_name, r.frame_in, r.frame_out, r.duration / frame_rate, label,
              index, is_target)
        for r in runs
    ]
```
- [ ] **Step 3b: Implement the merge.** Append to `src/sphynx/acts/families.py`:
```python
from sphynx.acts.events import EventStream, events_from_act


def family_event_stream(acts, results, frame_rate, family=None) -> EventStream:
    """Merge a family's per-member episodes into ONE time-ordered stream.

    Every event is labelled with the zone it came from, so order-of-visit and
    errors-before-target become generic queries over the stream instead of
    bespoke per-paradigm code (S2 layer 3 -> layer 5)."""
    members = [
        a for a in acts
        if (a.family if family is None else a.family == family) and a.family
    ]
    events = []
    for act in members:
        if act.name not in results:
            raise SphynxValueError(
                f'family member "{act.name}" has no computed result')
        events.extend(events_from_act(
            results[act.name], frame_rate, act_name=act.name,
            label=act.zone_name or act.name, index=act.zone_index,
            is_target=act.is_target))
    events.sort(key=lambda e: (e.start_frame, e.end_frame))
    return EventStream(events)
```
- [ ] **Step 4: Export.** In `src/sphynx/acts/__init__.py` add `family_event_stream` to the
  families import line and to `__all__`.
- [ ] **Step 5: Run — PASS** (9 passed), then full suite.
- [ ] **Step 6: Commit** `git add src/sphynx/acts/events.py src/sphynx/acts/families.py src/sphynx/acts/__init__.py tests/unit/test_family_events.py && git commit -m "feat(python): S2 M4 -- merged family EventStream (labelled by source zone)"`

---

## Done criteria
- `PYTHONPATH=src python -m pytest -q` green (M3b 359 + M4 new).
- A family expands over the zones that exist (no count constant anywhere), members carry
  zone provenance and roles, and their episodes merge into one labelled stream where visit
  order and errors-before-target are generic queries.

## Next plan
- **M5:** named-metric registry (`@register_metric` with explicit deps), universal
  act-derived metrics over Events (`visit_order`, `time_to_first`, `primary_errors`), and
  `ratio_index(a, b)`. Then the M4+M5 boundary review (opus).
