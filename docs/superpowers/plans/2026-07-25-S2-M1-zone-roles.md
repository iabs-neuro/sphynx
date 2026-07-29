# S2 M1 — Zone roles + arena center + angle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Extend the `Zone` data model with declarative roles (`zone_class`, `roles`,
`index`, `angle`) and add arena-center + zone-angle geometry.

**Architecture:** Slice 1 of S2 (see docs/superpowers/specs/2026-07-25-S2-paradigms-acts-metrics-design.md,
layer 1). Roles live in geometry as the single source of truth. Arena center is the
centroid of the arena mask (auto), overridable manually. A zone's `angle` is its centroid's
angle relative to the arena center. Backward compatible: existing `Zone(name, "area", mask)`
positional construction keeps working via defaulted new fields.

**Tech Stack:** Python 3.11+, numpy; pytest.

## Global Constraints
- Python at repo ROOT; MATLAB reference under `matlab/`. Commands run from root with `PYTHONPATH=src`.
- No silent fallbacks (§10): invalid input RAISES a `SphynxError` subclass.
- ASCII only. TDD: failing test first.
- Backward compatibility: the 4 existing `Zone(name, "area", mask)` call sites
  (zones/strips.py, circle.py, square.py x2) must keep working unchanged — all new
  `Zone` fields carry defaults and come AFTER `maskfilled`.

---

### Task 1: ZoneRoles + extend Zone

**Files:** Modify `src/sphynx/zones/strips.py` (Zone dataclass), `src/sphynx/zones/__init__.py` (exports); Test `tests/unit/test_zone_roles.py`.
**Interfaces:** `ZoneRoles(is_target: bool = False, tags: list[str] = [])`; `Zone` gains
`zone_class: str = "unknown"`, `roles: ZoneRoles = ZoneRoles()`, `index: int | None = None`,
`angle: float | None = None` (all after `maskfilled`, all defaulted).

- [ ] **Step 1: Failing test** — `tests/unit/test_zone_roles.py`:
```python
import numpy as np

from sphynx.zones import Zone, ZoneRoles


def _mask():
    m = np.zeros((10, 10), dtype=bool)
    m[2:5, 2:5] = True
    return m


def test_zone_roles_defaults():
    r = ZoneRoles()
    assert r.is_target is False
    assert r.tags == []


def test_zone_roles_independent_tag_lists():
    a = ZoneRoles()
    a.tags.append("x")
    b = ZoneRoles()
    assert b.tags == []  # no shared mutable default


def test_legacy_positional_construction_still_works():
    z = Zone("arena", "area", _mask())
    assert z.name == "arena"
    assert z.type == "area"
    assert z.zone_class == "unknown"
    assert z.roles.is_target is False
    assert z.index is None
    assert z.angle is None


def test_full_construction():
    z = Zone("target", "area", _mask(), zone_class="hole",
             roles=ZoneRoles(is_target=True, tags=["primary"]), index=3, angle=1.5)
    assert z.zone_class == "hole"
    assert z.roles.is_target is True
    assert z.roles.tags == ["primary"]
    assert z.index == 3
    assert z.angle == 1.5
```
- [ ] **Step 2: Run — FAIL** (`PYTHONPATH=src python -m pytest tests/unit/test_zone_roles.py -q`).
- [ ] **Step 3: Implement.** In `src/sphynx/zones/strips.py`, replace the imports + `Zone`
  dataclass block:
```python
from dataclasses import dataclass, field
```
and replace the `Zone` class with:
```python
@dataclass
class ZoneRoles:
    """Declarative role tags set once at mask-draw time (S2 layer 1)."""

    is_target: bool = False
    tags: list = field(default_factory=list)


@dataclass
class Zone:
    name: str
    type: str
    maskfilled: np.ndarray
    zone_class: str = "unknown"       # hole|object|wall|corner|arena|composite|unknown
    roles: ZoneRoles = field(default_factory=ZoneRoles)
    index: int | None = None          # 1-based position within its zone_class
    angle: float | None = None        # centroid angle rel. arena center, radians
```
- [ ] **Step 4: Export.** In `src/sphynx/zones/__init__.py` add `ZoneRoles` to the strips
  import line and `__all__`:
```python
from sphynx.zones.strips import Zone, ZoneRoles, partition_strips
```
  and ensure `__all__` (create if absent) contains `"Zone"`, `"ZoneRoles"`,
  `"partition_strips"`, `"classify_circle"`, `"classify_square"`.
- [ ] **Step 5: Run — PASS** (4 passed). Then full suite `PYTHONPATH=src python -m pytest -q` (no regressions).
- [ ] **Step 6: Commit** `git add src/sphynx/zones/strips.py src/sphynx/zones/__init__.py tests/unit/test_zone_roles.py && git commit -m "feat(python): S2 M1 -- ZoneRoles + Zone role/class/index/angle fields"`

---

### Task 2: arena center + zone angle geometry

**Files:** Create `src/sphynx/zones/geometry.py`; Test `tests/unit/test_zone_geometry.py`.
**Interfaces:**
- `arena_centroid(mask) -> tuple[float, float]` — (cx, cy) mean of nonzero pixel coords (x=col, y=row). Raises `SphynxGeometryError` on empty mask.
- `resolve_arena_center(mask, manual=None) -> tuple[float, float]` — manual override wins (validated 2-number sequence), else `arena_centroid`.
- `mask_centroid(mask) -> tuple[float, float]` — same as arena_centroid (alias for any zone mask). Raises on empty.
- `zone_angle(zone_centroid, arena_center) -> float` — `atan2(dy, dx)` in radians, range (-pi, pi].

- [ ] **Step 1: Failing test** — `tests/unit/test_zone_geometry.py`:
```python
import math

import numpy as np
import pytest

from sphynx.exceptions import SphynxGeometryError
from sphynx.zones.geometry import (
    arena_centroid, mask_centroid, resolve_arena_center, zone_angle,
)


def _block(r0, r1, c0, c1, shape=(20, 20)):
    m = np.zeros(shape, dtype=bool)
    m[r0:r1, c0:c1] = True
    return m


def test_arena_centroid_center_of_block():
    m = _block(5, 15, 5, 15)  # rows 5..14, cols 5..14 -> centroid (9.5, 9.5)
    cx, cy = arena_centroid(m)
    assert cx == pytest.approx(9.5)
    assert cy == pytest.approx(9.5)


def test_arena_centroid_empty_raises():
    with pytest.raises(SphynxGeometryError):
        arena_centroid(np.zeros((5, 5), dtype=bool))


def test_resolve_manual_override():
    m = _block(5, 15, 5, 15)
    assert resolve_arena_center(m, manual=(3.0, 4.0)) == (3.0, 4.0)


def test_resolve_manual_bad_shape_raises():
    m = _block(5, 15, 5, 15)
    with pytest.raises(SphynxGeometryError):
        resolve_arena_center(m, manual=(1.0,))


def test_resolve_auto_falls_to_centroid():
    m = _block(5, 15, 5, 15)
    assert resolve_arena_center(m) == pytest.approx((9.5, 9.5))


def test_zone_angle_cardinals():
    center = (10.0, 10.0)
    assert zone_angle((20.0, 10.0), center) == pytest.approx(0.0)          # east
    assert zone_angle((10.0, 20.0), center) == pytest.approx(math.pi / 2)  # south (y down)
    assert zone_angle((0.0, 10.0), center) == pytest.approx(math.pi)       # west
    assert zone_angle((10.0, 0.0), center) == pytest.approx(-math.pi / 2)  # north


def test_mask_centroid_matches_arena():
    m = _block(0, 10, 0, 4)
    assert mask_centroid(m) == pytest.approx(arena_centroid(m))
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement.** `src/sphynx/zones/geometry.py`:
```python
"""Arena center + zone angle geometry (S2 layer 1)."""

from __future__ import annotations

import math

import numpy as np

from sphynx.exceptions import SphynxGeometryError


def arena_centroid(mask) -> tuple[float, float]:
    m = np.asarray(mask) > 0
    if not m.any():
        raise SphynxGeometryError("arena mask is empty; cannot compute centroid")
    ys, xs = np.nonzero(m)
    return float(xs.mean()), float(ys.mean())


def mask_centroid(mask) -> tuple[float, float]:
    return arena_centroid(mask)


def resolve_arena_center(mask, manual=None) -> tuple[float, float]:
    if manual is not None:
        seq = list(manual)
        if len(seq) != 2 or not all(np.isreal(v) for v in seq):
            raise SphynxGeometryError(
                f"manual arena center must be (x, y); got {manual!r}")
        return float(seq[0]), float(seq[1])
    return arena_centroid(mask)


def zone_angle(zone_centroid, arena_center) -> float:
    dx = float(zone_centroid[0]) - float(arena_center[0])
    dy = float(zone_centroid[1]) - float(arena_center[1])
    return math.atan2(dy, dx)
```
- [ ] **Step 4: Run — PASS** (7 passed), then full suite.
- [ ] **Step 5: Commit** `git add src/sphynx/zones/geometry.py tests/unit/test_zone_geometry.py && git commit -m "feat(python): S2 M1 -- arena center + zone angle geometry"`

---

### Task 3: assign angles + per-class indices to zones

**Files:** Modify `src/sphynx/zones/geometry.py` (add functions), `src/sphynx/zones/__init__.py` (exports); Test `tests/unit/test_zone_assign.py`.
**Interfaces:**
- `assign_zone_angles(zones, arena_center) -> None` — mutates each zone: sets `.angle = zone_angle(mask_centroid(z.maskfilled), arena_center)`. Skips empty masks (leaves angle None + warns via logger).
- `assign_zone_indices(zones) -> None` — mutates: within each `zone_class`, assigns 1-based `.index` in list order.

- [ ] **Step 1: Failing test** — `tests/unit/test_zone_assign.py`:
```python
import numpy as np

from sphynx.zones import Zone
from sphynx.zones.geometry import assign_zone_angles, assign_zone_indices


def _block(r0, r1, c0, c1, shape=(30, 30)):
    m = np.zeros(shape, dtype=bool)
    m[r0:r1, c0:c1] = True
    return m


def test_assign_angles_sets_each():
    center = (15.0, 15.0)
    east = Zone("e", "area", _block(14, 17, 24, 27), zone_class="hole")   # x>center
    north = Zone("n", "area", _block(3, 6, 14, 17), zone_class="hole")    # y<center
    zones = [east, north]
    assign_zone_angles(zones, center)
    assert abs(east.angle) < 0.4          # near 0 (east)
    assert north.angle < 0                # negative (north, y up)


def test_assign_indices_per_class():
    zones = [
        Zone("h1", "area", _block(0, 3, 0, 3), zone_class="hole"),
        Zone("o1", "area", _block(0, 3, 5, 8), zone_class="object"),
        Zone("h2", "area", _block(0, 3, 10, 13), zone_class="hole"),
    ]
    assign_zone_indices(zones)
    assert zones[0].index == 1  # first hole
    assert zones[1].index == 1  # first object
    assert zones[2].index == 2  # second hole
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement.** Append to `src/sphynx/zones/geometry.py`:
```python
from sphynx.logging_setup import get_logger

_log = get_logger()


def assign_zone_angles(zones, arena_center) -> None:
    for z in zones:
        m = np.asarray(z.maskfilled) > 0
        if not m.any():
            _log.warning('Zone "%s" has an empty mask; angle left None', z.name)
            continue
        z.angle = zone_angle(mask_centroid(m), arena_center)


def assign_zone_indices(zones) -> None:
    counters: dict = {}
    for z in zones:
        counters[z.zone_class] = counters.get(z.zone_class, 0) + 1
        z.index = counters[z.zone_class]
```
  (Place the `get_logger` import with the other imports at the top of the file rather than
  mid-file if the implementer prefers; behavior is identical.)
- [ ] **Step 4: Export.** In `src/sphynx/zones/__init__.py`, export the geometry helpers:
  add `from sphynx.zones.geometry import (arena_centroid, mask_centroid,
  resolve_arena_center, zone_angle, assign_zone_angles, assign_zone_indices)` and add those
  names to `__all__`.
- [ ] **Step 5: Run — PASS** (3 passed), then full suite `PYTHONPATH=src python -m pytest -q`.
- [ ] **Step 6: Commit** `git add src/sphynx/zones/geometry.py src/sphynx/zones/__init__.py tests/unit/test_zone_assign.py && git commit -m "feat(python): S2 M1 -- assign zone angles + per-class indices"`

---

## Done criteria
- `PYTHONPATH=src python -m pytest -q` green (S1 255 + M1 new).
- `Zone` carries zone_class/roles/index/angle (backward compatible); arena center + angle
  geometry available and exported from `sphynx.zones`.

## Next plan
- **M2:** zone selectors / composites (`select(zones, predicate) -> CompositeZone` union
  masks) + role-selectors. Then M2 boundary review.
