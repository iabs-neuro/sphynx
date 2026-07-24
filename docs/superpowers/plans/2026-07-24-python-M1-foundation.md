# Python engine — M1 foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the Python `sphynx` package with a typed `Config`, an
exception hierarchy, logging, and the first ported geometry primitives (line +
circle fit), all under TDD.

**Architecture:** Approach C from the engine spec — mirror the MATLAB package
structure, add a typed `Config`. This plan is milestone M1 part 1 (foundation);
it produces independently testable software (config round-trip + geometry unit
tests) but not yet a data-loading pipeline. Ellipse/polygon fit and IO
(`read_dlc`, `read_preset`) are the next plan.

**Tech Stack:** Python 3.11+, numpy, scipy, pandas (declared but unused this
plan), tomllib (stdlib, read) + tomli-w (write); pytest + ruff; hatchling build.

## Global Constraints

- **Python project lives in the repo subdirectory `python/`.** The MATLAB tree
  (`+sphynx/`, `tests/`, `Demo/`) stays in place as the porting reference, so the
  Python package must not collide with the MATLAB `tests/` dir. All paths below
  are relative to repo root and start with `python/`. All commands run from
  inside `python/` (each command block `cd`s there).
- **Python 3.11+** (uses stdlib `tomllib`).
- **src layout:** importable package is `python/src/sphynx`, imported as `sphynx`.
- **No silent fallbacks** (engine spec §10): on bad input raise a `SphynxError`
  subclass or warn + return an explicit NaN — never substitute a plausible value.
- **Behavioural parity** with the MATLAB functions being ported; tests are ported
  from the MATLAB unit tests (same known-answer inputs).
- **TDD:** every function gets a failing test first.
- **Environment setup (once, right after Task 0 creates `pyproject.toml`):**
  from `python/`, create and activate a venv, then
  `pip install -e ".[dev]"`. This installs numpy/scipy/pandas/tomli-w + pytest/ruff
  and makes `sphynx` importable. Re-run only if dependencies change.

---

### Task 0: Project scaffold

**Files:**
- Create: `python/pyproject.toml`
- Create: `python/src/sphynx/__init__.py`
- Create: `python/src/sphynx/exceptions.py`
- Create: `python/src/sphynx/logging_setup.py`
- Create: `python/.gitignore`
- Test: `python/tests/test_smoke.py`

**Interfaces:**
- Produces: package `sphynx` importable; `sphynx.__version__: str`;
  exception classes `SphynxError`, `SphynxConfigError`, `SphynxIOError`,
  `SphynxGeometryError`, `TooFewPointsError`, `DegenerateGeometryError`;
  `sphynx.logging_setup.get_logger(name: str = "sphynx") -> logging.Logger`.

- [ ] **Step 1: Write the failing test**

`python/tests/test_smoke.py`:
```python
import sphynx
from sphynx.exceptions import (
    SphynxError, SphynxConfigError, SphynxIOError,
    SphynxGeometryError, TooFewPointsError, DegenerateGeometryError,
)
from sphynx.logging_setup import get_logger


def test_package_imports_and_has_version():
    assert isinstance(sphynx.__version__, str)
    assert sphynx.__version__


def test_exception_hierarchy():
    assert issubclass(SphynxConfigError, SphynxError)
    assert issubclass(SphynxIOError, SphynxError)
    assert issubclass(SphynxGeometryError, SphynxError)
    assert issubclass(TooFewPointsError, SphynxGeometryError)
    assert issubclass(DegenerateGeometryError, SphynxGeometryError)


def test_logger_is_singleton_per_name():
    a = get_logger("sphynx.test")
    b = get_logger("sphynx.test")
    assert a is b
    assert len(a.handlers) == 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd python && python -m pytest tests/test_smoke.py -v`
Expected: FAIL / ERROR — `ModuleNotFoundError: No module named 'sphynx'`.

- [ ] **Step 3: Create the scaffold files**

`python/pyproject.toml`:
```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "sphynx"
version = "0.0.1"
description = "Segmented PHYsical aNalysis of eXploration — behavioural analysis engine"
requires-python = ">=3.11"
dependencies = [
    "numpy>=1.26",
    "scipy>=1.11",
    "pandas>=2.1",
    "tomli-w>=1.0",
]

[project.optional-dependencies]
dev = ["pytest>=8.0", "ruff>=0.5"]

[tool.hatch.build.targets.wheel]
packages = ["src/sphynx"]

[tool.pytest.ini_options]
testpaths = ["tests"]
pythonpath = ["src"]

[tool.ruff]
line-length = 100
src = ["src"]
```

`python/.gitignore`:
```
__pycache__/
*.pyc
.pytest_cache/
*.egg-info/
.ruff_cache/
build/
dist/
```

`python/src/sphynx/__init__.py`:
```python
"""Sphynx behavioural-analysis engine (Python port)."""

__version__ = "0.0.1"
```

`python/src/sphynx/exceptions.py`:
```python
"""Exception hierarchy. No silent fallbacks — engine raises these instead."""


class SphynxError(Exception):
    """Base class for all sphynx errors."""


class SphynxConfigError(SphynxError):
    """Invalid or unreadable configuration."""


class SphynxIOError(SphynxError):
    """Failure reading or writing sphynx data (DLC, preset, ...)."""


class SphynxGeometryError(SphynxError):
    """Invalid input to a geometric fit."""


class TooFewPointsError(SphynxGeometryError):
    """Not enough points to perform the requested fit."""


class DegenerateGeometryError(SphynxGeometryError):
    """Points are degenerate (e.g. collinear) for the requested fit."""
```

`python/src/sphynx/logging_setup.py`:
```python
"""Central logging. Use get_logger() everywhere instead of print()."""

import logging

_FORMAT = "[%(levelname)s] %(name)s: %(message)s"


def get_logger(name: str = "sphynx") -> logging.Logger:
    """Return a logger with a single stream handler attached exactly once."""
    logger = logging.getLogger(name)
    if not logger.handlers:
        handler = logging.StreamHandler()
        handler.setFormatter(logging.Formatter(_FORMAT))
        logger.addHandler(handler)
        logger.setLevel(logging.INFO)
    return logger
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd python && python -m pytest tests/test_smoke.py -v`
Expected: PASS (3 passed).

- [ ] **Step 5: Commit**

```bash
cd python && git add pyproject.toml .gitignore src/sphynx/__init__.py \
  src/sphynx/exceptions.py src/sphynx/logging_setup.py tests/test_smoke.py
git commit -m "feat(python): project scaffold — package, exceptions, logging"
```

---

### Task 1: Typed Config

**Files:**
- Create: `python/src/sphynx/config.py`
- Test: `python/tests/test_config.py`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: dataclasses `Paths, Frames, PerPart, Preprocess, Acts, Io, Viz, Config`;
  `Config.default() -> Config`; `Config.from_toml(path) -> Config` (partial
  override — keys absent from the file keep their defaults);
  `Config.to_toml(path) -> None`. Field names are snake_case; TOML keys equal the
  field names. Note the MATLAB `range` block is named `frames` here (`range`
  shadows a builtin).

- [ ] **Step 1: Write the failing test**

`python/tests/test_config.py`:
```python
from sphynx.config import Config


def test_default_values_match_matlab_defaults():
    c = Config.default()
    assert c.frames.start_frame == 1
    assert c.frames.end_frame == 0
    assert c.frames.auto_start is False
    assert c.preprocess.likelihood_threshold == 0.95
    assert c.preprocess.max_velocity_cm_s == 50.0
    assert c.preprocess.interpolation_method == "pchip"
    assert c.preprocess.per_part.smoothing_method == "sgolay"
    assert c.acts.rest_threshold_cm_s == 1.0
    assert c.acts.loc_threshold_cm_s == 5.0
    assert c.acts.min_run_seconds == 0.25
    assert c.acts.freezing_mode == "HeadAndCenter"
    assert c.acts.rear_mode == "TailbasePaws"
    assert c.acts.rear_threshold_tailbase_paws_cm == 2.8
    assert c.acts.rear_auto_threshold is True
    assert c.io.save_workspace is True
    assert c.viz.headless is True
    assert c.verbose == "info"


def test_toml_round_trip(tmp_path):
    c = Config.default()
    c.acts.min_run_seconds = 0.4
    c.preprocess.per_part.smoothing_poly_order = 2
    p = tmp_path / "cfg.toml"
    c.to_toml(p)
    c2 = Config.from_toml(p)
    assert c2 == c


def test_partial_override_keeps_defaults(tmp_path):
    p = tmp_path / "cfg.toml"
    p.write_text("[acts]\nrest_threshold_cm_s = 2.0\n")
    c = Config.from_toml(p)
    assert c.acts.rest_threshold_cm_s == 2.0        # overridden
    assert c.acts.loc_threshold_cm_s == 5.0         # default kept
    assert c.preprocess.likelihood_threshold == 0.95  # untouched block kept
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd python && python -m pytest tests/test_config.py -v`
Expected: FAIL / ERROR — `ModuleNotFoundError: No module named 'sphynx.config'`.

- [ ] **Step 3: Write the implementation**

`python/src/sphynx/config.py`:
```python
"""Typed configuration. Defaults live here — the single source of truth.

Mirrors the engine subset of the MATLAB sphynx.pipeline.defaultConfig tree.
GUI-only knobs (createPreset/analyzeTab/... from sphynx_defaults.jsonc) are
out of scope for the engine and are not represented here.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field, fields, is_dataclass
from pathlib import Path
import tomllib

import tomli_w


@dataclass
class Paths:
    video: str = ""
    dlc: str = ""
    preset: str = ""
    out_dir: str = ""
    preprocess_settings: str = ""


@dataclass
class Frames:
    start_frame: int = 1
    end_frame: int = 0  # 0 = read all
    auto_start: bool = False


@dataclass
class PerPart:
    big_parts: list[str] = field(
        default_factory=lambda: [
            "mass centre", "mass center", "bodycenter", "body_center",
            "center", "mouse_center", "tailbase", "tail base", "tail_base", "tail1",
        ]
    )
    smoothing_method: str = "sgolay"
    smoothing_poly_order: int = 3
    not_found_threshold_pct: int = 90


@dataclass
class Preprocess:
    individual: str = ""
    likelihood_threshold: float = 0.95
    smooth_window_small_sec: float = 0.10
    smooth_window_big_sec: float = 0.25
    max_velocity_cm_s: float = 50.0
    interpolation_method: str = "pchip"
    per_part: PerPart = field(default_factory=PerPart)


@dataclass
class Acts:
    library_path: str = ""
    rest_threshold_cm_s: float = 1.0
    loc_threshold_cm_s: float = 5.0
    min_run_seconds: float = 0.25
    freezing_mode: str = "HeadAndCenter"
    rear_mode: str = "TailbasePaws"
    rear_threshold_all_body_parts_pxl: float = 170.0
    rear_threshold_tailbase_paws_cm: float = 2.8
    rear_auto_threshold: bool = True


@dataclass
class Io:
    save_workspace: bool = True
    session_name: str = ""


@dataclass
class Viz:
    enabled: bool = False
    headless: bool = True
    make_video: bool = False


@dataclass
class Config:
    paths: Paths = field(default_factory=Paths)
    frames: Frames = field(default_factory=Frames)
    preprocess: Preprocess = field(default_factory=Preprocess)
    acts: Acts = field(default_factory=Acts)
    io: Io = field(default_factory=Io)
    viz: Viz = field(default_factory=Viz)
    verbose: str = "info"  # debug | info | warn | error

    @classmethod
    def default(cls) -> "Config":
        return cls()

    @classmethod
    def from_toml(cls, path: str | Path) -> "Config":
        with open(path, "rb") as fh:
            data = tomllib.load(fh)
        cfg = cls.default()
        _overlay(cfg, data)
        return cfg

    def to_toml(self, path: str | Path) -> None:
        with open(path, "wb") as fh:
            tomli_w.dump(asdict(self), fh)


def _overlay(obj: object, data: dict) -> None:
    """Recursively set fields present in `data`; absent keys keep defaults."""
    for f in fields(obj):
        if f.name not in data:
            continue
        current = getattr(obj, f.name)
        value = data[f.name]
        if is_dataclass(current) and isinstance(value, dict):
            _overlay(current, value)
        else:
            setattr(obj, f.name, value)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd python && python -m pytest tests/test_config.py -v`
Expected: PASS (3 passed). If `tomli_w` is missing, `pip install tomli-w` first.

- [ ] **Step 5: Commit**

```bash
cd python && git add src/sphynx/config.py tests/test_config.py
git commit -m "feat(python): typed Config with TOML round-trip and partial override"
```

---

### Task 2: util geometry — line utilities

**Files:**
- Create: `python/src/sphynx/util/__init__.py`
- Create: `python/src/sphynx/util/geometry.py`
- Test: `python/tests/unit/test_geometry.py`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  `line_through_points(p1: Sequence[float], p2: Sequence[float]) -> tuple[float, float, float]`
  returning `(k, B, x_const)`: `y = k*x + B` → `(k, B, nan)`; vertical `x = a` →
  `(nan, nan, a)`; degenerate `p1 == p2` → `(nan, nan, nan)`.
  `lines_intersection(k1, B1, k2, B2) -> tuple[float, float]` → intersection of
  `y=k1*x+B1` and `y=k2*x+B2`; parallel → `(nan, nan)`.
  (Ports of `sphynx.util.getLineEquation` / `sphynx.util.linesIntersection`.)

- [ ] **Step 1: Write the failing test**

`python/tests/unit/test_geometry.py`:
```python
import math

from sphynx.util.geometry import line_through_points, lines_intersection


def test_line_from_two_points():
    k, b, xc = line_through_points((0, 0), (1, 2))  # y = 2x
    assert k == 2
    assert b == 0
    assert math.isnan(xc)


def test_vertical_line():
    k, b, xc = line_through_points((5, 0), (5, 7))
    assert math.isnan(k)
    assert math.isnan(b)
    assert xc == 5


def test_degenerate_points():
    k, b, xc = line_through_points((3, 4), (3, 4))
    assert math.isnan(k) and math.isnan(b) and math.isnan(xc)


def test_intersection():
    x, y = lines_intersection(1, 0, -1, 4)  # y=x and y=-x+4 -> (2, 2)
    assert x == 2
    assert y == 2


def test_parallel_returns_nan():
    x, y = lines_intersection(2, 1, 2, 3)
    assert math.isnan(x) and math.isnan(y)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd python && python -m pytest tests/unit/test_geometry.py -v`
Expected: FAIL / ERROR — `ModuleNotFoundError: No module named 'sphynx.util'`.

- [ ] **Step 3: Write the implementation**

`python/src/sphynx/util/__init__.py`:
```python
"""Utility functions: pure geometry and small helpers."""
```

`python/src/sphynx/util/geometry.py`:
```python
"""Pure geometry helpers ported from +sphynx/+util."""

from __future__ import annotations

from collections.abc import Sequence

_NAN = float("nan")


def line_through_points(
    p1: Sequence[float], p2: Sequence[float]
) -> tuple[float, float, float]:
    """Return (k, B, x_const) describing the line through p1 and p2.

    y = k*x + B      -> (k, B, nan)
    x = a (vertical) -> (nan, nan, a)
    p1 == p2         -> (nan, nan, nan)
    Port of sphynx.util.getLineEquation.
    """
    x1, y1 = float(p1[0]), float(p1[1])
    x2, y2 = float(p2[0]), float(p2[1])
    if x1 == x2:
        if y1 == y2:
            return (_NAN, _NAN, _NAN)
        return (_NAN, _NAN, x1)
    k = (y1 - y2) / (x1 - x2)
    b = (y2 * x1 - y1 * x2) / (x1 - x2)
    return (k, b, _NAN)


def lines_intersection(
    k1: float, b1: float, k2: float, b2: float
) -> tuple[float, float]:
    """Intersection of y=k1*x+b1 and y=k2*x+b2; parallel -> (nan, nan).

    Port of sphynx.util.linesIntersection.
    """
    if k1 == k2:
        return (_NAN, _NAN)
    x = (b2 - b1) / (k1 - k2)
    y = k1 * x + b1
    return (x, y)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd python && python -m pytest tests/unit/test_geometry.py -v`
Expected: PASS (5 passed).

- [ ] **Step 5: Commit**

```bash
cd python && git add src/sphynx/util/__init__.py src/sphynx/util/geometry.py \
  tests/unit/test_geometry.py
git commit -m "feat(python): util geometry — line_through_points, lines_intersection"
```

---

### Task 3: util geometry — circle_fit

**Files:**
- Modify: `python/src/sphynx/util/geometry.py` (append `circle_fit`)
- Test: `python/tests/unit/test_geometry.py` (append circle tests)

**Interfaces:**
- Consumes: `sphynx.exceptions.TooFewPointsError`, `DegenerateGeometryError`.
- Produces: `circle_fit(x, y) -> tuple[float, float, float]` returning
  `(xc, yc, r)` of the least-squares circle. Raises `SphynxGeometryError` on
  length mismatch, `TooFewPointsError` for `< 3` points, `DegenerateGeometryError`
  for collinear points. (Port of `sphynx.util.circleFit`.)

- [ ] **Step 1: Write the failing test**

Append to `python/tests/unit/test_geometry.py`:
```python
import numpy as np
import pytest

from sphynx.util.geometry import circle_fit
from sphynx.exceptions import (
    SphynxGeometryError, TooFewPointsError, DegenerateGeometryError,
)


def test_fits_unit_circle():
    th = np.linspace(0, 2 * np.pi, 100)
    xc, yc, r = circle_fit(np.cos(th), np.sin(th))
    assert xc == pytest.approx(0.0, abs=1e-9)
    assert yc == pytest.approx(0.0, abs=1e-9)
    assert r == pytest.approx(1.0, abs=1e-9)


def test_fits_offset_circle():
    th = np.linspace(0, 2 * np.pi, 50)
    xc, yc, r = circle_fit(5 + 3 * np.cos(th), -7 + 3 * np.sin(th))
    assert xc == pytest.approx(5.0, abs=1e-9)
    assert yc == pytest.approx(-7.0, abs=1e-9)
    assert r == pytest.approx(3.0, abs=1e-9)


def test_fits_three_non_collinear_points():
    th = np.array([0.0, 2 * np.pi / 3, 4 * np.pi / 3])
    xc, yc, r = circle_fit(np.cos(th), np.sin(th))
    assert xc == pytest.approx(0.0, abs=1e-9)
    assert yc == pytest.approx(0.0, abs=1e-9)
    assert r == pytest.approx(1.0, abs=1e-9)


def test_rejects_too_few_points():
    with pytest.raises(TooFewPointsError):
        circle_fit([0, 1], [0, 0])


def test_rejects_collinear_points():
    with pytest.raises(DegenerateGeometryError):
        circle_fit([0, 1, 2, 3], [0, 0, 0, 0])


def test_rejects_length_mismatch():
    with pytest.raises(SphynxGeometryError):
        circle_fit([0, 1, 2], [0, 1])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd python && python -m pytest tests/unit/test_geometry.py -v`
Expected: FAIL / ERROR — `ImportError: cannot import name 'circle_fit'`.

- [ ] **Step 3: Write the implementation**

Add these imports at the top of `python/src/sphynx/util/geometry.py` (below the
existing imports):
```python
import numpy as np

from sphynx.exceptions import (
    DegenerateGeometryError,
    SphynxGeometryError,
    TooFewPointsError,
)
```

Append to `python/src/sphynx/util/geometry.py`:
```python
def circle_fit(x, y) -> tuple[float, float, float]:
    """Least-squares circle fit through (x, y). Returns (xc, yc, r).

    Solves (x^2+y^2) + a*x + b*y + c = 0, then xc=-a/2, yc=-b/2,
    r=sqrt((a^2+b^2)/4 - c). Port of sphynx.util.circleFit — raises on
    degenerate input rather than returning NaN silently.
    """
    x = np.asarray(x, dtype=float).ravel()
    y = np.asarray(y, dtype=float).ravel()
    if x.size != y.size:
        raise SphynxGeometryError("x and y must have the same length")
    if x.size < 3:
        raise TooFewPointsError(f"Need at least 3 points; got {x.size}")

    a_mat = np.column_stack([x, y, np.ones(x.size)])
    b_vec = -(x**2 + y**2)

    ata = a_mat.T @ a_mat
    cond = np.linalg.cond(ata)
    rcond = 1.0 / cond if np.isfinite(cond) and cond != 0 else 0.0
    if rcond < 1e-12:
        raise DegenerateGeometryError("Points appear collinear; cannot fit a circle")

    sol, *_ = np.linalg.lstsq(a_mat, b_vec, rcond=None)
    a, b, c = float(sol[0]), float(sol[1]), float(sol[2])
    xc = -a / 2.0
    yc = -b / 2.0
    r = float(np.sqrt((a**2 + b**2) / 4.0 - c))
    return (xc, yc, r)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd python && python -m pytest tests/unit/test_geometry.py -v`
Expected: PASS (11 passed — 5 line + 6 circle).

- [ ] **Step 5: Commit**

```bash
cd python && git add src/sphynx/util/geometry.py tests/unit/test_geometry.py
git commit -m "feat(python): util geometry — circle_fit with explicit degenerate errors"
```

---

## Done criteria for this plan

- `cd python && python -m pytest -v` is green (smoke + config + geometry).
- Package imports as `sphynx`; `Config.default()` reproduces the MATLAB engine
  defaults; TOML round-trip and partial override work; line + circle fits match
  the ported MATLAB known-answer tests.

## Next plans (not this one)

- **M1b:** `ellipse_fit`, `polygon_fit` (remaining `util` geometry) + `io`
  (`read_dlc` single/multi-animal + locale, `read_preset`).
- **M2:** `preprocess`, `bodyparts`, `angles`.
