# S4d — Create Preset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Mark up a new experiment entirely in Python: a video frame, a calibration, drawn
shapes, derived rings and roles, and a preset the engine reads unchanged.

**Architecture:** Three Qt-free engine modules (video reader, the `buildObjectZones` port,
the preset writer that shares one format description with the v2 converter); the tab draws
with matplotlib's own selectors on the canvas already embedded elsewhere. Spec:
`docs/superpowers/specs/2026-08-02-S4d-create-preset-design.md`.

**Tech Stack:** Python 3.11+, PySide6, matplotlib, numpy, scipy, opencv-python 4.13; pytest, pytest-qt.

## Global Constraints
- Python at repo ROOT; commands from root with `PYTHONPATH=src`.
- `sphynx` must not import Qt. OpenCV lives ONLY in `sphynx/io/video.py`.
- No silent fallbacks (§10): an unreadable video or frame index raises `SphynxIOError`; a
  ring width without a calibration raises rather than inflating by pixels; a preset that
  fails its paradigm's rules is reported before saving, not silently written.
- The written preset must be the SAME `.mat` shape the v2 converter produces, so
  `read_preset` needs no change and MATLAB can still open it.
- ASCII only, including UI strings. TDD: failing test first.

## File Structure
- Create `src/sphynx/io/video.py` — frame access (the only OpenCV import).
- Create `src/sphynx/preset/objects.py` — port of `matlab/+sphynx/+preset/buildObjectZones.m`.
- Create `src/sphynx/io/preset_write.py` — one description of the on-disk zone format.
- Modify `src/sphynx/io/preset_upgrade.py` — use the shared writer.
- Create `src/sphynx_gui/preset_canvas.py`, `src/sphynx_gui/preset_tab.py`,
  `src/sphynx_gui/preset_controller.py`.
- Modify `src/sphynx_gui/main_window.py`, `src/sphynx_gui/state.py`.

---

### Task 1: video frame access

**Files:** Create `src/sphynx/io/video.py`; Test `tests/unit/test_video.py`.
**Interfaces:**
- `VideoInfo(path, n_frames, frame_rate, width, height)`.
- `video_info(path) -> VideoInfo`.
- `read_frame(path, index=0) -> np.ndarray` — HxWx3 uint8 RGB.
- Both raise `SphynxIOError` for a missing file, an unopenable file, or an index out of range.

- [ ] **Step 1: Write the failing test** — `tests/unit/test_video.py`:
```python
from pathlib import Path

import numpy as np
import pytest

from sphynx.exceptions import SphynxIOError
from sphynx.io.video import read_frame, video_info

_ROOT = Path(__file__).resolve().parents[2]
_VIDEO = _ROOT / "Demo/Video/NOF_H01_1D.mp4"

needs_video = pytest.mark.skipif(not _VIDEO.is_file(),
                                 reason="Demo video not present")


def test_missing_file_raises(tmp_path):
    with pytest.raises(SphynxIOError):
        video_info(tmp_path / "nope.mp4")


def test_a_file_that_is_not_a_video_raises(tmp_path):
    fake = tmp_path / "not_a_video.mp4"
    fake.write_text("hello", encoding="utf-8")
    with pytest.raises(SphynxIOError):
        video_info(fake)


@needs_video
def test_info_reports_the_shape():
    info = video_info(_VIDEO)
    assert info.n_frames > 0
    assert info.frame_rate > 0
    assert info.width > 0 and info.height > 0


@needs_video
def test_first_frame_is_an_rgb_image():
    frame = read_frame(_VIDEO, 0)
    assert frame.ndim == 3
    assert frame.shape[2] == 3
    assert frame.dtype == np.uint8


@needs_video
def test_frame_matches_the_reported_size():
    info = video_info(_VIDEO)
    frame = read_frame(_VIDEO, 0)
    assert frame.shape[:2] == (info.height, info.width)


@needs_video
def test_a_later_frame_differs_from_the_first():
    first = read_frame(_VIDEO, 0)
    later = read_frame(_VIDEO, min(50, video_info(_VIDEO).n_frames - 1))
    assert not np.array_equal(first, later)


@needs_video
def test_an_index_past_the_end_raises():
    info = video_info(_VIDEO)
    with pytest.raises(SphynxIOError):
        read_frame(_VIDEO, info.n_frames + 10)


@needs_video
def test_a_negative_index_raises():
    with pytest.raises(SphynxIOError):
        read_frame(_VIDEO, -1)
```
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_video.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'sphynx.io.video'`

- [ ] **Step 3: Write the implementation.** Create `src/sphynx/io/video.py`:
```python
"""Read frames from a video (S4d).

The ONLY place OpenCV is imported. A frame that cannot be read raises rather
than returning a blank image: marking zones onto a black rectangle would look
like it worked.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np

from sphynx.exceptions import SphynxIOError


@dataclass
class VideoInfo:
    path: str
    n_frames: int
    frame_rate: float
    width: int
    height: int


def _open(path):
    source = Path(path)
    if not source.is_file():
        raise SphynxIOError(f"video not found: {source}")
    capture = cv2.VideoCapture(str(source))
    if not capture.isOpened():
        capture.release()
        raise SphynxIOError(f"cannot open video: {source}")
    return capture


def video_info(path) -> VideoInfo:
    capture = _open(path)
    try:
        n_frames = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
        frame_rate = float(capture.get(cv2.CAP_PROP_FPS))
        width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
    finally:
        capture.release()
    if n_frames <= 0 or width <= 0 or height <= 0:
        raise SphynxIOError(
            f"video reports no frames or no size: {path}; it may be corrupt "
            "or in a codec OpenCV cannot read")
    return VideoInfo(str(path), n_frames, frame_rate, width, height)


def read_frame(path, index: int = 0) -> np.ndarray:
    """One frame as an HxWx3 uint8 RGB array."""
    if index < 0:
        raise SphynxIOError(f"frame index must be >= 0; got {index}")
    capture = _open(path)
    try:
        total = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
        if total > 0 and index >= total:
            raise SphynxIOError(
                f"frame {index} is past the end of {path} ({total} frames)")
        capture.set(cv2.CAP_PROP_POS_FRAMES, int(index))
        ok, frame = capture.read()
    finally:
        capture.release()
    if not ok or frame is None:
        raise SphynxIOError(f"cannot read frame {index} of {path}")
    return cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
```
- [ ] **Step 4: Run tests to verify they pass**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_video.py -q`
Expected: PASS (8 passed). Then the full suite.

- [ ] **Step 5: Commit**
```bash
git add src/sphynx/io/video.py tests/unit/test_video.py
git commit -m "feat(python): S4d -- video frame access"
```

---

### Task 2: object zones and their rings

**Files:** Create `src/sphynx/preset/objects.py`; Modify `src/sphynx/preset/__init__.py`; Test `tests/unit/test_preset_objects.py`.
**Interfaces:**
- `inflate_mask(mask, width_pixels, x_kcorr=1.0) -> tuple[np.ndarray, np.ndarray]` —
  `(inflated, ring)`; the ring is the inflation minus the original.
- `build_object_zones(objects, height, width, pixels_per_cm=None, zone_width_cm=2.5, x_kcorr=1.0) -> list[Zone]`
  where `objects` is a list of `(name, mask)`.
- Port of `matlab/+sphynx/+preset/buildObjectZones.m`: per object `<name>_real`,
  `<name>_realout`, `<name>_out`; with two or more objects also `objectall_real/_realout/_out`.
- A positive `zone_width_cm` without `pixels_per_cm` raises `SphynxValueError`.

- [ ] **Step 1: Write the failing test** — `tests/unit/test_preset_objects.py`:
```python
import numpy as np
import pytest

from sphynx.exceptions import SphynxValueError
from sphynx.preset.objects import build_object_zones, inflate_mask

H = W = 120


def _square(cx, cy, half=6):
    mask = np.zeros((H, W), dtype=bool)
    mask[cy - half:cy + half, cx - half:cx + half] = True
    return mask


def _zones(**kw):
    kw.setdefault("pixels_per_cm", 10.0)
    kw.setdefault("zone_width_cm", 2.5)
    return build_object_zones([("object1", _square(30, 30)),
                               ("object2", _square(90, 30))], H, W, **kw)


def _by_name(zones):
    return {z.name: z for z in zones}


# --- the inflation itself --------------------------------------------------

def test_inflation_grows_the_mask():
    mask = _square(60, 60)
    inflated, _ring = inflate_mask(mask, 5)
    assert inflated.sum() > mask.sum()
    assert (inflated & mask).sum() == mask.sum()      # contains the original


def test_the_ring_excludes_the_object():
    mask = _square(60, 60)
    inflated, ring = inflate_mask(mask, 5)
    assert not (ring & mask).any()
    assert (ring | mask).sum() == inflated.sum()      # ring + object = inflated


def test_a_wider_band_gives_a_bigger_ring():
    mask = _square(60, 60)
    _i1, narrow = inflate_mask(mask, 3)
    _i2, wide = inflate_mask(mask, 8)
    assert wide.sum() > narrow.sum()


def test_zero_width_leaves_an_empty_ring():
    mask = _square(60, 60)
    inflated, ring = inflate_mask(mask, 0)
    assert not ring.any()
    assert inflated.sum() == mask.sum()


def test_anisotropy_changes_the_shape():
    # With x_kcorr != 1 the band is inflated in isotropic space, so the ring is
    # not the same as the isotropic one.
    mask = _square(60, 60)
    _i, plain = inflate_mask(mask, 6, x_kcorr=1.0)
    _i2, stretched = inflate_mask(mask, 6, x_kcorr=1.6)
    assert plain.shape == stretched.shape
    assert not np.array_equal(plain, stretched)


# --- the zone set ----------------------------------------------------------

def test_three_zones_per_object():
    zones = _by_name(_zones())
    for name in ("object1_real", "object1_realout", "object1_out",
                 "object2_real", "object2_realout", "object2_out"):
        assert name in zones


def test_realout_is_the_union_of_real_and_out():
    zones = _by_name(_zones())
    real = zones["object1_real"].maskfilled
    ring = zones["object1_out"].maskfilled
    realout = zones["object1_realout"].maskfilled
    assert np.array_equal(realout, real | ring)
    assert not (real & ring).any()


def test_combined_zones_appear_for_two_objects():
    zones = _by_name(_zones())
    for name in ("objectall_real", "objectall_realout", "objectall_out"):
        assert name in zones
    combined = zones["objectall_real"].maskfilled
    assert combined.sum() == (zones["object1_real"].maskfilled.sum()
                              + zones["object2_real"].maskfilled.sum())


def test_a_single_object_gets_no_combined_zones():
    zones = _by_name(build_object_zones([("object1", _square(30, 30))], H, W,
                                        pixels_per_cm=10.0))
    assert "objectall_real" not in zones


def test_zones_carry_their_class_and_index():
    zones = _by_name(_zones())
    assert zones["object1_real"].zone_class == "object"
    assert zones["object1_out"].zone_class == "object_ring"
    assert zones["object1_realout"].zone_class == "object_area"
    assert zones["object2_real"].index == 2


def test_holes_are_supported_for_barnes():
    zones = _by_name(build_object_zones([("hole1", _square(30, 30))], H, W,
                                        pixels_per_cm=10.0, kind="hole"))
    assert zones["hole1_real"].zone_class == "hole"
    assert zones["hole1_out"].zone_class == "hole_ring"


def test_the_target_flag_reaches_all_three_zones():
    zones = _by_name(build_object_zones(
        [("target", _square(30, 30))], H, W, pixels_per_cm=10.0, kind="hole",
        targets={"target"}))
    for suffix in ("_real", "_out", "_realout"):
        assert zones["target" + suffix].roles.is_target is True


def test_no_calibration_with_a_ring_width_raises():
    with pytest.raises(SphynxValueError):
        build_object_zones([("object1", _square(30, 30))], H, W,
                           pixels_per_cm=None, zone_width_cm=2.5)


def test_zero_width_needs_no_calibration():
    zones = _by_name(build_object_zones([("object1", _square(30, 30))], H, W,
                                        pixels_per_cm=None, zone_width_cm=0))
    assert "object1_real" in zones
    assert "object1_out" not in zones


def test_an_empty_object_list_gives_no_zones():
    assert build_object_zones([], H, W, pixels_per_cm=10.0) == []
```
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_preset_objects.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'sphynx.preset.objects'`

- [ ] **Step 3: Write the implementation.** Create `src/sphynx/preset/objects.py`:
```python
"""Object zones and the rings around them (S4d).

Port of matlab/+sphynx/+preset/buildObjectZones.m. Each object yields three
zones, and they are three DIFFERENT classes so an act family binds exactly one
and nothing is counted twice:

    <name>_real     the object footprint          class <kind>
    <name>_out      the ring around it            class <kind>_ring
    <name>_realout  footprint + ring together     class <kind>_area

The ring is inflated in normalized (isotropic-cm) space when the pixel is
anisotropic, so a 2.5 cm band is physically 2.5 cm on both axes.
"""

from __future__ import annotations

import numpy as np
from scipy.ndimage import distance_transform_edt, zoom

from sphynx.exceptions import SphynxValueError
from sphynx.zones.strips import Zone, ZoneRoles


def _to_norm(mask, x_kcorr):
    """Stretch the columns so distances are isotropic. Rows are unchanged."""
    if x_kcorr == 1:
        return np.asarray(mask, dtype=bool)
    return zoom(np.asarray(mask, dtype=np.uint8), (1.0, x_kcorr),
                order=0) > 0


def _from_norm(mask, shape):
    if mask.shape == tuple(shape):
        return np.asarray(mask, dtype=bool)
    factors = (shape[0] / mask.shape[0], shape[1] / mask.shape[1])
    out = zoom(np.asarray(mask, dtype=np.uint8), factors, order=0) > 0
    # zoom can land one pixel short or long; trim or pad to the exact frame.
    fixed = np.zeros(tuple(shape), dtype=bool)
    rows = min(shape[0], out.shape[0])
    cols = min(shape[1], out.shape[1])
    fixed[:rows, :cols] = out[:rows, :cols]
    return fixed


def inflate_mask(mask, width_pixels, x_kcorr: float = 1.0):
    """(inflated, ring) for `mask` grown by `width_pixels`."""
    mask = np.asarray(mask, dtype=bool)
    if width_pixels <= 0:
        return mask.copy(), np.zeros_like(mask)

    if x_kcorr == 1:
        # bwdist(mask) in MATLAB is the distance to the nearest True pixel,
        # which is the EDT of the complement here.
        distance = distance_transform_edt(~mask)
        inflated = distance <= width_pixels
        return inflated, inflated & ~mask

    shape = mask.shape
    normalized = _to_norm(mask, x_kcorr)
    distance = distance_transform_edt(~normalized)
    inflated_norm = distance <= width_pixels
    inflated = _from_norm(inflated_norm, shape)
    ring = inflated & ~mask
    return inflated, ring


def build_object_zones(objects, height, width, pixels_per_cm=None,
                       zone_width_cm: float = 2.5, x_kcorr: float = 1.0,
                       kind: str = "object", targets=None) -> list:
    """Three zones per object, plus the combined set when there are several."""
    objects = list(objects or [])
    if not objects:
        return []
    if zone_width_cm > 0 and not pixels_per_cm:
        raise SphynxValueError(
            "a ring width in centimetres needs the pixels-per-cm calibration; "
            "calibrate first or set the width to 0")

    targets = set(targets or ())
    width_pixels = float(zone_width_cm) * float(pixels_per_cm or 1.0)
    zones: list = []

    def _add(name, mask, zone_class, index, is_target):
        zones.append(Zone(name, "area", np.asarray(mask, dtype=bool),
                          zone_class=zone_class,
                          roles=ZoneRoles(is_target=is_target), index=index))

    all_real = np.zeros((height, width), dtype=bool)
    all_realout = np.zeros((height, width), dtype=bool)

    for position, (name, mask) in enumerate(objects, start=1):
        mask = np.asarray(mask, dtype=bool)
        is_target = name in targets
        _add(f"{name}_real", mask, kind, position, is_target)
        all_real |= mask
        if width_pixels > 0:
            inflated, ring = inflate_mask(mask, width_pixels, x_kcorr)
            _add(f"{name}_realout", inflated, f"{kind}_area", position, is_target)
            _add(f"{name}_out", ring, f"{kind}_ring", position, is_target)
            all_realout |= inflated

    if len(objects) >= 2:
        _add("objectall_real", all_real, "legacy_aggregate", None, False)
        if width_pixels > 0:
            _add("objectall_realout", all_realout, "legacy_aggregate", None, False)
            _add("objectall_out", all_realout & ~all_real, "legacy_aggregate",
                 None, False)
    return zones
```
- [ ] **Step 4: Export.** In `src/sphynx/preset/__init__.py` add
  `from sphynx.preset.objects import build_object_zones, inflate_mask` and both names to
  `__all__` (create `__all__` if the file has none).
- [ ] **Step 5: Run tests to verify they pass**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_preset_objects.py -q`
Expected: PASS (15 passed). Then the full suite.

- [ ] **Step 6: Commit**
```bash
git add src/sphynx/preset/objects.py src/sphynx/preset/__init__.py tests/unit/test_preset_objects.py
git commit -m "feat(python): S4d -- object zones and their rings"
```

---

### Task 3: writing a preset

**Files:** Create `src/sphynx/io/preset_write.py`; Modify `src/sphynx/io/preset_upgrade.py`; Test `tests/unit/test_preset_write.py`.
**Interfaces:**
- `zone_to_mat(zone) -> dict` and `roles_to_mat(roles) -> dict` — moved out of
  `preset_upgrade` so the on-disk shape is described in one place.
- `save_preset(zones, options, path, arena_and_objects=None) -> str`.
- `options_struct(frame_rate, pixels_per_cm, width, height, x_kcorr=1.0, experiment_type="", **extra) -> dict`.

- [ ] **Step 1: Write the failing test** — `tests/unit/test_preset_write.py`:
```python
from pathlib import Path

import numpy as np
import pytest

from sphynx.exceptions import SphynxIOError
from sphynx.io.preset import read_preset
from sphynx.io.preset_write import options_struct, save_preset
from sphynx.zones.strips import Zone, ZoneRoles

H = W = 60


def _mask(r0, r1, c0, c1):
    mask = np.zeros((H, W), dtype=bool)
    mask[r0:r1, c0:c1] = True
    return mask


def _zones():
    return [
        Zone("arena", "area", _mask(5, 55, 5, 55), zone_class="arena", index=1),
        Zone("object1_real", "area", _mask(10, 16, 10, 16), zone_class="object",
             index=1),
        Zone("object1_realout", "area", _mask(8, 18, 8, 18),
             zone_class="object_area", index=1),
        Zone("target_real", "area", _mask(40, 46, 40, 46), zone_class="hole",
             roles=ZoneRoles(is_target=True), index=1),
    ]


def _options():
    return options_struct(frame_rate=30.0, pixels_per_cm=22.2, width=W,
                          height=H, experiment_type="Novelty OF")


def test_the_file_is_written(tmp_path):
    path = tmp_path / "nested" / "preset.mat"
    written = save_preset(_zones(), _options(), path)
    assert Path(written).is_file()


def test_the_engine_can_read_it_back(tmp_path):
    path = tmp_path / "preset.mat"
    save_preset(_zones(), _options(), path)
    preset = read_preset(path)
    names = [str(z.name) for z in np.atleast_1d(preset.zones)]
    assert "arena" in names and "object1_real" in names


def test_zone_classes_survive(tmp_path):
    path = tmp_path / "preset.mat"
    save_preset(_zones(), _options(), path)
    zones = {str(z.name): z for z in np.atleast_1d(read_preset(path).zones)}
    assert zones["object1_real"].zone_class == "object"
    assert zones["object1_realout"].zone_class == "object_area"


def test_the_target_flag_survives(tmp_path):
    path = tmp_path / "preset.mat"
    save_preset(_zones(), _options(), path)
    zones = {str(z.name): z for z in np.atleast_1d(read_preset(path).zones)}
    assert bool(zones["target_real"].roles.is_target) is True
    assert bool(zones["arena"].roles.is_target) is False


def test_masks_survive(tmp_path):
    path = tmp_path / "preset.mat"
    save_preset(_zones(), _options(), path)
    zones = {str(z.name): z for z in np.atleast_1d(read_preset(path).zones)}
    assert zones["arena"].maskfilled.shape == (H, W)
    assert zones["arena"].maskfilled.sum() == _mask(5, 55, 5, 55).sum()


def test_the_options_the_engine_reads_survive(tmp_path):
    path = tmp_path / "preset.mat"
    save_preset(_zones(), _options(), path)
    options = read_preset(path).options
    assert float(options.FrameRate) == 30.0
    assert float(options.pxl2sm) == 22.2
    assert int(options.Width) == W
    assert int(options.Height) == H
    assert float(options.x_kcorr) == 1.0


def test_saving_no_zones_raises(tmp_path):
    with pytest.raises(SphynxIOError):
        save_preset([], _options(), tmp_path / "empty.mat")


def test_a_written_preset_passes_paradigm_validation(tmp_path):
    from sphynx.paradigms import (
        PARADIGMS, register_builtin_paradigms, resolve_paradigm,
        validate_paradigm,
    )

    PARADIGMS.clear()
    register_builtin_paradigms()
    path = tmp_path / "preset.mat"
    save_preset(_zones(), _options(), path)
    preset = read_preset(path)
    report = validate_paradigm(resolve_paradigm("EOF"), list(preset.zones),
                               preset.options)
    assert report.ok is True          # an object and a calibration are present
    PARADIGMS.clear()
```
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_preset_write.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'sphynx.io.preset_write'`

- [ ] **Step 3: Write the implementation.** Create `src/sphynx/io/preset_write.py`:
```python
"""Write a preset .mat (S4d).

The on-disk shape is described HERE and nowhere else: the legacy upgrade and the
preset builder both write through this module, so the two cannot drift into
producing files the engine reads differently.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import scipy.io

from sphynx.exceptions import SphynxIOError


class Roles:
    """Roles that survive a .mat round trip."""

    def __init__(self, is_target: bool = False, tags=None):
        self.is_target = bool(is_target)
        self.tags = list(tags or [])


def roles_to_mat(roles) -> dict:
    return {"is_target": bool(getattr(roles, "is_target", False)),
            "tags": np.array(list(getattr(roles, "tags", []) or []),
                             dtype=object)}


def _angle_of(zone) -> float:
    angle = getattr(zone, "angle", None)
    return float("nan") if angle is None else float(angle)


def zone_to_mat(zone) -> dict:
    index = getattr(zone, "index", None)
    return {
        "name": str(getattr(zone, "name", "")),
        "type": str(getattr(zone, "type", "area")),
        "maskfilled": np.asarray(zone.maskfilled),
        "zone_class": str(getattr(zone, "zone_class", "unknown")),
        "index": np.nan if index is None else float(index),
        # `or` would turn a legitimate angle of 0.0 into NaN.
        "angle": float(_angle_of(zone)),
        "roles": roles_to_mat(getattr(zone, "roles", Roles())),
    }


def options_struct(frame_rate, pixels_per_cm, width, height,
                   x_kcorr: float = 1.0, experiment_type: str = "",
                   **extra) -> dict:
    """The Options fields the engine reads, under their legacy names."""
    options = {
        "FrameRate": float(frame_rate),
        "pxl2sm": float(pixels_per_cm),
        "Width": int(width),
        "Height": int(height),
        "x_kcorr": float(x_kcorr),
        "ExperimentType": str(experiment_type),
    }
    options.update(extra)
    return options


def save_preset(zones, options, path, arena_and_objects=None) -> str:
    """Write zones and options as the .mat shape read_preset expects."""
    zones = list(zones or [])
    if not zones:
        raise SphynxIOError("a preset needs at least one zone")

    target = Path(path)
    payload = {
        "Options": dict(options or {}),
        "ArenaAndObjects": (np.array([]) if arena_and_objects is None
                            else arena_and_objects),
        "Zones": np.array([zone_to_mat(z) for z in zones], dtype=object),
    }
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        scipy.io.savemat(target, payload, do_compression=True)
    except Exception as e:      # noqa: BLE001 - scipy raises broadly
        raise SphynxIOError(f"cannot write preset {target}: {e}") from e
    return str(target)
```
- [ ] **Step 4: Point the upgrade at the shared writer.** In
  `src/sphynx/io/preset_upgrade.py` delete the local `_Roles`, `_roles_to_mat` and
  `_zone_to_mat`, import `Roles as _Roles, zone_to_mat` from `sphynx.io.preset_write`,
  and replace the `_zone_to_mat(z)` call in `upgrade_preset_file` with `zone_to_mat(z)`.
  Leave the rest of the file alone; `tests/unit/test_preset_upgrade.py` must pass unchanged.
- [ ] **Step 5: Run tests to verify they pass**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_preset_write.py tests/unit/test_preset_upgrade.py -q`
Expected: PASS (8 new; the 17 upgrade tests unchanged). Then the full suite.

- [ ] **Step 6: Commit**
```bash
git add src/sphynx/io/preset_write.py src/sphynx/io/preset_upgrade.py tests/unit/test_preset_write.py
git commit -m "feat(python): S4d -- one description of the preset file format"
```

---

### Task 4: the drawing canvas

**Files:** Create `src/sphynx_gui/preset_canvas.py`; Test `tests/gui/test_preset_canvas.py`.
**Interfaces:**
- `Shape(name, kind, geometry, points)` — `kind` in `rectangle | ellipse | polygon`;
  `points` is the vertex list in pixel coordinates.
- `PresetCanvas(parent=None)` (QWidget) with `.show_frame(frame)`, `.set_tool(kind)`,
  `.shapes` (list), `.add_shape(name, kind, points)`, `.remove_shape(name)`,
  `.mask_for(shape, height, width) -> np.ndarray`, signal `shape_drawn(str)`.

> **NOTE for the controller:** interactive drawing over an embedded canvas. Build it in the
> main loop, not via a transcribing implementer.

- [ ] **Step 1: Write the failing test** — `tests/gui/test_preset_canvas.py` covering: a frame
  is displayed; a rectangle added by points produces a filled mask of the right area; an
  ellipse mask is smaller than its bounding box; a polygon mask follows its vertices; adding
  a shape emits `shape_drawn`; removing one drops it; a mask for a shape drawn outside the
  frame is clipped rather than raising.
- [ ] **Step 2: Run tests to verify they fail**
- [ ] **Step 3: Implement**, using matplotlib's `RectangleSelector`, `EllipseSelector` and
  `PolygonSelector` on the embedded canvas and `sphynx.preset.mask.mask_from_border` for the
  masks.
- [ ] **Step 4: Run tests to verify they pass**, then the full suite.
- [ ] **Step 5: Commit**
```bash
git add src/sphynx_gui/preset_canvas.py tests/gui/test_preset_canvas.py
git commit -m "feat(gui): S4d -- preset drawing canvas"
```

---

### Task 5: Create Preset tab and controller

**Files:** Create `src/sphynx_gui/preset_controller.py`, `src/sphynx_gui/preset_tab.py`; Modify `src/sphynx_gui/state.py`; Test `tests/gui/test_preset_tab.py`.
**Interfaces:**
- `PresetTab(state)` with `.canvas`, `.shapes_table`, `.video_button`, `.frame_spin`,
  `.calibrate_button`, `.pixels_per_cm_box`, `.ring_width_box`, `.build_button`,
  `.save_button`, `.warnings`, `.status_label`, `.controller`.
- `PresetController(state, tab)` with `.open_video(path)`, `.show_frame(index)`,
  `.calibrate(points, distance_cm)`, `.build_zones()`, `.validate()`, `.save(path)`.
- The ring width spin box defaults to 2.5.

> **NOTE for the controller:** wires the canvas, the geometry and the validation. Build it in
> the main loop.

- [ ] **Step 1: Write the failing test** — `tests/gui/test_preset_tab.py` covering: opening a
  missing video reports instead of raising; the frame spin box is bounded by the video's
  frame count; calibration from two points and a distance fills the pixels-per-cm box;
  building zones with no arena reports it; building with an arena and two objects produces
  the object/ring/area trio and the arena-derived zones; the warnings panel shows the chosen
  paradigm's complaints; saving without built zones reports it; saving writes a file the
  engine reads.
- [ ] **Step 2: Run tests to verify they fail**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests to verify they pass**, then the full suite.
- [ ] **Step 5: Commit**
```bash
git add src/sphynx_gui/preset_tab.py src/sphynx_gui/preset_controller.py src/sphynx_gui/state.py tests/gui/test_preset_tab.py
git commit -m "feat(gui): S4d -- Create Preset tab"
```

---

### Task 6: make the tab live and check the slice end to end

**Files:** Modify `src/sphynx_gui/main_window.py`; Test `tests/gui/test_main_window.py` (append), `tests/integration/test_preset_roundtrip.py`.
**Interfaces:** `MainWindow.preset_tab` is a `PresetTab`; one placeholder remains.

- [ ] **Step 1: Write the failing tests** — append to `tests/gui/test_main_window.py` that
  `window.preset_tab` is a `PresetTab` and exactly one placeholder is left; and
  `tests/integration/test_preset_roundtrip.py` that takes a frame from
  `Demo/Video/NOF_H01_1D.mp4`, builds a preset with an arena and two objects at a known
  calibration, saves it, reads it back with `read_preset`, validates it as EOF, and then runs
  `analyze_session` on the matching DLC csv asserting the acts `nose_at_object1` and
  `nose_at_object2` exist.
- [ ] **Step 2: Run tests to verify they fail**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests to verify they pass**, then the full suite.
- [ ] **Step 5: Launch the app by hand**

Run: `PYTHONPATH=src python -m sphynx_gui.app`
Expected: Create Preset opens a video, shows a frame, and a drawn arena plus objects build
into zones that save to a readable preset.

- [ ] **Step 6: Commit**
```bash
git add -A src/sphynx_gui tests
git commit -m "feat(gui): S4d -- Create Preset live, a preset built in Python analyses"
```

---

## Task order
Dispatch 1, 2, 3, 4, 5, 6 in order.

## Done criteria
- `PYTHONPATH=src python -m pytest -q` green (806 + new).
- A preset built and saved in Python is read by the engine, passes EOF validation, and yields
  object acts on a real session.
- The ring width is an editable field defaulting to 2.5 cm, and a ring width without a
  calibration raises instead of inflating by pixels.
