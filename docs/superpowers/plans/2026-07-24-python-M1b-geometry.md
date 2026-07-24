# Python engine — M1b geometry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the `util` geometry primitives by porting `ellipse_fit` and
`polygon_fit` from MATLAB, under TDD.

**Architecture:** Approach C — mirror the MATLAB `+util` functions. Both append to
the existing `src/sphynx/util/geometry.py`. This continues milestone M1
(foundation); IO (`read_dlc`, `read_preset`) is the next plan (M1c).

**Tech Stack:** Python 3.11+, numpy; pytest + ruff.

## Global Constraints

- Python project at repo ROOT (`src/sphynx/`, `tests/`); MATLAB reference under
  `matlab/` (do not touch). All paths relative to repo root; commands run from root.
- **No silent fallbacks** (spec §10): raise a `SphynxError` subclass on bad input.
  Exception: `ellipse_fit` intentionally returns a result object with a non-empty
  `status` string for non-elliptical conics (parabola/hyperbola/singular) — this
  mirrors the MATLAB contract and is an explicit, inspected signal, not a silent
  substitution.
- Behavioural parity with the MATLAB functions; tests ported from the MATLAB unit
  tests (`matlab/tests/unit/ellipseFitTest.m`, `polygonFitTest.m`).
- TDD: failing test first.

---

### Task 1: util geometry — ellipse_fit

**Files:**
- Modify: `src/sphynx/util/geometry.py` (append `EllipseFit` dataclass + `ellipse_fit`)
- Test: `tests/unit/test_geometry.py` (append ellipse tests)

**Interfaces:**
- Consumes: `sphynx.exceptions.TooFewPointsError`; numpy.
- Produces: `EllipseFit` dataclass (fields: `a, b, phi, X0, Y0, X0_in, Y0_in,
  long_axis, short_axis` all `float | None`; `status: str = ""`; raw conic coeffs
  `ar, br, cr, dr, er: float | None`). `ellipse_fit(x, y) -> EllipseFit`: least-
  squares ellipse fit (Ohad Gal algorithm, port of `sphynx.util.ellipseFit`).
  Raises `TooFewPointsError` for `< 5` points. Returns a mostly-empty `EllipseFit`
  with `status` set to `"matrix inversion warning"` / `"Parabola found"` /
  `"Hyperbola found"` on degenerate conics.

- [ ] **Step 1: Write the failing test**

Append to `tests/unit/test_geometry.py`:
```python
from sphynx.util.geometry import ellipse_fit, EllipseFit


def test_fits_axis_aligned_ellipse():
    th = np.linspace(0, 2 * np.pi, 50)
    x = 10 + 5 * np.cos(th)
    y = 20 + 3 * np.sin(th)
    e = ellipse_fit(x, y)
    assert e.status == ""
    assert e.X0_in == pytest.approx(10.0, abs=1e-6)
    assert e.Y0_in == pytest.approx(20.0, abs=1e-6)
    assert sorted([e.a, e.b]) == pytest.approx([3.0, 5.0], abs=1e-6)


def test_fits_circle_as_ellipse():
    th = np.linspace(0, 2 * np.pi, 50)
    x = 4 * np.cos(th)
    y = 4 * np.sin(th)
    e = ellipse_fit(x, y)
    assert e.status == ""
    assert e.a == pytest.approx(4.0, abs=1e-6)
    assert e.b == pytest.approx(4.0, abs=1e-6)


def test_ellipse_rejects_too_few_points():
    with pytest.raises(TooFewPointsError):
        ellipse_fit([1, 2, 3, 4], [1, 2, 3, 4])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tests/unit/test_geometry.py -k ellipse -v`
Expected: FAIL / ERROR — `ImportError: cannot import name 'ellipse_fit'`.

- [ ] **Step 3: Write the implementation**

Add to the imports block near the top of `src/sphynx/util/geometry.py` (the
`from dataclasses import dataclass` line if not already present):
```python
from dataclasses import dataclass
```

Append to `src/sphynx/util/geometry.py`:
```python
@dataclass
class EllipseFit:
    """Result of ellipse_fit. On a non-elliptical conic, most fields are None
    and `status` carries the reason (an explicit, inspected signal)."""

    a: float | None = None
    b: float | None = None
    phi: float | None = None
    X0: float | None = None
    Y0: float | None = None
    X0_in: float | None = None
    Y0_in: float | None = None
    long_axis: float | None = None
    short_axis: float | None = None
    status: str = ""
    ar: float | None = None
    br: float | None = None
    cr: float | None = None
    dr: float | None = None
    er: float | None = None


def ellipse_fit(x, y) -> EllipseFit:
    """Least-squares ellipse fit (Ohad Gal algorithm). Port of
    sphynx.util.ellipseFit. Raises TooFewPointsError for < 5 points; returns an
    EllipseFit with a non-empty `status` for degenerate conics.
    """
    orientation_tolerance = 1e-3
    x = np.asarray(x, dtype=float).ravel()
    y = np.asarray(y, dtype=float).ravel()
    if x.size < 5:
        raise TooFewPointsError(f"Need at least 5 points; got {x.size}")

    mean_x = float(np.mean(x))
    mean_y = float(np.mean(y))
    x = x - mean_x
    y = y - mean_y

    design = np.column_stack([x**2, x * y, y**2, x, y])
    gram = design.T @ design
    try:
        coef = np.sum(design, axis=0) @ np.linalg.inv(gram)
    except np.linalg.LinAlgError:
        return EllipseFit(status="matrix inversion warning")
    if not np.all(np.isfinite(coef)):
        return EllipseFit(status="matrix inversion warning")

    a, b, c, d, e = coef  # numpy float64 scalars (inf on /0, matching MATLAB)
    ar, br, cr, dr, er = float(a), float(b), float(c), float(d), float(e)

    if min(abs(b / a), abs(b / c)) > orientation_tolerance:
        orientation_rad = 0.5 * np.arctan(b / (c - a))
        cos_phi = np.cos(orientation_rad)
        sin_phi = np.sin(orientation_rad)
        a, b, c, d, e = (
            a * cos_phi**2 - b * cos_phi * sin_phi + c * sin_phi**2,
            0.0,
            a * sin_phi**2 + b * cos_phi * sin_phi + c * cos_phi**2,
            d * cos_phi - e * sin_phi,
            d * sin_phi + e * cos_phi,
        )
        mean_x, mean_y = (
            cos_phi * mean_x - sin_phi * mean_y,
            sin_phi * mean_x + cos_phi * mean_y,
        )
    else:
        orientation_rad = 0.0
        cos_phi = 1.0
        sin_phi = 0.0

    test = a * c
    if test == 0:
        return EllipseFit(status="Parabola found", ar=ar, br=br, cr=cr, dr=dr, er=er)
    if test < 0:
        return EllipseFit(status="Hyperbola found", ar=ar, br=br, cr=cr, dr=dr, er=er)

    if a < 0:
        a, c, d, e = -a, -c, -d, -e
    x0 = mean_x - d / 2 / a
    y0 = mean_y - e / 2 / c
    f = 1 + (d**2) / (4 * a) + (e**2) / (4 * c)
    a, b = np.sqrt(f / a), np.sqrt(f / c)
    long_axis = 2 * max(a, b)
    short_axis = 2 * min(a, b)

    rot = np.array([[cos_phi, sin_phi], [-sin_phi, cos_phi]])
    p_in = rot @ np.array([x0, y0])

    return EllipseFit(
        a=float(a), b=float(b), phi=float(orientation_rad),
        X0=float(x0), Y0=float(y0),
        X0_in=float(p_in[0]), Y0_in=float(p_in[1]),
        long_axis=float(long_axis), short_axis=float(short_axis),
        status="", ar=ar, br=br, cr=cr, dr=dr, er=er,
    )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tests/unit/test_geometry.py -k ellipse -v`
Expected: PASS (3 passed).

- [ ] **Step 5: Commit**

```bash
git add src/sphynx/util/geometry.py tests/unit/test_geometry.py
git commit -m "feat(python): util geometry — ellipse_fit (Ohad Gal)"
```

---

### Task 2: util geometry — polygon_fit

**Files:**
- Modify: `src/sphynx/util/geometry.py` (append `polygon_fit`)
- Test: `tests/unit/test_geometry.py` (append polygon tests)

**Interfaces:**
- Consumes: `sphynx.exceptions.TooFewPointsError`, `SphynxGeometryError`; numpy.
- Produces: `polygon_fit(x_corners, y_corners, points_per_side: int = 1000) ->
  tuple[np.ndarray, np.ndarray, list[np.ndarray], list[np.ndarray]]` returning
  `(x, y, sides_x, sides_y)`: `x, y` are the closed dense outline (all sides
  concatenated); `sides_x[i]`, `sides_y[i]` are the dense coords for side i
  (corner i to corner i+1, wrapping). Raises `SphynxGeometryError` on length
  mismatch, `TooFewPointsError` for `< 3` corners. (Port of
  `sphynx.util.polygonFit`.)

- [ ] **Step 1: Write the failing test**

Append to `tests/unit/test_geometry.py`:
```python
from sphynx.util.geometry import polygon_fit


def test_polygon_square_has_four_sides():
    x = [0, 10, 10, 0]
    y = [0, 0, 10, 10]
    px, py, sx, sy = polygon_fit(x, y)
    assert px.size == py.size
    assert len(sx) == 4
    assert len(sy) == 4


def test_polygon_sides_are_dense():
    x = [0, 10, 10, 0]
    y = [0, 0, 10, 10]
    _, _, sx, _ = polygon_fit(x, y)
    for side in sx:
        assert side.size > 10


def test_polygon_rejects_too_few_corners():
    with pytest.raises(TooFewPointsError):
        polygon_fit([0, 1], [0, 1])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tests/unit/test_geometry.py -k polygon -v`
Expected: FAIL / ERROR — `ImportError: cannot import name 'polygon_fit'`.

- [ ] **Step 3: Write the implementation**

Append to `src/sphynx/util/geometry.py`:
```python
def polygon_fit(
    x_corners, y_corners, points_per_side: int = 1000
) -> tuple[np.ndarray, np.ndarray, list[np.ndarray], list[np.ndarray]]:
    """Closed dense polygon outline + per-side traces. Port of
    sphynx.util.polygonFit. Raises on length mismatch / < 3 corners.
    """
    xc = np.asarray(x_corners, dtype=float).ravel()
    yc = np.asarray(y_corners, dtype=float).ravel()
    if xc.size != yc.size:
        raise SphynxGeometryError("x_corners and y_corners must match in length")
    if xc.size < 3:
        raise TooFewPointsError(f"Need at least 3 corners; got {xc.size}")

    n = xc.size
    sides_x: list[np.ndarray] = []
    sides_y: list[np.ndarray] = []
    for i in range(n):
        j = (i + 1) % n
        sides_x.append(np.linspace(xc[i], xc[j], points_per_side))
        sides_y.append(np.linspace(yc[i], yc[j], points_per_side))

    x = np.concatenate(sides_x)
    y = np.concatenate(sides_y)
    return x, y, sides_x, sides_y
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tests/unit/test_geometry.py -k polygon -v`
Expected: PASS (3 passed).

- [ ] **Step 5: Commit**

```bash
git add src/sphynx/util/geometry.py tests/unit/test_geometry.py
git commit -m "feat(python): util geometry — polygon_fit"
```

---

## Done criteria for this plan
- `python -m pytest -q` green (M1 22 + ellipse 3 + polygon 3 = 28).
- `util.geometry` now provides line utils, circle_fit, ellipse_fit, polygon_fit.

## Next plan
- **M1c:** `io` — `read_dlc` (single/multi-animal + decimal-comma locale) and
  `read_preset` (load MATLAB `.mat` preset via scipy.io).
