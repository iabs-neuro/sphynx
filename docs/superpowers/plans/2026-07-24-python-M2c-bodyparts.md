# Python engine — M2c bodyparts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Port body-part identification and geometry: `identify_parts` (+ `Point`),
`resolve_part`, `compute_center`, `relative_coords`.

**Architecture:** Approach C — mirror MATLAB `+bodyparts`. New `src/sphynx/bodyparts/`
package. Completes the body-part layer needed by acts/pipeline. Indices are 0-BASED
in Python (MATLAB was 1-based) — ported tests reflect this.

**Tech Stack:** Python 3.11+, numpy; pytest.

## Global Constraints
- Python at repo ROOT; MATLAB reference under `matlab/` (do not touch). Commands from root.
- No silent fallbacks (§10): `relative_coords` raises `SphynxValueError` when tailbase absent.
  `compute_center` intentionally synthesizes a center (mean of all parts, NaN-ignored)
  when no center marker exists — this is the documented graceful path, not a silent bug.
- Behavioural parity with MATLAB `+bodyparts`; tests ported from `matlab/tests/unit/`
  with indices converted 1-based -> 0-based.
- `Point` fields are snake_case canonicals; each is `int | None` (0-based index or None).
- TDD: failing test first.

---

### Task 1: bodyparts.identify_parts (+ Point)

**Files:** Create `src/sphynx/bodyparts/__init__.py`, `src/sphynx/bodyparts/identify.py`; Test `tests/unit/test_identify_parts.py`.
**Interfaces:** `Point` dataclass (fields: miniscope_ucla, nose, left_ear, right_ear,
head_center, left_fore_limb, right_fore_limb, left_body_center, right_body_center,
left_hind_limb, right_hind_limb, tailbase, center — each `int | None`);
`identify_parts(names: list[str]) -> Point`. Port of `sphynx.bodyparts.identifyParts`.

- [ ] **Step 1: Failing test** — `tests/unit/test_identify_parts.py`:
```python
from sphynx.bodyparts import identify_parts, Point


def test_finds_common_parts():
    p = identify_parts(["nose", "tailbase", "bodycenter", "leftear"])
    assert p.nose == 0
    assert p.tailbase == 1
    assert p.center == 2
    assert p.left_ear == 3


def test_case_insensitive():
    p = identify_parts(["Nose", "TAILBASE", "BodyCenter"])
    assert p.nose == 0 and p.tailbase == 1 and p.center == 2


def test_center_synonym():
    assert identify_parts(["mass center"]).center == 0


def test_tailbase_synonym():
    assert identify_parts(["tail base"]).tailbase == 0


def test_returns_none_for_missing():
    p = identify_parts(["nose"])
    assert p.tailbase is None and p.center is None


def test_superanimal_topviewmouse_schema():
    names = ["nose", "left_ear", "right_ear", "head_midpoint",
             "left_shoulder", "right_shoulder", "left_midside", "right_midside",
             "left_hip", "right_hip", "mouse_center", "tail_base"]
    p = identify_parts(names)
    assert p.nose == 0
    assert p.left_ear == 1
    assert p.right_ear == 2
    assert p.head_center == 3
    assert p.left_fore_limb == 4
    assert p.right_fore_limb == 5
    assert p.left_body_center == 6
    assert p.right_body_center == 7
    assert p.left_hind_limb == 8
    assert p.right_hind_limb == 9
    assert p.center == 10
    assert p.tailbase == 11


def test_center_prefers_direct_over_midside():
    p = identify_parts(["left_midside", "right_midside", "mouse_center"])
    assert p.center == 2
    assert p.left_body_center == 0
    assert p.right_body_center == 1
```
- [ ] **Step 2: Run — FAIL** (no module `sphynx.bodyparts`).
- [ ] **Step 3: Implement.** `src/sphynx/bodyparts/__init__.py`:
```python
"""Body-part identification and geometry."""

from sphynx.bodyparts.identify import Point, identify_parts

__all__ = ["Point", "identify_parts"]
```
`src/sphynx/bodyparts/identify.py`:
```python
"""Identify canonical body parts by alias. Port of
sphynx.bodyparts.identifyParts."""

from __future__ import annotations

from dataclasses import dataclass, fields


@dataclass
class Point:
    """Canonical body-part -> 0-based index (or None). Mirrors the MATLAB
    identifyParts struct."""

    miniscope_ucla: int | None = None
    nose: int | None = None
    left_ear: int | None = None
    right_ear: int | None = None
    head_center: int | None = None
    left_fore_limb: int | None = None
    right_fore_limb: int | None = None
    left_body_center: int | None = None
    right_body_center: int | None = None
    left_hind_limb: int | None = None
    right_hind_limb: int | None = None
    tailbase: int | None = None
    center: int | None = None


# canonical field -> accepted synonyms (lowercased). Single source of truth
# consulted by resolve_part, compute_center, relative_coords, acts.
_SYNONYMS: dict[str, tuple[str, ...]] = {
    "miniscope_ucla": ("miniscopeucla",),
    "nose": ("nose", "snout"),
    "left_ear": ("leftear", "left_ear", "left ear", "left_ear_tip"),
    "right_ear": ("rightear", "right_ear", "right ear", "right_ear_tip"),
    "head_center": ("headcenter", "head_midpoint", "head midpoint",
                    "head_center", "head center", "neck"),
    "left_fore_limb": ("leftforelimb", "left_forelimb", "left forelimb",
                       "left_shoulder", "left shoulder"),
    "right_fore_limb": ("righforelimb", "rightforelimb", "right_forelimb",
                        "right forelimb", "right_shoulder", "right shoulder"),
    "left_body_center": ("leftbody", "left_body", "left body",
                         "left_midside", "left midside"),
    "right_body_center": ("rightbody", "right_body", "right body",
                          "right_midside", "right midside"),
    "left_hind_limb": ("lefthindlimb", "left_hindlimb", "left hindlimb",
                       "left_hip", "left hip"),
    "right_hind_limb": ("righthindlimb", "right_hindlimb", "right hindlimb",
                        "right_hip", "right hip"),
    "tailbase": ("tailbase", "tail base", "tail_base", "tail1"),
    "center": ("mass centre", "mass center", "bodycenter", "body_center",
               "body center", "center", "mouse_center", "mouse center"),
}


def identify_parts(names) -> Point:
    """Map a list of DLC body-part labels onto canonical Point fields (first
    match wins, case-insensitive). Port of sphynx.bodyparts.identifyParts."""
    lowered = [str(n).strip().lower() for n in names]
    point = Point()
    for canon, syns in _SYNONYMS.items():
        for i, label in enumerate(lowered):
            if label in syns:
                setattr(point, canon, i)
                break
    return point
```
- [ ] **Step 4: Run — PASS** (7 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/bodyparts/__init__.py src/sphynx/bodyparts/identify.py tests/unit/test_identify_parts.py && git commit -m "feat(python): bodyparts.identify_parts + Point"`

---

### Task 2: bodyparts.resolve_part

**Files:** Create `src/sphynx/bodyparts/resolve.py`; Modify `src/sphynx/bodyparts/__init__.py` (export `resolve_part`); Test `tests/unit/test_resolve_part.py`.
**Interfaces:** `resolve_part(body_parts, query_name) -> int | None`. Exact
case-insensitive match first, else alias-via-canonical. Port of `resolvePart.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_resolve_part.py`:
```python
from sphynx.bodyparts import resolve_part


def test_exact_match_wins():
    assert resolve_part(["nose", "tailbase", "bodycenter"], "bodycenter") == 2


def test_exact_case_insensitive():
    assert resolve_part(["Nose", "TailBase", "BodyCenter"], "bodycenter") == 2


def test_superanimal_to_legacy_bodycenter():
    assert resolve_part(["nose", "tail_base", "mouse_center", "left_midside"], "bodycenter") == 2


def test_superanimal_to_legacy_tailbase():
    assert resolve_part(["nose", "mouse_center", "tail_base"], "tailbase") == 2


def test_superanimal_to_legacy_hindlimbs():
    parts = ["nose", "mouse_center", "left_hip", "right_hip"]
    assert resolve_part(parts, "lefthindlimb") == 2
    assert resolve_part(parts, "righthindlimb") == 3


def test_superanimal_to_legacy_headcenter():
    assert resolve_part(["nose", "head_midpoint", "mouse_center"], "headcenter") == 1


def test_reverse_direction_alias():
    assert resolve_part(["nose", "tailbase", "bodycenter"], "mouse_center") == 2


def test_returns_none_for_unknown():
    assert resolve_part(["nose", "tailbase"], "wholly_unknown_part") is None


def test_empty_inputs():
    assert resolve_part([], "bodycenter") is None
    assert resolve_part(["nose"], "") is None


def test_prefers_exact_over_synonym():
    assert resolve_part(["mouse_center", "bodycenter"], "bodycenter") == 1
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement.** `src/sphynx/bodyparts/resolve.py`:
```python
"""Alias-tolerant body-part lookup. Port of sphynx.bodyparts.resolvePart."""

from __future__ import annotations

from dataclasses import fields

from sphynx.bodyparts.identify import identify_parts


def resolve_part(body_parts, query_name) -> int | None:
    """Find a body-part index by alias-tolerant name match: exact
    (case-insensitive) first, else resolve query and list to the same
    canonical. Returns None if nothing matches."""
    if not body_parts or not query_name:
        return None
    q = str(query_name)

    lowered = [str(b).strip().lower() for b in body_parts]
    ql = q.strip().lower()
    if ql in lowered:
        return lowered.index(ql)

    q_point = identify_parts([q])
    canons = [f.name for f in fields(q_point) if getattr(q_point, f.name) is not None]
    if not canons:
        return None

    bp_point = identify_parts(body_parts)
    for canon in canons:
        idx = getattr(bp_point, canon)
        if idx is not None:
            return idx
    return None
```
Update `src/sphynx/bodyparts/__init__.py`:
```python
"""Body-part identification and geometry."""

from sphynx.bodyparts.identify import Point, identify_parts
from sphynx.bodyparts.resolve import resolve_part

__all__ = ["Point", "identify_parts", "resolve_part"]
```
- [ ] **Step 4: Run — PASS** (10 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/bodyparts/resolve.py src/sphynx/bodyparts/__init__.py tests/unit/test_resolve_part.py && git commit -m "feat(python): bodyparts.resolve_part"`

---

### Task 3: bodyparts.compute_center

**Files:** Create `src/sphynx/bodyparts/center.py`; Modify `__init__.py` (export `compute_center`); Test `tests/unit/test_compute_center.py`.
**Interfaces:** `compute_center(bpx, bpy, point) -> (xc, yc)` (1D arrays). Center row
if set; else mean of left/right body center; else NaN-ignored synthetic mean of all
rows. Empty input -> empty arrays. Port of `computeCenter.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_compute_center.py`:
```python
import numpy as np

from sphynx.bodyparts import compute_center, Point


def test_center_takes_precedence():
    bpx = np.array([[1.0, 2, 3], [10, 20, 30], [100, 200, 300]])
    bpy = np.array([[4.0, 5, 6], [40, 50, 60], [400, 500, 600]])
    p = Point(center=1, left_body_center=0, right_body_center=2)
    xc, yc = compute_center(bpx, bpy, p)
    assert np.array_equal(xc, [10, 20, 30])
    assert np.array_equal(yc, [40, 50, 60])


def test_falls_back_to_left_right_mean():
    bpx = np.array([[10.0, 20, 30], [30, 40, 50]])
    bpy = np.array([[5.0, 6, 7], [15, 16, 17]])
    p = Point(center=None, left_body_center=0, right_body_center=1)
    xc, yc = compute_center(bpx, bpy, p)
    assert np.array_equal(xc, [20, 30, 40])
    assert np.array_equal(yc, [10, 11, 12])


def test_synthetic_mean_when_none():
    bpx = np.array([[1.0, 2, 3], [3, 4, 5], [5, 6, 7]])
    bpy = np.array([[10.0, 20, 30], [30, 40, 50], [50, 60, 70]])
    p = Point()
    xc, yc = compute_center(bpx, bpy, p)
    assert np.array_equal(xc, [3, 4, 5])
    assert np.array_equal(yc, [30, 40, 50])


def test_nan_ignored_in_synthetic_mean():
    bpx = np.array([[np.nan, 2, 3], [3, 4, 5], [5, 6, np.nan]])
    bpy = np.array([[10.0, 20, 30], [30, 40, 50], [50, 60, 70]])
    xc, yc = compute_center(bpx, bpy, Point())
    assert np.array_equal(xc, [4, 4, 4])
    assert np.array_equal(yc, [30, 40, 50])


def test_empty_returns_empty():
    xc, yc = compute_center(np.array([]), np.array([]), Point())
    assert xc.size == 0 and yc.size == 0


def test_only_one_of_left_right_falls_through():
    bpx = np.array([[2.0, 4, 6], [8, 10, 12]])
    bpy = np.array([[1.0, 3, 5], [7, 9, 11]])
    p = Point(left_body_center=0, right_body_center=None)
    xc, yc = compute_center(bpx, bpy, p)
    assert np.array_equal(xc, [5, 7, 9])
    assert np.array_equal(yc, [4, 6, 8])
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement.** `src/sphynx/bodyparts/center.py`:
```python
"""Body-center trace. Port of sphynx.bodyparts.computeCenter."""

from __future__ import annotations

import numpy as np

from sphynx.bodyparts.identify import Point


def compute_center(bpx, bpy, point: Point):
    """Resolve the body-center: explicit center row, else mean of
    left+right body center, else NaN-ignored mean of all parts (synthetic).
    Empty input -> empty arrays."""
    bpx = np.asarray(bpx, dtype=float)
    bpy = np.asarray(bpy, dtype=float)
    if bpx.size == 0 or bpy.size == 0:
        return np.zeros(0), np.zeros(0)

    if point.center is not None:
        return bpx[point.center, :], bpy[point.center, :]

    if point.left_body_center is not None and point.right_body_center is not None:
        xc = (bpx[point.left_body_center, :] + bpx[point.right_body_center, :]) / 2.0
        yc = (bpy[point.left_body_center, :] + bpy[point.right_body_center, :]) / 2.0
        return xc, yc

    return np.nanmean(bpx, axis=0), np.nanmean(bpy, axis=0)
```
Update `__init__.py` to also export `compute_center` (add
`from sphynx.bodyparts.center import compute_center` and add to `__all__`).
- [ ] **Step 4: Run — PASS** (6 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/bodyparts/center.py src/sphynx/bodyparts/__init__.py tests/unit/test_compute_center.py && git commit -m "feat(python): bodyparts.compute_center"`

---

### Task 4: bodyparts.relative_coords

**Files:** Create `src/sphynx/bodyparts/relative.py`; Modify `__init__.py` (export `relative_coords`); Test `tests/unit/test_relative_coords.py`.
**Interfaces:** `relative_coords(bpx, bpy, point) -> dict` with keys `R`, `Theta`,
`AngleRot`. Tailbase-relative polar coords, body-axis rotated to theta=0. Raises
`SphynxValueError` if tailbase absent. Port of `relativeCoords.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_relative_coords.py`:
```python
import numpy as np
import pytest

from sphynx.bodyparts import relative_coords, Point
from sphynx.exceptions import SphynxValueError


def test_tailbase_row_zero_radius():
    bx = np.array([[0.0, 0], [5, 5], [8, 8]])
    by = np.array([[0.0, 0], [0, 0], [0, 0]])
    out = relative_coords(bx, by, Point(tailbase=0, center=1))
    assert np.allclose(out["R"][0, :], [0, 0], atol=1e-9)


def test_center_row_aligned_after_rotation():
    bx = np.array([[0.0, 0], [5, 5]])
    by = np.array([[0.0, 0], [5, 0]])
    out = relative_coords(bx, by, Point(tailbase=0, center=1))
    assert np.allclose(out["Theta"][1, :], [0, 0], atol=1e-9)


def test_angle_rot_matches_body_axis():
    bx = np.array([[0.0], [5]])
    by = np.array([[0.0], [0]])
    out = relative_coords(bx, by, Point(tailbase=0, center=1))
    assert np.allclose(out["AngleRot"], 0.0, atol=1e-9)


def test_fallback_center_from_left_right():
    bx = np.array([[0.0], [-2], [2]])
    by = np.array([[-1.0], [0], [0]])
    out = relative_coords(bx, by, Point(tailbase=0, left_body_center=1, right_body_center=2))
    assert np.allclose(out["AngleRot"], np.pi / 2, atol=1e-9)


def test_no_tailbase_raises():
    with pytest.raises(SphynxValueError):
        relative_coords(np.array([[1.0], [2]]), np.array([[1.0], [2]]),
                        Point(tailbase=None, center=1))
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement.** `src/sphynx/bodyparts/relative.py`:
```python
"""Tailbase-relative polar coords. Port of sphynx.bodyparts.relativeCoords."""

from __future__ import annotations

import numpy as np

from sphynx.angles import wrap
from sphynx.bodyparts.center import compute_center
from sphynx.bodyparts.identify import Point
from sphynx.exceptions import SphynxValueError


def relative_coords(bpx, bpy, point: Point) -> dict:
    """Body parts in tailbase-relative polar coords, body-axis rotated to
    theta=0. Returns {R, Theta, AngleRot}. Raises if tailbase absent."""
    if point.tailbase is None:
        raise SphynxValueError("Point.tailbase is required")
    bpx = np.asarray(bpx, dtype=float)
    bpy = np.asarray(bpy, dtype=float)

    xc, yc = compute_center(bpx, bpy, point)

    rel_x = bpx - bpx[point.tailbase, :]
    rel_y = bpy - bpy[point.tailbase, :]
    theta = np.arctan2(rel_y, rel_x)
    r = np.hypot(rel_x, rel_y)

    if point.center is not None:
        angle_rot = theta[point.center, :]
    else:
        c_rel_x = xc - bpx[point.tailbase, :]
        c_rel_y = yc - bpy[point.tailbase, :]
        angle_rot = np.arctan2(c_rel_y, c_rel_x)

    theta_rotated = wrap(theta - angle_rot)
    return {"R": r, "Theta": theta_rotated, "AngleRot": angle_rot}
```
Update `__init__.py` to export `relative_coords`.
- [ ] **Step 4: Run — PASS** (5 passed), then full suite `python -m pytest -q`.
- [ ] **Step 5: Commit** `git add src/sphynx/bodyparts/relative.py src/sphynx/bodyparts/__init__.py tests/unit/test_relative_coords.py && git commit -m "feat(python): bodyparts.relative_coords"`

---

## Done criteria
- `python -m pytest -q` green (M2b 92 + bodyparts tests).
- `sphynx.bodyparts` provides Point, identify_parts, resolve_part, compute_center, relative_coords.

## Next plan
- **M2d:** remaining preprocess — clean_body_part, auto_threshold, kalman_filter_2d,
  arena_exclusion_ring, detect_session_start_frame, apply_per_part_settings. Then the
  M2 whole-branch opus review.
