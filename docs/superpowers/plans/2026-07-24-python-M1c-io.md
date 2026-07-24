# Python engine — M1c IO Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port DLC CSV reading (`read_dlc`, single/multi-animal) and preset `.mat`
loading (`read_preset`) into `sphynx.io`, under TDD.

**Architecture:** Approach C — mirror MATLAB `+io`. New `src/sphynx/io/` subpackage.
Completes milestone M1 (data loading). This is the first milestone touching real
Demo data and external formats; a heavy whole-branch review follows.

**Tech Stack:** Python 3.11+, numpy, pandas (CSV), scipy.io (MATLAB .mat); pytest.

## Global Constraints

- Python project at repo ROOT; MATLAB reference under `matlab/` (do not touch).
  Demo data is at repo-root `Demo/`. All commands from repo root.
- **No silent fallbacks** (spec §10): missing/unreadable files and malformed CSVs
  raise `SphynxIOError`; a forced-but-absent individual raises `SphynxIOError`.
- Behavioural parity with MATLAB `readDLC` / `readPreset`; tests port the MATLAB
  unit tests. NOTE: the MATLAB decimal-comma/RU-locale hazard does NOT exist in
  Python (pandas/numpy parse `.` regardless of host locale), so only the
  dot-decimal round-trip is ported, not the locale-switch test.
- The DLC missing sentinel is any negative x/y (DeepLabCut writes -1.0 for "no
  detection"); such entries become NaN in X/Y/likelihood.
- TDD: failing test first. Demo-dependent tests skip gracefully when the file is absent.

---

### Task 1: sphynx.io.read_dlc

**Files:**
- Create: `src/sphynx/io/__init__.py`
- Create: `src/sphynx/io/dlc.py`
- Test: `tests/unit/test_io_dlc.py`

**Interfaces:**
- Consumes: `sphynx.exceptions.SphynxIOError`; numpy; pandas.
- Produces: `DlcData` dataclass (`body_parts: list[str]`, `X, Y, likelihood:
  np.ndarray` (P×N), `n_frames: int`, `individuals: list[str] | None`,
  `selected_individual: str | None`); `read_dlc(csv_path, start_frame=1,
  end_frame=0, individual="") -> DlcData` (port of `sphynx.io.readDLC`).
  Single-animal → `individuals`/`selected_individual` are `None`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_io_dlc.py`:
```python
from pathlib import Path

import numpy as np
import pytest

from sphynx.io import read_dlc, DlcData
from sphynx.exceptions import SphynxIOError

REPO = Path(__file__).resolve().parents[2]

SINGLE_CSV = (
    "scorer,DLC,DLC,DLC,DLC,DLC,DLC\n"
    "bodyparts,nose,nose,nose,tail,tail,tail\n"
    "coords,x,y,likelihood,x,y,likelihood\n"
    "0,100.5,200.25,0.987,110.1,210.7,0.93\n"
    "1,101.2,201.05,0.991,110.9,211.2,0.94\n"
    "2,102.05,202.3,0.988,111.0,212.8,0.95\n"
    "3,102.9,203.45,0.985,112.5,213.0,0.92\n"
    "4,103.7,204.15,0.989,113.1,214.6,0.91\n"
)


def _write(tmp_path, text):
    p = tmp_path / "dlc.csv"
    p.write_text(text)
    return p


def test_single_animal_parsed(tmp_path):
    out = read_dlc(_write(tmp_path, SINGLE_CSV))
    assert isinstance(out, DlcData)
    assert out.individuals is None
    assert out.selected_individual is None
    assert out.body_parts == ["nose", "tail"]
    assert out.n_frames == 5
    assert out.X[0, 0] == pytest.approx(100.5, abs=1e-6)
    assert out.Y[0, 0] == pytest.approx(200.25, abs=1e-6)
    assert out.likelihood[0, 0] == pytest.approx(0.987, abs=1e-6)
    assert not np.isnan(out.X).any()


def test_frame_range_slice(tmp_path):
    out = read_dlc(_write(tmp_path, SINGLE_CSV), start_frame=2, end_frame=4)
    assert out.n_frames == 3
    assert out.X[0, 0] == pytest.approx(101.2, abs=1e-6)  # 2nd data row


def test_negative_sentinel_becomes_nan(tmp_path):
    text = (
        "scorer,DLC,DLC,DLC\n"
        "bodyparts,nose,nose,nose\n"
        "coords,x,y,likelihood\n"
        "0,-1.0,-1.0,0.01\n"
        "1,50.0,60.0,0.99\n"
    )
    out = read_dlc(_write(tmp_path, text))
    assert np.isnan(out.X[0, 0])
    assert np.isnan(out.Y[0, 0])
    assert np.isnan(out.likelihood[0, 0])
    assert out.X[0, 1] == pytest.approx(50.0, abs=1e-6)


def test_missing_file_raises(tmp_path):
    with pytest.raises(SphynxIOError):
        read_dlc(tmp_path / "nope.csv")


def test_malformed_column_count_raises(tmp_path):
    text = "scorer,DLC,DLC\nbodyparts,nose,nose\ncoords,x,y\n0,1.0,2.0\n"
    with pytest.raises(SphynxIOError):
        read_dlc(_write(tmp_path, text))


def test_multi_animal_stfp_selects_true_animal():
    csv = REPO / "Demo" / "DLC" / (
        "Stfp 1 D5 T2 1-14-1DLC_resnet50_STFP_2T_1GJun13shuffle1_100000_el.csv"
    )
    if not csv.is_file():
        pytest.skip("Demo STFP el.csv not present")
    out = read_dlc(csv)
    assert out.individuals is not None
    assert "observer" in out.individuals
    assert "demonstrator" in out.individuals
    assert "single" in out.individuals
    assert out.selected_individual in ("observer", "demonstrator")
    assert len(out.body_parts) == 11


def test_multi_animal_barnes_sentinel_and_pick():
    csv = REPO / "Demo" / "BARNES" / "3_DLC" / (
        "2024_11_02_17_16_42_test_cr_reencoded_superanimal_topviewmouse_snapshot.csv"
    )
    if not csv.is_file():
        pytest.skip("Demo BARNES snapshot csv not present")
    out = read_dlc(csv)
    assert len(out.individuals) == 10
    assert out.selected_individual.startswith("animal")
    assert len(out.body_parts) == 27
    assert np.isnan(out.X).any()
    assert int((~np.isnan(out.X) & ~np.isnan(out.Y)).sum()) > 0


def test_forced_individual():
    csv = REPO / "Demo" / "BARNES" / "3_DLC" / (
        "2024_11_02_17_16_42_test_cr_reencoded_superanimal_topviewmouse_snapshot.csv"
    )
    if not csv.is_file():
        pytest.skip("Demo BARNES snapshot csv not present")
    out = read_dlc(csv, individual="animal3")
    assert out.selected_individual == "animal3"


def test_forced_unknown_individual_raises():
    csv = REPO / "Demo" / "BARNES" / "3_DLC" / (
        "2024_11_02_17_16_42_test_cr_reencoded_superanimal_topviewmouse_snapshot.csv"
    )
    if not csv.is_file():
        pytest.skip("Demo BARNES snapshot csv not present")
    with pytest.raises(SphynxIOError):
        read_dlc(csv, individual="nobody")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tests/unit/test_io_dlc.py -v`
Expected: FAIL / ERROR — `ModuleNotFoundError: No module named 'sphynx.io'`.

- [ ] **Step 3: Write the implementation**

`src/sphynx/io/__init__.py`:
```python
"""IO: reading DLC tracking CSVs and preset .mat files."""

from sphynx.io.dlc import DlcData, read_dlc

__all__ = ["DlcData", "read_dlc"]
```

`src/sphynx/io/dlc.py`:
```python
"""Read DeepLabCut tracking CSVs (single- or multi-animal). Port of
sphynx.io.readDLC.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd

from sphynx.exceptions import SphynxIOError


@dataclass
class DlcData:
    body_parts: list[str]
    X: np.ndarray
    Y: np.ndarray
    likelihood: np.ndarray
    n_frames: int
    individuals: list[str] | None = None
    selected_individual: str | None = None


def read_dlc(
    csv_path, start_frame: int = 1, end_frame: int = 0, individual: str = ""
) -> DlcData:
    """Parse a DLC CSV. start_frame is 1-based inclusive; end_frame 0 = read all.
    For multi-animal ('individuals' header row) auto-picks the most-populated
    true animal (>1 bodypart), excluding 'single' trackers, unless `individual`
    forces one. Negative x/y sentinels (-1.0) become NaN.
    """
    path = Path(csv_path)
    if not path.is_file():
        raise SphynxIOError(f"DLC csv not found: {path}")

    header_lines: list[str] = []
    with open(path, "r", encoding="utf-8", newline="") as fh:
        for k in range(4):
            line = fh.readline()
            if line == "":
                raise SphynxIOError(f"CSV ended before header line {k + 1}")
            header_lines.append(line.rstrip("\n").rstrip("\r"))

    row2 = header_lines[1].split(",")
    is_multi = bool(row2) and row2[0].strip().lower() == "individuals"
    if is_multi:
        num_header = 4
        bodyparts_tokens = header_lines[2].split(",")
        individuals_tokens = row2[1:]
    else:
        num_header = 3
        bodyparts_tokens = header_lines[1].split(",")
        individuals_tokens = []
    bodyparts_tokens = bodyparts_tokens[1:]  # drop the leading label
    n_cols = len(bodyparts_tokens)
    if n_cols % 3 != 0:
        raise SphynxIOError(f"Expected 3 columns per part, got {n_cols} data columns")

    data = pd.read_csv(path, skiprows=num_header, header=None).to_numpy(dtype=float)
    n_total = data.shape[0]
    end = end_frame if (end_frame != 0 and end_frame <= n_total) else n_total
    rows = slice(start_frame - 1, end)  # 1-based inclusive -> 0-based half-open

    if is_multi:
        part_cols, part_names, picked, all_individuals = _pick_multi_animal(
            individuals_tokens, bodyparts_tokens, data, individual
        )
        individuals_out: list[str] | None = all_individuals
        selected_out: str | None = picked
    else:
        n_parts = n_cols // 3
        part_names = [bodyparts_tokens[i * 3] for i in range(n_parts)]
        part_cols = [i * 3 for i in range(n_parts)]
        individuals_out = None
        selected_out = None

    n_parts = len(part_names)
    n_sel = end - (start_frame - 1)
    xs = np.zeros((n_parts, n_sel))
    ys = np.zeros((n_parts, n_sel))
    ls = np.zeros((n_parts, n_sel))
    for part in range(n_parts):
        col = part_cols[part] + 1  # +1 to skip the frame-index column (col 0)
        xs[part, :] = data[rows, col]
        ys[part, :] = data[rows, col + 1]
        ls[part, :] = data[rows, col + 2]

    miss = (xs < 0) | (ys < 0)
    xs[miss] = np.nan
    ys[miss] = np.nan
    ls[miss] = np.nan

    return DlcData(
        body_parts=[t.strip() for t in part_names],
        X=xs, Y=ys, likelihood=ls, n_frames=n_sel,
        individuals=individuals_out, selected_individual=selected_out,
    )


def _pick_multi_animal(
    individuals_tokens: list[str],
    bodyparts_tokens: list[str],
    data: np.ndarray,
    forced: str,
) -> tuple[list[int], list[str], str, list[str]]:
    n_data_cols = len(individuals_tokens)
    if n_data_cols % 3 != 0:
        raise SphynxIOError(
            f"Multi-animal: column counts inconsistent ({n_data_cols} not divisible by 3)"
        )
    n_triplets = n_data_cols // 3
    triplet_individual = [individuals_tokens[t * 3].strip() for t in range(n_triplets)]
    triplet_bodypart = [bodyparts_tokens[t * 3].strip() for t in range(n_triplets)]

    all_individuals = list(dict.fromkeys(triplet_individual))  # unique, stable

    candidates = [
        name
        for name in all_individuals
        if len({triplet_bodypart[t] for t in range(n_triplets)
                if triplet_individual[t] == name}) > 1
    ]
    if not candidates:
        candidates = all_individuals

    if forced:
        if forced in all_individuals:
            picked = forced
        else:
            raise SphynxIOError(
                f'Forced Individual "{forced}" not in CSV; available: {all_individuals}'
            )
    else:
        best = -1
        picked = candidates[0]
        for name in candidates:
            score = 0
            for t in range(n_triplets):
                if triplet_individual[t] != name:
                    continue
                col = t * 3 + 1  # +1 to skip frame-index column
                xs = data[:, col]
                ys = data[:, col + 1]
                populated = ~np.isnan(xs) & ~np.isnan(ys) & (xs >= 0) & (ys >= 0)
                score += int(np.sum(populated))
            if score > best:
                best = score
                picked = name

    picked_idx = [t for t in range(n_triplets) if triplet_individual[t] == picked]
    part_names = [triplet_bodypart[t] for t in picked_idx]
    part_cols = [t * 3 for t in picked_idx]
    return part_cols, part_names, picked, all_individuals
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tests/unit/test_io_dlc.py -v`
Expected: PASS (synthetic tests pass; Demo-dependent tests pass if Demo present, else skip).

- [ ] **Step 5: Commit**

```bash
git add src/sphynx/io/__init__.py src/sphynx/io/dlc.py tests/unit/test_io_dlc.py
git commit -m "feat(python): io.read_dlc — single/multi-animal DLC CSV parsing"
```

---

### Task 2: sphynx.io.read_preset

**Files:**
- Create: `src/sphynx/io/preset.py`
- Modify: `src/sphynx/io/__init__.py` (export `read_preset`, `PresetData`)
- Test: `tests/unit/test_io_preset.py`

**Interfaces:**
- Consumes: `sphynx.exceptions.SphynxIOError`; scipy.io.
- Produces: `PresetData` dataclass (`options`, `zones`, `arena_and_objects` — the
  loaded MATLAB values); `read_preset(mat_path) -> PresetData` (port of
  `sphynx.io.readPreset`). Loads with `squeeze_me=True, struct_as_record=False`
  so struct fields are attribute-accessible (`options.FrameRate`). Missing file
  raises `SphynxIOError`.

- [ ] **Step 1: Write the failing test**

`tests/unit/test_io_preset.py`:
```python
from pathlib import Path

import pytest

from sphynx.io import read_preset, PresetData
from sphynx.exceptions import SphynxIOError

REPO = Path(__file__).resolve().parents[2]


def test_missing_preset_raises(tmp_path):
    with pytest.raises(SphynxIOError):
        read_preset(tmp_path / "nope.mat")


def test_loads_demo_preset():
    mat = REPO / "Demo" / "Preset" / "NOF_H01_1D_Preset.mat"
    if not mat.is_file():
        pytest.skip("Demo NOF preset not present")
    out = read_preset(mat)
    assert isinstance(out, PresetData)
    assert out.options is not None
    assert hasattr(out.options, "FrameRate")
    assert hasattr(out.options, "pxl2sm")
    assert out.zones is not None
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tests/unit/test_io_preset.py -v`
Expected: FAIL / ERROR — `ImportError: cannot import name 'read_preset'`.

- [ ] **Step 3: Write the implementation**

`src/sphynx/io/preset.py`:
```python
"""Load a sphynx preset .mat file. Port of sphynx.io.readPreset."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import scipy.io

from sphynx.exceptions import SphynxIOError


@dataclass
class PresetData:
    options: object
    zones: object
    arena_and_objects: object


def read_preset(mat_path) -> PresetData:
    """Load the legacy preset .mat (fields Options, Zones, ArenaAndObjects).
    Struct fields are attribute-accessible (e.g. options.FrameRate).
    """
    path = Path(mat_path)
    if not path.is_file():
        raise SphynxIOError(f"Preset .mat not found: {path}")
    mat = scipy.io.loadmat(path, squeeze_me=True, struct_as_record=False)
    return PresetData(
        options=mat.get("Options"),
        zones=mat.get("Zones"),
        arena_and_objects=mat.get("ArenaAndObjects"),
    )
```

Update `src/sphynx/io/__init__.py`:
```python
"""IO: reading DLC tracking CSVs and preset .mat files."""

from sphynx.io.dlc import DlcData, read_dlc
from sphynx.io.preset import PresetData, read_preset

__all__ = ["DlcData", "read_dlc", "PresetData", "read_preset"]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tests/unit/test_io_preset.py -v`
Expected: PASS (missing-file test passes; Demo test passes if present, else skips).

- [ ] **Step 5: Commit**

```bash
git add src/sphynx/io/preset.py src/sphynx/io/__init__.py tests/unit/test_io_preset.py
git commit -m "feat(python): io.read_preset — load MATLAB .mat preset via scipy.io"
```

---

## Done criteria for this plan
- `python -m pytest -q` green (all prior + new io tests; Demo-dependent ones pass or skip).
- `sphynx.io` provides `read_dlc` and `read_preset`. Milestone M1 (data loading) complete.

## Next plan
- **M2:** `preprocess` (clean/interpolate/smooth/velocity/kalman/hampel/autothreshold/
  per-part/arena-ring/detect-start), `bodyparts` (identify/center/resolve/relative),
  `angles` (head_direction/wrap/unwrap).
