# S2 M2 — Zone selectors + composites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Declarative zone selection (`ZoneSelector` + `select`) and composite zones
(union of selected masks), plus role-selector helpers.

**Architecture:** Slice 2 of S2 (spec layer 2). A `ZoneSelector` is serializable data
(no lambdas) so paradigms and the New-paradigm save/load can carry it. `select(zones,
selector)` filters; `make_composite` unions the selected masks into a `Zone` with
`zone_class="composite"`. Role-selectors (target / neutral / all-of-class) are thin wrappers.

**Tech Stack:** Python 3.11+, numpy; pytest.

## Global Constraints
- Python at repo ROOT; commands from root with `PYTHONPATH=src`.
- No silent fallbacks (§10): invalid input RAISES a `SphynxError` subclass. An empty
  selection or mismatched mask shapes RAISE, never return a plausible empty/zero mask silently.
- ASCII only. TDD: failing test first.
- Composites are `Zone` instances (drop-in for acts/apply which read `.name`/`.maskfilled`);
  new `Zone.members` field is defaulted (backward compatible with all existing call sites).

---

### Task 1: ZoneSelector + select + Zone.members

**Files:** Modify `src/sphynx/zones/strips.py` (add `members` field to Zone); Create `src/sphynx/zones/select.py`; Modify `src/sphynx/zones/__init__.py`; Test `tests/unit/test_zone_select.py`.
**Interfaces:**
- `Zone` gains `members: list = []` (after `angle`, defaulted).
- `ZoneSelector(zone_class=None, is_target=None, tags_all=None, tags_any=None)` with
  `.matches(zone) -> bool` (None fields = don't-care; AND across set fields).
- `select(zones, selector) -> list[Zone]`.

- [ ] **Step 1: Failing test** — `tests/unit/test_zone_select.py`:
```python
import numpy as np

from sphynx.zones import Zone, ZoneRoles, ZoneSelector, select


def _m():
    a = np.zeros((8, 8), dtype=bool)
    a[1:3, 1:3] = True
    return a


def _zones():
    return [
        Zone("h1", "area", _m(), zone_class="hole",
             roles=ZoneRoles(is_target=True, tags=["primary"])),
        Zone("h2", "area", _m(), zone_class="hole", roles=ZoneRoles(is_target=False)),
        Zone("h3", "area", _m(), zone_class="hole", roles=ZoneRoles(is_target=False)),
        Zone("obj", "area", _m(), zone_class="object"),
    ]


def test_select_by_class():
    got = select(_zones(), ZoneSelector(zone_class="hole"))
    assert [z.name for z in got] == ["h1", "h2", "h3"]


def test_select_target_hole():
    got = select(_zones(), ZoneSelector(zone_class="hole", is_target=True))
    assert [z.name for z in got] == ["h1"]


def test_select_neutral_holes():
    got = select(_zones(), ZoneSelector(zone_class="hole", is_target=False))
    assert [z.name for z in got] == ["h2", "h3"]


def test_select_by_tag():
    got = select(_zones(), ZoneSelector(tags_any=["primary"]))
    assert [z.name for z in got] == ["h1"]


def test_selector_dontcare_matches_all():
    got = select(_zones(), ZoneSelector())
    assert len(got) == 4


def test_zone_members_defaults_empty():
    assert Zone("x", "area", _m()).members == []
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3a: Add members field.** In `src/sphynx/zones/strips.py`, in the `Zone`
  dataclass, add after the `angle` field:
```python
    members: list = field(default_factory=list)  # composite provenance (zone names)
```
- [ ] **Step 3b: Implement selector.** `src/sphynx/zones/select.py`:
```python
"""Declarative zone selection (S2 layer 2). Selectors are data, not lambdas,
so paradigms can serialize them."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class ZoneSelector:
    zone_class: str | None = None
    is_target: bool | None = None
    tags_all: list | None = None
    tags_any: list | None = None

    def matches(self, zone) -> bool:
        if self.zone_class is not None and zone.zone_class != self.zone_class:
            return False
        if self.is_target is not None and bool(zone.roles.is_target) != self.is_target:
            return False
        tags = set(zone.roles.tags)
        if self.tags_all is not None and not set(self.tags_all).issubset(tags):
            return False
        if self.tags_any is not None and tags.isdisjoint(set(self.tags_any)):
            return False
        return True


def select(zones, selector: ZoneSelector) -> list:
    return [z for z in zones if selector.matches(z)]
```
- [ ] **Step 4: Export.** In `src/sphynx/zones/__init__.py` add
  `from sphynx.zones.select import ZoneSelector, select` and add `"ZoneSelector"`,
  `"select"` to `__all__`.
- [ ] **Step 5: Run — PASS** (6 passed), then full suite `PYTHONPATH=src python -m pytest -q`.
- [ ] **Step 6: Commit** `git add src/sphynx/zones/strips.py src/sphynx/zones/select.py src/sphynx/zones/__init__.py tests/unit/test_zone_select.py && git commit -m "feat(python): S2 M2 -- ZoneSelector + select + Zone.members"`

---

### Task 2: union_mask + make_composite + role-selectors

**Files:** Modify `src/sphynx/zones/select.py` (add functions); Modify `src/sphynx/zones/__init__.py`; Test `tests/unit/test_zone_composite.py`.
**Interfaces:**
- `union_mask(zones) -> np.ndarray` — boolean OR of member masks. Raises `SphynxGeometryError` on empty list or mismatched shapes.
- `make_composite(name, zones, selector, zone_class="composite") -> Zone` — selects, unions, returns a `Zone` with `.members` = selected names. Raises `SphynxValueError` if the selection is empty (no silent empty mask).
- Role-selector wrappers: `target_zone(zones, zone_class="hole") -> Zone` (exactly one is_target; raises if 0 or >1), `neutral_composite(name, zones, zone_class="hole") -> Zone`, `class_composite(name, zones, zone_class) -> Zone`.

- [ ] **Step 1: Failing test** — `tests/unit/test_zone_composite.py`:
```python
import numpy as np
import pytest

from sphynx.exceptions import SphynxGeometryError, SphynxValueError
from sphynx.zones import Zone, ZoneRoles, ZoneSelector
from sphynx.zones.select import (
    class_composite, make_composite, neutral_composite, target_zone, union_mask,
)


def _m(r0, r1, c0, c1, shape=(8, 12)):
    a = np.zeros(shape, dtype=bool)
    a[r0:r1, c0:c1] = True
    return a


def _zones():
    return [
        Zone("h1", "area", _m(1, 3, 1, 3), zone_class="hole",
             roles=ZoneRoles(is_target=True)),
        Zone("h2", "area", _m(1, 3, 5, 7), zone_class="hole"),
        Zone("h3", "area", _m(1, 3, 9, 11), zone_class="hole"),
        Zone("obj", "area", _m(5, 7, 5, 7), zone_class="object"),
    ]


def test_union_mask_ors():
    zs = _zones()[:2]
    u = union_mask(zs)
    assert u.sum() == zs[0].maskfilled.sum() + zs[1].maskfilled.sum()


def test_union_mask_empty_raises():
    with pytest.raises(SphynxGeometryError):
        union_mask([])


def test_union_mask_shape_mismatch_raises():
    a = Zone("a", "area", np.zeros((8, 12), dtype=bool))
    b = Zone("b", "area", np.zeros((8, 10), dtype=bool))
    with pytest.raises(SphynxGeometryError):
        union_mask([a, b])


def test_make_composite_all_holes():
    c = make_composite("all_holes", _zones(), ZoneSelector(zone_class="hole"))
    assert c.zone_class == "composite"
    assert c.members == ["h1", "h2", "h3"]
    assert c.maskfilled.sum() == 3 * _m(1, 3, 1, 3).sum()


def test_make_composite_empty_selection_raises():
    with pytest.raises(SphynxValueError):
        make_composite("none", _zones(), ZoneSelector(zone_class="wall"))


def test_target_zone_unique():
    t = target_zone(_zones())
    assert t.name == "h1"


def test_target_zone_missing_raises():
    zs = [z for z in _zones() if z.name != "h1"]
    with pytest.raises(SphynxValueError):
        target_zone(zs)


def test_neutral_composite_excludes_target():
    c = neutral_composite("neutral", _zones())
    assert c.members == ["h2", "h3"]


def test_class_composite():
    c = class_composite("holes", _zones(), "hole")
    assert c.members == ["h1", "h2", "h3"]
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement.** Append to `src/sphynx/zones/select.py`:
```python
import numpy as np

from sphynx.exceptions import SphynxGeometryError, SphynxValueError
from sphynx.zones.strips import Zone


def union_mask(zones) -> np.ndarray:
    if not zones:
        raise SphynxGeometryError("union_mask needs at least one zone")
    masks = [np.asarray(z.maskfilled) > 0 for z in zones]
    shape = masks[0].shape
    for m in masks[1:]:
        if m.shape != shape:
            raise SphynxGeometryError(
                f"zone masks have mismatched shapes: {shape} vs {m.shape}")
    out = np.zeros(shape, dtype=bool)
    for m in masks:
        out |= m
    return out


def make_composite(name, zones, selector, zone_class: str = "composite") -> Zone:
    chosen = select(zones, selector)
    if not chosen:
        raise SphynxValueError(f'composite "{name}": selector matched no zones')
    z = Zone(name, "area", union_mask(chosen), zone_class=zone_class)
    z.members = [c.name for c in chosen]
    return z


def target_zone(zones, zone_class: str = "hole") -> Zone:
    hits = select(zones, ZoneSelector(zone_class=zone_class, is_target=True))
    if len(hits) != 1:
        raise SphynxValueError(
            f"expected exactly one target {zone_class}; found {len(hits)}")
    return hits[0]


def neutral_composite(name, zones, zone_class: str = "hole") -> Zone:
    return make_composite(
        name, zones, ZoneSelector(zone_class=zone_class, is_target=False))


def class_composite(name, zones, zone_class) -> Zone:
    return make_composite(name, zones, ZoneSelector(zone_class=zone_class))
```
- [ ] **Step 4: Export.** In `src/sphynx/zones/__init__.py` extend the select import to
  `from sphynx.zones.select import (ZoneSelector, select, union_mask, make_composite,
  target_zone, neutral_composite, class_composite)` and add those names to `__all__`.
- [ ] **Step 5: Run — PASS** (9 passed), then full suite.
- [ ] **Step 6: Commit** `git add src/sphynx/zones/select.py src/sphynx/zones/__init__.py tests/unit/test_zone_composite.py && git commit -m "feat(python): S2 M2 -- composites + role-selectors (union_mask/make_composite/target_zone)"`

---

## Done criteria
- `PYTHONPATH=src python -m pytest -q` green.
- `select`, `make_composite`, `target_zone`, `neutral_composite`, `class_composite`
  available from `sphynx.zones`; composites are drop-in `Zone`s with `.members`.

## Next plan
- **M3a:** act model v2 part 1 — part-resolution (explicit fallback chains) + post-filters
  + freezing/rear as library act properties.
