# Python engine — M3 zones + preset geometry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Port the pure zone/preset geometry: `mask_from_border`, `partition_strips`,
`classify_circle`, `classify_square` (round-corner mode), `pixels_per_cm` (headless math).

**Architecture:** Approach C — mirror MATLAB `+zones` and `+preset`. scipy.ndimage EDT
replaces bwdist; matplotlib.path replaces inpolygon. Deferred to M3b (preset-build,
GUI-time, off the analysis critical path): square-corner-mode of classify_square, the
PCA/ArenaVertices strip path, the strips `_realout` augmentation, and interactive
functions (readArenaGeometry drawing, readObjects, readFrameAt, pickGoodFrame,
marqueeSelect) which belong to the GUI spec S4.

**Tech Stack:** Python 3.11+, numpy, scipy.ndimage, matplotlib; pytest.

## Global Constraints
- Python at repo ROOT; MATLAB reference under `matlab/` (do not touch). Commands from root.
- No silent fallbacks (§10): missing PixelsPerCm/CornerPoints, invalid N/direction/strategy
  raise `SphynxValueError`.
- Behavioural parity with MATLAB sources; tests ported from `matlab/tests/unit/`.
  Masks stay HxW; corner/point coords are 1-based image coords (as in the MATLAB tests).
- `bwdist(BW)` maps to `scipy.ndimage.distance_transform_edt(~BW)`.
- TDD: failing test first.

---

### Task 1: preset.mask_from_border

**Files:** Create `src/sphynx/preset/__init__.py`, `src/sphynx/preset/mask.py`; Test `tests/unit/test_mask_from_border.py`.
**Interfaces:** `mask_from_border(h, w, x, y) -> np.ndarray` (HxW bool). Port of `maskFromBorder.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_mask_from_border.py`:
```python
import numpy as np

from sphynx.preset import mask_from_border


def test_marks_rounded_pixels():
    m = mask_from_border(10, 10, [3.4, 5.7], [2.1, 8.6])
    assert m[1, 2]   # round(2.1)=2 row, round(3.4)=3 col -> 0-based [1,2]
    assert m[8, 5]   # round(8.6)=9 row, round(5.7)=6 col -> 0-based [8,5]
    assert m.sum() == 2


def test_skips_out_of_bounds():
    m = mask_from_border(10, 10, [0, 11, 5], [5, 5, 12])
    assert m.sum() == 0
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement.** `src/sphynx/preset/__init__.py`:
```python
"""Preset geometry: zone/arena mask construction and calibration."""

from sphynx.preset.mask import mask_from_border

__all__ = ["mask_from_border"]
```
`src/sphynx/preset/mask.py`:
```python
"""Build a border mask from polyline points. Port of
sphynx.preset.maskFromBorder."""

from __future__ import annotations

import numpy as np


def mask_from_border(h: int, w: int, x, y) -> np.ndarray:
    """HxW bool mask, True at each in-bounds rounded (x, y). Coords are
    1-based image coords; out-of-bounds points are skipped."""
    mask = np.zeros((h, w), dtype=bool)
    xi = np.round(np.asarray(x, dtype=float).ravel()).astype(int)
    yi = np.round(np.asarray(y, dtype=float).ravel()).astype(int)
    valid = (xi >= 1) & (xi <= w) & (yi >= 1) & (yi <= h)
    mask[yi[valid] - 1, xi[valid] - 1] = True
    return mask
```
- [ ] **Step 4: Run — PASS** (2 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/preset/__init__.py src/sphynx/preset/mask.py tests/unit/test_mask_from_border.py && git commit -m "feat(python): preset.mask_from_border"`

---

### Task 2: zones.partition_strips (+ Zone)

**Files:** Create `src/sphynx/zones/__init__.py`, `src/sphynx/zones/strips.py`; Test `tests/unit/test_partition_strips.py`.
**Interfaces:** `Zone` dataclass (name: str, type: str, maskfilled: np.ndarray);
`partition_strips(arena_mask, n, direction) -> list[Zone]`. Axis-aligned equal strips.
Raises `SphynxValueError` on non-integer/<1 N or unknown direction. Port of
`partitionStrips.m` (axis-aligned path; PCA/ArenaVertices deferred to M3b).

- [ ] **Step 1: Failing test** — `tests/unit/test_partition_strips.py`:
```python
import numpy as np
import pytest

from sphynx.zones import partition_strips, Zone
from sphynx.exceptions import SphynxValueError


def test_three_horizontal_strips():
    zones = partition_strips(np.ones((30, 60), bool), 3, "horizontal")
    assert len(zones) == 3
    assert zones[0].name == "strip1"
    for z in zones:
        assert 30 * 60 / 3 - 60 < z.maskfilled.sum() < 30 * 60 / 3 + 60


def test_two_vertical_strips():
    zones = partition_strips(np.ones((20, 40), bool), 2, "vertical")
    assert len(zones) == 2
    assert zones[0].maskfilled[9, 4]      # left half
    assert not zones[0].maskfilled[9, 34]
    assert zones[1].maskfilled[9, 34]     # right half
    assert not zones[1].maskfilled[9, 4]


def test_rejects_zero_strips():
    with pytest.raises(SphynxValueError):
        partition_strips(np.ones((10, 10), bool), 0, "horizontal")


def test_rejects_unknown_direction():
    with pytest.raises(SphynxValueError):
        partition_strips(np.ones((10, 10), bool), 3, "diagonal")


def test_strips_partition_arena():
    m = np.zeros((20, 30), bool)
    m[4:15, 4:25] = True
    zones = partition_strips(m, 4, "horizontal")
    summed = np.zeros((20, 30), bool)
    for z in zones:
        assert not (summed & z.maskfilled).any()
        summed |= z.maskfilled
    assert np.array_equal(summed, m)
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement.** `src/sphynx/zones/__init__.py`:
```python
"""Zone classification (rings, corners/walls/center, strips)."""

from sphynx.zones.strips import Zone, partition_strips

__all__ = ["Zone", "partition_strips"]
```
`src/sphynx/zones/strips.py`:
```python
"""Split an arena mask into N equal strips. Port of
sphynx.zones.partitionStrips (axis-aligned path)."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from sphynx.exceptions import SphynxValueError


@dataclass
class Zone:
    name: str
    type: str
    maskfilled: np.ndarray


def partition_strips(arena_mask, n, direction: str) -> list[Zone]:
    mask = np.asarray(arena_mask) > 0
    if not float(n).is_integer() or n < 1:
        raise SphynxValueError(f"N must be a positive integer; got {n}")
    n = int(n)
    if direction not in ("horizontal", "vertical"):
        raise SphynxValueError(f"direction must be horizontal|vertical; got {direction}")
    h, w = mask.shape
    if not mask.any():
        raise SphynxValueError("arena_mask is empty")

    ys, xs = np.nonzero(mask)
    zones: list[Zone] = []
    if direction == "horizontal":
        lo0, hi0 = int(ys.min()), int(ys.max())
    else:
        lo0, hi0 = int(xs.min()), int(xs.max())
    span = hi0 - lo0 + 1

    for i in range(n):
        lo = lo0 + round(i * span / n)
        hi = lo0 + round((i + 1) * span / n) - 1
        m = np.zeros((h, w), dtype=bool)
        if direction == "horizontal":
            lo = max(lo, 0)
            hi = min(hi, h - 1)
            m[lo : hi + 1, :] = True
        else:
            lo = max(lo, 0)
            hi = min(hi, w - 1)
            m[:, lo : hi + 1] = True
        zones.append(Zone(f"strip{i + 1}", "area", m & mask))
    return zones
```
- [ ] **Step 4: Run — PASS** (5 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/zones/__init__.py src/sphynx/zones/strips.py tests/unit/test_partition_strips.py && git commit -m "feat(python): zones.partition_strips + Zone"`

---

### Task 3: zones.classify_circle

**Files:** Create `src/sphynx/zones/circle.py`; Modify `src/sphynx/zones/__init__.py` (export `classify_circle`); Test `tests/unit/test_classify_circle.py`.
**Interfaces:** `classify_circle(arena_mask, pixels_per_cm, wall_width_cm=10,
middle_width_cm=20, min_center_cm=10) -> list[Zone]`. Concentric rings
wall/middle1../center. Raises `SphynxValueError` if pixels_per_cm missing/<=0.
Port of `classifyCircle.m`.

- [ ] **Step 1: Failing test** — `tests/unit/test_classify_circle.py`:
```python
import numpy as np

from sphynx.zones import classify_circle


def _circle(h, w, cx, cy, r):
    yy, xx = np.mgrid[1 : h + 1, 1 : w + 1]  # 1-based grid like MATLAB
    return (xx - cx) ** 2 + (yy - cy) ** 2 <= r**2


def test_small_arena_wall_and_center():
    m = _circle(200, 200, 100, 100, 30 * 2)
    names = [z.name for z in classify_circle(m, 2, wall_width_cm=10, middle_width_cm=20)]
    assert "wall" in names and "middle1" in names and "center" in names


def test_large_arena_middle_rings():
    m = _circle(400, 400, 200, 200, 80 * 2)
    names = [z.name for z in classify_circle(m, 2, wall_width_cm=10, middle_width_cm=20)]
    for nm in ("wall", "middle1", "middle2", "middle3", "center"):
        assert nm in names


def test_center_always_added_even_if_narrow():
    m = _circle(200, 200, 100, 100, 15 * 2)
    names = [z.name for z in classify_circle(m, 2, wall_width_cm=10, middle_width_cm=20, min_center_cm=10)]
    assert "wall" in names and "center" in names and "middle1" not in names


def test_zones_partition_arena():
    m = _circle(300, 300, 150, 150, 60 * 2)
    zones = classify_circle(m, 2, wall_width_cm=10, middle_width_cm=20)
    summed = np.zeros_like(m)
    for z in zones:
        assert not (summed & z.maskfilled).any()
        summed |= z.maskfilled
    assert np.array_equal(summed, m)


def test_arena_touching_frame_edge():
    m = _circle(200, 200, 60, 60, 60 * 2)
    zones = classify_circle(m, 2, wall_width_cm=10, middle_width_cm=20)
    wall = next(z for z in zones if z.name == "wall")
    assert wall.maskfilled.sum() > 0
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** `src/sphynx/zones/circle.py`:
```python
"""Ring-based zone classification for a round arena. Port of
sphynx.zones.classifyCircle."""

from __future__ import annotations

import numpy as np
from scipy.ndimage import distance_transform_edt

from sphynx.exceptions import SphynxError, SphynxValueError
from sphynx.zones.strips import Zone


def classify_circle(
    arena_mask, pixels_per_cm, wall_width_cm: float = 10, middle_width_cm: float = 20,
    min_center_cm: float = 10,  # accepted for compat; no effect on emitted zones
) -> list[Zone]:
    if pixels_per_cm is None or pixels_per_cm <= 0:
        raise SphynxValueError("pixels_per_cm is required")
    mask = np.asarray(arena_mask) > 0
    h, w = mask.shape
    wall_w = wall_width_cm * pixels_per_cm
    mid_w = middle_width_cm * pixels_per_cm

    pad = max(round(wall_w + mid_w * 4 + 10), 20)
    padded = np.pad(mask, pad, mode="constant", constant_values=False)
    # bwdist(~padded): distance from arena pixels to the outside boundary.
    dist = distance_transform_edt(padded)
    max_dist = dist.max()

    def mk(name, pm):
        return Zone(name, "area", pm[pad : pad + h, pad : pad + w])

    zones: list[Zone] = []
    wall_ring = padded & (dist > 0) & (dist <= wall_w)
    if wall_ring.any():
        zones.append(mk("wall", wall_ring))

    rast_slop = 0.5
    cum = wall_w
    midi = 1
    while cum + mid_w <= max_dist + rast_slop:
        nxt = cum + mid_w
        ring = padded & (dist > cum) & (dist <= nxt)
        if ring.any():
            zones.append(mk(f"middle{midi}", ring))
        cum = nxt
        midi += 1
        if midi > 50:
            raise SphynxError("Computed > 50 middle rings; check input parameters")

    center = padded & (dist > cum)
    if center.any():
        zones.append(mk("center", center))
    return zones
```
Update `__init__.py` to export `classify_circle`.
- [ ] **Step 4: Run — PASS** (5 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/zones/circle.py src/sphynx/zones/__init__.py tests/unit/test_classify_circle.py && git commit -m "feat(python): zones.classify_circle"`

---

### Task 4: zones.classify_square (round corner mode)

**Files:** Create `src/sphynx/zones/square.py`; Modify `__init__.py` (export `classify_square`); Test `tests/unit/test_classify_square.py`.
**Interfaces:** `classify_square(arena_mask, strategy="corners-walls-center",
pixels_per_cm=None, wall_width_cm=3, corner_points=None, num_strips=3,
strip_direction="horizontal", corner_type="round") -> list[Zone]`. Strategies:
corners-walls-center (round mode; 8 zones), strips (delegates to partition_strips),
none (arena only). Raises `SphynxValueError` on unknown strategy / missing
pixels_per_cm / missing corner_points / square corner_type (deferred). Port of
`classifySquare.m` (round path only).

- [ ] **Step 1: Failing test** — `tests/unit/test_classify_square.py`:
```python
import numpy as np
import pytest
from matplotlib.path import Path

from sphynx.zones import classify_square
from sphynx.exceptions import SphynxValueError


def _rect(h, w, xc, yc):
    yy, xx = np.mgrid[1 : h + 1, 1 : w + 1]
    pts = np.column_stack([xx.ravel(), yy.ravel()])
    inside = Path(np.column_stack([xc, yc])).contains_points(pts)
    return inside.reshape(h, w)


def test_corners_walls_center_basic():
    xc = [50, 250, 250, 50]
    yc = [50, 50, 150, 150]
    m = _rect(200, 300, xc, yc)
    zones = classify_square(m, strategy="corners-walls-center", pixels_per_cm=5,
                            wall_width_cm=3, corner_points=np.column_stack([xc, yc]))
    names = [z.name for z in zones]
    assert "corners" in names and "walls" in names and "center" in names


def test_arena_touching_frame_edge_walls_and_corners_nonempty():
    xc = [1, 200, 200, 1]
    yc = [1, 1, 100, 100]
    m = np.ones((100, 200), bool)
    zones = classify_square(m, strategy="corners-walls-center", pixels_per_cm=5,
                            wall_width_cm=3, corner_points=np.column_stack([xc, yc]))
    walls = next(z for z in zones if z.name == "walls")
    corners = next(z for z in zones if z.name == "corners")
    assert walls.maskfilled.sum() > 0
    assert corners.maskfilled.sum() > 0


def test_strips_strategy_delegates():
    m = np.zeros((100, 200), bool)
    m[19:80, 19:180] = True
    zones = classify_square(m, strategy="strips", num_strips=3, strip_direction="vertical")
    assert len(zones) == 3
    assert zones[0].name == "strip1"


def test_none_strategy_returns_arena_only():
    m = np.zeros((100, 200), bool)
    m[19:80, 19:180] = True
    zones = classify_square(m, strategy="none")
    assert len(zones) == 1
    assert zones[0].name == "arena"


def test_rejects_unknown_strategy():
    with pytest.raises(SphynxValueError):
        classify_square(np.ones((10, 10), bool), strategy="blah")
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** `src/sphynx/zones/square.py`:
```python
"""Zone classification for a square/polygon arena (round-corner mode).
Port of sphynx.zones.classifySquare; square-corner mode and strips `_realout`
augmentation deferred to M3b."""

from __future__ import annotations

import numpy as np
from scipy.ndimage import distance_transform_edt

from sphynx.exceptions import SphynxValueError
from sphynx.zones.strips import Zone, partition_strips


def classify_square(
    arena_mask, strategy: str = "corners-walls-center", pixels_per_cm=None,
    wall_width_cm: float = 3, corner_points=None, num_strips: int = 3,
    strip_direction: str = "horizontal", corner_type: str = "round",
) -> list[Zone]:
    mask = np.asarray(arena_mask) > 0
    if strategy == "corners-walls-center":
        return _corners_walls_center(mask, pixels_per_cm, wall_width_cm,
                                     corner_points, corner_type)
    if strategy == "strips":
        return partition_strips(mask, num_strips, strip_direction)
    if strategy == "none":
        return [Zone("arena", "area", mask)]
    raise SphynxValueError(
        f"Strategy must be corners-walls-center|strips|none; got {strategy}")


def _corners_walls_center(mask, pixels_per_cm, wall_width_cm, corner_points, corner_type):
    if pixels_per_cm is None or pixels_per_cm <= 0:
        raise SphynxValueError("pixels_per_cm required for corners-walls-center")
    if corner_points is None or len(corner_points) == 0:
        raise SphynxValueError("corner_points required for corners-walls-center")
    if str(corner_type).lower() == "square":
        raise SphynxValueError("square corner_type not yet ported (round only)")

    cp = np.asarray(corner_points, dtype=float)
    wall_w = wall_width_cm * pixels_per_cm
    corner_w = wall_w * np.sqrt(2.0)
    h, w = mask.shape
    pad = max(round(wall_w + corner_w + 10), 20)
    padded = np.pad(mask, pad, mode="constant", constant_values=False)

    dist_out = distance_transform_edt(padded)          # bwdist(~padded)
    center = padded & (dist_out > wall_w)
    wc = padded & ~center

    def _seed(points):
        s = np.zeros_like(padded)
        for x, y in points:
            cx = round(x) + pad - 1
            cy = round(y) + pad - 1
            if 0 <= cx < padded.shape[1] and 0 <= cy < padded.shape[0]:
                s[cy, cx] = True
        return s

    corners = np.zeros_like(padded)
    for x, y in cp:
        seed = _seed([(x, y)])
        if not seed.any():
            continue
        dfc = distance_transform_edt(~seed)            # bwdist(seed)
        corners |= wc & (dfc <= corner_w)
    walls = wc & ~corners

    bwd_out = distance_transform_edt(~padded)          # bwdist(padded)
    outer_ring = (bwd_out > 0) & (bwd_out <= wall_w)
    arena_realout = padded | outer_ring
    wc_realout = arena_realout & ~center

    corner_seed = _seed(cp)
    dist_to_corner = distance_transform_edt(~corner_seed)
    outer_near_corners = outer_ring & (dist_to_corner <= corner_w)
    outer_near_walls = outer_ring & ~outer_near_corners
    corners_realout = corners | outer_near_corners
    walls_realout = walls | outer_near_walls

    def mk(name, pm):
        return Zone(name, "area", pm[pad : pad + h, pad : pad + w])

    return [
        mk("corners", corners),
        mk("walls", walls),
        mk("walls_and_corners", wc),
        mk("center", center),
        mk("arena_realout", arena_realout),
        mk("corners_realout", corners_realout),
        mk("walls_realout", walls_realout),
        mk("walls_and_corners_realout", wc_realout),
    ]
```
Update `__init__.py` to export `classify_square`.
- [ ] **Step 4: Run — PASS** (5 passed).
- [ ] **Step 5: Commit** `git add src/sphynx/zones/square.py src/sphynx/zones/__init__.py tests/unit/test_classify_square.py && git commit -m "feat(python): zones.classify_square (round-corner mode)"`

---

### Task 5: preset.pixels_per_cm (headless calibration math)

**Files:** Create `src/sphynx/preset/calibration.py`; Modify `src/sphynx/preset/__init__.py` (export); Test `tests/unit/test_pixels_per_cm.py`.
**Interfaces:** `pixels_per_cm(points, distances_cm, percent_threshold=3) ->
(ppc, x_kcorr, pxl_y, pxl_x, diff_pct)`. `points` 4x2 [x,y]; `distances_cm`
[d_vertical, d_horizontal]. Averages the two axis scales when within threshold, else
uses Y and returns an x correction factor. Port of `pixelsPerCm.m` (headless math only;
interactive ginput path is GUI/S4).

- [ ] **Step 1: Failing test** — `tests/unit/test_pixels_per_cm.py`:
```python
import numpy as np
import pytest

from sphynx.preset import pixels_per_cm


def test_isotropic_averages():
    pts = np.array([[0, 0], [0, 100], [0, 0], [100, 0]], dtype=float)
    ppc, x_kcorr, pxl_y, pxl_x, diff = pixels_per_cm(pts, [10.0, 10.0])
    assert ppc == pytest.approx(10.0)
    assert x_kcorr == 1.0
    assert diff == pytest.approx(0.0)


def test_anisotropic_uses_y_and_kcorr():
    # vertical pair: 100 px / 10 cm = 10; horizontal pair: 90 px / 10 cm = 9
    pts = np.array([[0, 0], [0, 100], [0, 0], [90, 0]], dtype=float)
    ppc, x_kcorr, pxl_y, pxl_x, diff = pixels_per_cm(pts, [10.0, 10.0])
    assert ppc == pytest.approx(10.0)
    assert x_kcorr == pytest.approx(10.0 / 9.0)
    assert diff > 3
```
- [ ] **Step 2: Run — FAIL**.
- [ ] **Step 3: Implement** `src/sphynx/preset/calibration.py`:
```python
"""Pixels-per-cm calibration from 4 reference points. Port of
sphynx.preset.pixelsPerCm (headless math; interactive ginput path is GUI/S4)."""

from __future__ import annotations

import numpy as np


def pixels_per_cm(points, distances_cm, percent_threshold: float = 3):
    """points: 4x2 [x, y] (pts 1-2 = vertical pair, pts 3-4 = horizontal pair);
    distances_cm: [d_vertical, d_horizontal]. Returns
    (ppc, x_kcorr, pxl_y, pxl_x, diff_pct)."""
    pts = np.asarray(points, dtype=float)
    x = pts[:, 0]
    y = pts[:, 1]
    dist_px_y = abs(y[1] - y[0])
    dist_px_x = abs(x[3] - x[2])
    pxl_y = dist_px_y / distances_cm[0]
    pxl_x = dist_px_x / distances_cm[1]
    diff_pct = abs(pxl_x - pxl_y) / pxl_x * 100.0
    if diff_pct > percent_threshold:
        return pxl_y, pxl_y / pxl_x, pxl_y, pxl_x, diff_pct
    return (pxl_y + pxl_x) / 2.0, 1.0, pxl_y, pxl_x, diff_pct
```
Update `src/sphynx/preset/__init__.py` to export `pixels_per_cm`.
- [ ] **Step 4: Run — PASS** (2 passed), then full suite `python -m pytest -q`.
- [ ] **Step 5: Commit** `git add src/sphynx/preset/calibration.py src/sphynx/preset/__init__.py tests/unit/test_pixels_per_cm.py && git commit -m "feat(python): preset.pixels_per_cm (headless calibration)"`

---

## Done criteria
- `python -m pytest -q` green (M2 157 + these).
- `sphynx.zones.{Zone, partition_strips, classify_circle, classify_square}` and
  `sphynx.preset.{mask_from_border, pixels_per_cm}` available.

## Deferred to M3b (preset-build, off analysis critical path)
- classify_square square-corner mode; partition_strips PCA/ArenaVertices path;
  strips `_realout` augmentation; build_zones_* orchestration; auto_detect_objects;
  grid_offsets; rotate_around_centroid; corrected_frame_count. Interactive drawing/video
  functions -> GUI spec S4.

## Next
- M3 whole-branch review, then M4: `acts` (registry, built-in acts, act_stats, refine,
  apply, eval) + `events` (single-act episodes).
