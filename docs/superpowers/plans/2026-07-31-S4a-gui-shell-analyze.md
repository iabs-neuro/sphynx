# S4a — GUI shell + Analyze tab + S2 engine bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A runnable six-tab PySide6 application whose Analyze Session tab runs the engine
on a real session -- with a paradigm driving validation, act families and named metrics.

**Architecture:** The engine stays Qt-free: the S2 bridge lives in `src/sphynx/pipeline/`
and is tested like ordinary engine code. The GUI is a separate package `src/sphynx_gui/`
where widgets hold no engine logic -- a controller reads `AppState`, runs the engine in a
worker, and pushes results into widgets. Spec:
`docs/superpowers/specs/2026-07-31-S4a-gui-shell-analyze-design.md`.

**Tech Stack:** Python 3.11+, PySide6, matplotlib (FigureCanvasQTAgg), numpy; pytest, pytest-qt.

## Global Constraints
- Python at repo ROOT; commands from root with `PYTHONPATH=src`.
- **`sphynx` must not import Qt.** Only `sphynx_gui` may. A test enforces this.
- No silent fallbacks (§10): a paradigm whose composite or family cannot be built records a
  `ValidationIssue` in the report -- never a quietly missing act. Metric failures land in
  `MetricResults.errors` and are displayed, not blanked.
- Backward compatibility: `analyze_session(config)` without a paradigm behaves exactly as
  before; the new `SessionResult` fields are defaulted.
- ASCII only in all files, including UI strings (the codebase is ASCII throughout).
- GUI tests run headless: `QT_QPA_PLATFORM=offscreen`.
- TDD: failing test first.
- Precedence for settings: preset `Options` > paradigm `config_defaults` > `Config`.

## File Structure

**Engine (no Qt):**
- Create `src/sphynx/pipeline/paradigm_bridge.py` -- `apply_paradigm(result, paradigm, registry=None)`.
- Modify `src/sphynx/pipeline/analyze.py` -- `SessionResult` gains `validation`, `metrics`,
  `event_streams`, `degraded`; `analyze_session(config, paradigm=None)`.

**GUI:**
- `src/sphynx_gui/state.py` -- `AppState` (QObject + signals).
- `src/sphynx_gui/worker.py` -- `AnalysisWorker` (QObject; `run()` is synchronous and testable).
- `src/sphynx_gui/placeholder_tab.py` -- stub tab for the five unbuilt tabs.
- `src/sphynx_gui/main_window.py` -- six-tab shell.
- `src/sphynx_gui/app.py` -- `main()` entry point.
- `src/sphynx_gui/warnings_panel.py` -- the §10 surface.
- `src/sphynx_gui/plot_grid.py` -- 2x2 matplotlib grid with double-click maximise.
- `src/sphynx_gui/analyze_tab.py` + `analyze_controller.py` -- the Analyze tab.

---

### Task 1: paradigm bridge in the engine

**Files:** Create `src/sphynx/pipeline/paradigm_bridge.py`; Modify `src/sphynx/pipeline/analyze.py`, `src/sphynx/pipeline/__init__.py`; Test `tests/unit/test_paradigm_bridge.py`.
**Interfaces:**
- Consumes: `resolve_paradigm(name_or_paradigm, registry=None)`, `lineage(...)`,
  `validate_paradigm(paradigm, zones, options=None) -> ValidationReport`,
  `make_composite(name, zones, selector, zone_class="composite") -> Zone`,
  `expand_family(family, zones) -> list[Act]`, `eval_acts_library(acts, ctx) -> dict`,
  `family_event_stream(acts, results, frame_rate, family=None) -> EventStream`,
  `act_stats(mask, frame_rate, velocity=None) -> ActStats`,
  `compute_metric_refs(refs, ctx, *, paradigm) -> MetricResults`,
  `MetricContext(acts, stats, events, act_defs, zones, degraded, trajectory_cm, frame_rate)`,
  `ActContext(X, Y, velocity_cm_s, body_parts, zones, frame_rate, pixels_per_cm, x_kcorr)`,
  `SessionAct(name, array, category, stats)`, `ValidationIssue(code, level, message, where)`.
- Produces: `apply_paradigm(result, paradigm, registry=None) -> None` (mutates `result`);
  `analyze_session(config, paradigm=None)`.

- [ ] **Step 1: Write the failing test** — `tests/unit/test_paradigm_bridge.py`:
```python
import math

import numpy as np
import pytest

from sphynx.acts import Act, ActFamily
from sphynx.config import Config
from sphynx.paradigms import (
    PARADIGMS, MetricRef, Paradigm, register_builtin_paradigms,
    register_paradigm,
)
from sphynx.paradigms.validate import ValidationRule
from sphynx.pipeline.analyze import SessionAct, SessionResult
from sphynx.pipeline.paradigm_bridge import apply_paradigm
from sphynx.bodyparts.identify import Point
from sphynx.zones import Zone, ZoneRoles, ZoneSelector

N = 60
FPS = 10.0


@pytest.fixture(autouse=True)
def _builtins():
    saved = dict(PARADIGMS)
    PARADIGMS.clear()
    register_builtin_paradigms()
    yield
    PARADIGMS.clear()
    PARADIGMS.update(saved)


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
                roles=ZoneRoles(is_target=is_target), angle=0.0, index=None)


def _result(zones):
    # the animal sits inside hole_a for frames 10..19, elsewhere otherwise
    x = np.full(N, 90.0)
    y = np.full(N, 90.0)
    x[10:20] = 20.0
    y[10:20] = 20.0
    traces = [_Trace("nose", x, y, np.zeros(N)),
              _Trace("bodycenter", x, y, np.zeros(N))]
    point = Point(nose=0, center=1)
    return SessionResult(
        body_parts_names=["nose", "bodycenter"], body_parts_traces=traces,
        point=point, acts=[SessionAct("rest", np.ones(N), "builtin")],
        options=_Options(), zones=zones, arena_and_objects=None,
        n_frames=N, config=Config.default(),
    )


def _zones():
    zs = [_hole("hole_a", 20, 20, is_target=True), _hole("hole_b", 80, 20)]
    for i, z in enumerate(zs, start=1):
        z.index = i
    return zs


def test_validation_report_is_attached():
    result = _result(_zones())
    apply_paradigm(result, "OF")
    assert result.validation is not None
    assert result.validation.paradigm == "OF"
    assert result.validation.ok is True          # pxl2sm is set


def test_missing_calibration_is_reported():
    result = _result(_zones())
    result.options = type("O", (), {"FrameRate": FPS, "Width": 100, "Height": 100})()
    apply_paradigm(result, "OF")
    assert result.validation.ok is False
    assert "needs_calibration" in [i.code for i in result.validation.errors]


def test_family_acts_are_computed_and_appended():
    result = _result(_zones())
    apply_paradigm(result, "Barnes")
    names = [a.name for a in result.acts]
    assert "rest" in names                       # existing acts survive
    assert "nose_at_hole1" in names
    assert "nose_at_hole2" in names
    family_act = next(a for a in result.acts if a.name == "nose_at_hole1")
    assert family_act.category == "family"
    assert family_act.stats is not None
    assert family_act.array.sum() > 0            # the animal visited hole_a


def test_event_streams_are_built():
    result = _result(_zones())
    apply_paradigm(result, "Barnes")
    assert "nose_at_hole" in result.event_streams
    stream = result.event_streams["nose_at_hole"]
    assert [e.label for e in stream.events] == ["hole_a"]


def test_metrics_are_computed():
    result = _result(_zones())
    apply_paradigm(result, "Barnes")
    assert result.metrics is not None
    assert result.metrics.values["primary_latency"] == pytest.approx(1.0)
    assert result.metrics.values["target_ordinal"] == 0.0


def test_metric_failures_are_recorded_not_hidden():
    zones = [_hole("hole_a", 20, 20), _hole("hole_b", 80, 20)]   # no target
    for i, z in enumerate(zones, start=1):
        z.index = i
    result = _result(zones)
    apply_paradigm(result, "Barnes")
    assert result.metrics.errors            # target metrics could not run
    assert "needs_one_target" in [i.code for i in result.validation.errors]


def test_unbuildable_composite_is_reported_as_a_validation_issue():
    # EOF wants an "all_objects" composite; this preset has only holes.
    result = _result(_zones())
    apply_paradigm(result, "EOF")
    codes = [i.code for i in result.validation.issues]
    assert "composite_failed" in codes


def test_unbuildable_family_is_reported_as_a_validation_issue():
    result = _result(_zones())
    apply_paradigm(result, "EOF")
    codes = [i.code for i in result.validation.issues]
    assert "family_failed" in codes


def test_degradation_is_carried_onto_the_result():
    zones = _zones()
    result = _result(zones)
    result.body_parts_names = ["bodycenter"]     # no nose at all
    result.body_parts_traces = result.body_parts_traces[1:]
    result.point = Point(center=0)
    apply_paradigm(result, "Barnes")
    assert result.degraded                       # nose-based family acts degraded


def test_paradigm_config_defaults_do_not_override_the_preset():
    register_paradigm(Paradigm(name="Loud", parent="OF",
                               config_defaults={"velocity_rest": 99.0}))
    result = _result(_zones())
    apply_paradigm(result, "Loud")
    # the bridge records defaults for the caller but never rewrites Options
    assert result.paradigm_defaults["velocity_rest"] == 99.0
    assert result.options.pxl2sm == 10.0


def test_unknown_paradigm_raises():
    from sphynx.exceptions import SphynxValueError

    with pytest.raises(SphynxValueError):
        apply_paradigm(_result(_zones()), "NoSuchParadigm")
```
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_paradigm_bridge.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'sphynx.pipeline.paradigm_bridge'`

- [ ] **Step 3: Add the result fields.** In `src/sphynx/pipeline/analyze.py`, append to the
  `SessionResult` dataclass (after `all_individuals`):
```python
    # --- filled in by the paradigm bridge (S4a); None when no paradigm ran ---
    validation: object | None = None      # ValidationReport
    metrics: object | None = None         # MetricResults
    event_streams: dict = field(default_factory=dict)   # family -> EventStream
    degraded: dict = field(default_factory=dict)        # act name -> reasons
    paradigm: str = ""
    paradigm_defaults: dict = field(default_factory=dict)
```
- [ ] **Step 4: Write the bridge.** Create `src/sphynx/pipeline/paradigm_bridge.py`:
```python
"""Compute a paradigm's composites, act families and named metrics onto a
session result (S2 -> S4 bridge).

The engine stays honest here: a composite or family that cannot be built lands
in the validation report as an issue, and a metric that cannot be computed lands
in MetricResults.errors. Nothing is quietly skipped, and the caller (GUI or CLI)
renders the report.
"""

from __future__ import annotations

import numpy as np

from sphynx.acts.apply import eval_acts_library
from sphynx.acts.families import expand_family, family_event_stream
from sphynx.acts.schema import ActContext
from sphynx.acts.stats import act_stats
from sphynx.exceptions import SphynxError
from sphynx.logging_setup import get_logger
from sphynx.metrics.registry import MetricContext, compute_metric_refs
from sphynx.paradigms.registry import lineage, resolve_paradigm
from sphynx.paradigms.validate import ValidationIssue, validate_paradigm
from sphynx.zones.select import make_composite

_log = get_logger()


def _issue(report, code, message, where=""):
    report.issues.append(
        ValidationIssue(code=code, level="error", message=message, where=where))


def _opt(options, name, default):
    value = getattr(options, name, None) if options is not None else None
    return default if value is None else value


def _build_composites(resolved, zones, report):
    for spec in resolved.composites:
        try:
            zones.append(make_composite(spec.name, zones, spec.selector))
        except SphynxError as e:
            _issue(report, "composite_failed",
                   f'composite "{spec.name}" could not be built: {e}',
                   where=spec.name)


def _expand_families(resolved, zones, report):
    concrete = []
    for family in resolved.families:
        try:
            concrete.extend(expand_family(family, zones))
        except SphynxError as e:
            _issue(report, "family_failed",
                   f'act family "{family.name}" could not be expanded: {e}',
                   where=family.name)
    return concrete


def _act_context(result, zones, frame_rate):
    traces = result.body_parts_traces
    bpx = np.array([t.x_smooth for t in traces], dtype=float)
    bpy = np.array([t.y_smooth for t in traces], dtype=float)
    bpv = np.array(
        [t.velocity if t.velocity is not None else np.zeros(result.n_frames)
         for t in traces], dtype=float)
    x_kcorr = float(_opt(result.options, "x_kcorr", 1.0) or 1.0)
    return ActContext(
        X=bpx, Y=bpy, velocity_cm_s=bpv,
        body_parts=list(result.body_parts_names), zones=zones,
        frame_rate=frame_rate,
        pixels_per_cm=float(_opt(result.options, "pxl2sm", 1.0)),
        x_kcorr=x_kcorr if x_kcorr > 0 else 1.0,
    )


def _trajectory_cm(result, pixels_per_cm):
    """Centre trace in CENTIMETRES -- traces are stored in pixels."""
    index = result.point.center
    if index is None or index >= len(result.body_parts_traces):
        return None
    trace = result.body_parts_traces[index]
    if not pixels_per_cm > 0:
        return None
    return (np.asarray(trace.x_smooth, dtype=float) / pixels_per_cm,
            np.asarray(trace.y_smooth, dtype=float) / pixels_per_cm)


def apply_paradigm(result, paradigm, registry=None) -> None:
    """Run a paradigm over an already-analysed session, in place."""
    from sphynx.pipeline.analyze import SessionAct

    resolved = resolve_paradigm(paradigm, registry)
    result.paradigm = resolved.name
    result.paradigm_defaults = dict(resolved.config_defaults)

    zones = [] if result.zones is None else list(result.zones)
    report = validate_paradigm(resolved, zones, result.options)
    result.validation = report

    frame_rate = float(_opt(result.options, "FrameRate", 30.0))

    _build_composites(resolved, zones, report)
    concrete = _expand_families(resolved, zones, report)

    masks = {}
    if concrete:
        ctx = _act_context(result, zones, frame_rate)
        masks = eval_acts_library(concrete, ctx)
        result.degraded = dict(ctx.degraded)

        centre = result.point.center
        velocity = None
        if centre is not None and centre < len(result.body_parts_traces):
            velocity = result.body_parts_traces[centre].velocity
        for act in concrete:
            mask = masks.get(act.name)
            if mask is None:
                continue
            result.acts.append(SessionAct(
                name=act.name, array=np.asarray(mask, dtype=float),
                category="family",
                stats=act_stats(mask, frame_rate, velocity=velocity)))

        for family in resolved.families:
            members = [a for a in concrete if a.family == family.name]
            if members:
                result.event_streams[family.name] = family_event_stream(
                    members, masks, frame_rate, family=family.name)

    if resolved.metrics:
        pixels_per_cm = float(_opt(result.options, "pxl2sm", 0.0))
        metric_ctx = MetricContext(
            acts={a.name: a.array for a in result.acts},
            stats={a.name: a.stats for a in result.acts if a.stats is not None},
            events=dict(result.event_streams), act_defs=concrete, zones=zones,
            degraded=dict(result.degraded),
            trajectory_cm=_trajectory_cm(result, pixels_per_cm),
            frame_rate=frame_rate,
        )
        try:
            para_lineage = lineage(paradigm, registry)
        except SphynxError:
            para_lineage = (resolved.name,)
        result.metrics = compute_metric_refs(
            resolved.metrics, metric_ctx, paradigm=para_lineage)
```
- [ ] **Step 5: Wire it into analyze_session.** In `src/sphynx/pipeline/analyze.py`, change
  the signature and the return so they read:
```python
def analyze_session(config: Config, paradigm=None) -> SessionResult:
    """Run the full single-session pipeline and return a SessionResult.

    Required: config.paths.dlc, config.paths.preset. When `paradigm` is given
    (a name or a Paradigm), its validation, composites, act families and named
    metrics are computed onto the result as well.
    """
```
  and immediately before the final `return`, build the result into a local and apply the
  paradigm, so the tail of the function reads:
```python
    # --- 11. Result ---
    result = SessionResult(
        body_parts_names=kept_names, body_parts_traces=traces, point=point,
        acts=acts, options=options, zones=zones, arena_and_objects=arena,
        n_frames=n_frames, config=config,
        selected_individual=dlc.selected_individual or "",
        all_individuals=list(dlc.individuals) if dlc.individuals else [],
    )
    if paradigm is not None:
        from sphynx.pipeline.paradigm_bridge import apply_paradigm

        apply_paradigm(result, paradigm)
    return result
```
- [ ] **Step 6: Export.** In `src/sphynx/pipeline/__init__.py` add
  `from sphynx.pipeline.paradigm_bridge import apply_paradigm` and `"apply_paradigm"` to
  `__all__`.
- [ ] **Step 7: Run tests to verify they pass**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_paradigm_bridge.py -q`
Expected: PASS (11 passed). Then the full suite: `PYTHONPATH=src python -m pytest -q`

- [ ] **Step 8: Commit**
```bash
git add src/sphynx/pipeline tests/unit/test_paradigm_bridge.py
git commit -m "feat(python): S4a -- paradigm bridge (analyze_session gains paradigms)"
```

---

### Task 2: AppState

**Files:** Create `src/sphynx_gui/__init__.py`, `src/sphynx_gui/state.py`; Test `tests/gui/conftest.py`, `tests/gui/test_state.py`.
**Interfaces:**
- Produces: `AppState` (QObject) with properties `dlc_path`, `preset_path`, `out_dir`,
  `paradigm`, `config` (a `Config`), `result`; signals `paths_changed`, `paradigm_changed`,
  `result_changed`; method `build_config() -> Config`.

- [ ] **Step 1: Write the failing test** — `tests/gui/conftest.py`:
```python
import os

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
```
  and `tests/gui/test_state.py`:
```python
from sphynx.config import Config
from sphynx_gui.state import AppState


def test_defaults_are_empty(qtbot):
    state = AppState()
    assert state.dlc_path == ""
    assert state.preset_path == ""
    assert state.paradigm == "OF"
    assert state.result is None


def test_setting_a_path_emits_paths_changed(qtbot):
    state = AppState()
    with qtbot.waitSignal(state.paths_changed, timeout=500):
        state.dlc_path = "a.csv"
    assert state.dlc_path == "a.csv"


def test_setting_the_same_path_does_not_emit(qtbot):
    state = AppState()
    state.dlc_path = "a.csv"
    received = []
    state.paths_changed.connect(lambda: received.append(1))
    state.dlc_path = "a.csv"
    assert received == []


def test_paradigm_signal(qtbot):
    state = AppState()
    with qtbot.waitSignal(state.paradigm_changed, timeout=500):
        state.paradigm = "Barnes"
    assert state.paradigm == "Barnes"


def test_result_signal(qtbot):
    state = AppState()
    sentinel = object()
    with qtbot.waitSignal(state.result_changed, timeout=500):
        state.result = sentinel
    assert state.result is sentinel


def test_build_config_carries_paths_and_frames(qtbot):
    state = AppState()
    state.dlc_path = "d.csv"
    state.preset_path = "p.mat"
    state.out_dir = "out"
    state.end_frame = 3000
    config = state.build_config()
    assert isinstance(config, Config)
    assert config.paths.dlc == "d.csv"
    assert config.paths.preset == "p.mat"
    assert config.paths.out_dir == "out"
    assert config.frames.end_frame == 3000
    assert config.io.save_workspace is False


def test_build_config_returns_a_copy_each_time(qtbot):
    state = AppState()
    first = state.build_config()
    first.paths.dlc = "mutated"
    assert state.build_config().paths.dlc == ""


def test_settings_round_trip_through_toml(tmp_path, qtbot):
    state = AppState()
    state.dlc_path = "d.csv"
    state.preset_path = "p.mat"
    state.out_dir = "out"
    state.paradigm = "Barnes"
    state.end_frame = 1500
    state.heatmap_bin_cm = 6.0
    path = tmp_path / "settings.toml"
    state.save_settings(path)

    restored = AppState()
    restored.load_settings(path)
    assert restored.dlc_path == "d.csv"
    assert restored.preset_path == "p.mat"
    assert restored.out_dir == "out"
    assert restored.paradigm == "Barnes"
    assert restored.end_frame == 1500
    assert restored.heatmap_bin_cm == 6.0


def test_loading_a_missing_settings_file_raises(tmp_path, qtbot):
    from sphynx.exceptions import SphynxIOError

    state = AppState()
    with pytest.raises(SphynxIOError):
        state.load_settings(tmp_path / "nope.toml")
```
  (add `import pytest` at the top of the test file.)
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/gui/test_state.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'sphynx_gui'`

- [ ] **Step 3: Write the implementation.** Create `src/sphynx_gui/__init__.py`:
```python
"""Sphynx desktop GUI (PySide6). The engine package `sphynx` never imports Qt."""
```
  and `src/sphynx_gui/state.py`:
```python
"""Application-wide state (S4a).

One object holds the paths, the chosen paradigm and the last result, and every
tab subscribes to it. In the MATLAB app each tab loaded its own paths, which is
the "app-wide state" complaint in docs/TODO.md.
"""

from __future__ import annotations

import copy

from PySide6.QtCore import QObject, Signal

from sphynx.config import Config


class AppState(QObject):
    paths_changed = Signal()
    paradigm_changed = Signal()
    result_changed = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._dlc_path = ""
        self._preset_path = ""
        self._out_dir = ""
        self._paradigm = "OF"
        self._result = None
        self._config = Config.default()
        self.end_frame = 0
        self.heatmap_bin_cm = 4.0

    # --- paths ---
    @property
    def dlc_path(self) -> str:
        return self._dlc_path

    @dlc_path.setter
    def dlc_path(self, value: str) -> None:
        value = str(value or "")
        if value != self._dlc_path:
            self._dlc_path = value
            self.paths_changed.emit()

    @property
    def preset_path(self) -> str:
        return self._preset_path

    @preset_path.setter
    def preset_path(self, value: str) -> None:
        value = str(value or "")
        if value != self._preset_path:
            self._preset_path = value
            self.paths_changed.emit()

    @property
    def out_dir(self) -> str:
        return self._out_dir

    @out_dir.setter
    def out_dir(self, value: str) -> None:
        value = str(value or "")
        if value != self._out_dir:
            self._out_dir = value
            self.paths_changed.emit()

    # --- paradigm ---
    @property
    def paradigm(self) -> str:
        return self._paradigm

    @paradigm.setter
    def paradigm(self, value: str) -> None:
        value = str(value or "")
        if value != self._paradigm:
            self._paradigm = value
            self.paradigm_changed.emit()

    # --- result ---
    @property
    def result(self):
        return self._result

    @result.setter
    def result(self, value) -> None:
        self._result = value
        self.result_changed.emit()

    def build_config(self) -> Config:
        """A fresh Config for one run; the state's own config is never handed out."""
        config = copy.deepcopy(self._config)
        config.paths.dlc = self._dlc_path
        config.paths.preset = self._preset_path
        config.paths.out_dir = self._out_dir
        config.frames.end_frame = int(self.end_frame or 0)
        config.io.save_workspace = False
        return config

    # --- settings ---
    def save_settings(self, path) -> str:
        """Write paths, paradigm and view options to one TOML file."""
        data = {
            "paths": {"dlc": self._dlc_path, "preset": self._preset_path,
                      "out_dir": self._out_dir},
            "analysis": {"paradigm": self._paradigm,
                         "end_frame": int(self.end_frame or 0),
                         "heatmap_bin_cm": float(self.heatmap_bin_cm)},
        }
        target = Path(path)
        try:
            target.parent.mkdir(parents=True, exist_ok=True)
            with open(target, "wb") as handle:
                tomli_w.dump(data, handle)
        except OSError as e:
            raise SphynxIOError(f"cannot write settings to {target}: {e}") from e
        return str(target)

    def load_settings(self, path) -> None:
        source = Path(path)
        if not source.is_file():
            raise SphynxIOError(f"settings file not found: {source}")
        try:
            with open(source, "rb") as handle:
                data = tomllib.load(handle)
        except tomllib.TOMLDecodeError as e:
            raise SphynxIOError(f"malformed settings TOML in {source}: {e}") from e
        except OSError as e:
            raise SphynxIOError(f"cannot read settings from {source}: {e}") from e

        paths = data.get("paths", {})
        analysis = data.get("analysis", {})
        self.dlc_path = paths.get("dlc", "")
        self.preset_path = paths.get("preset", "")
        self.out_dir = paths.get("out_dir", "")
        self.paradigm = analysis.get("paradigm", "OF")
        self.end_frame = int(analysis.get("end_frame", 0))
        self.heatmap_bin_cm = float(analysis.get("heatmap_bin_cm", 4.0))
```
  with these imports at the top of `state.py`:
```python
import copy
import tomllib
from pathlib import Path

import tomli_w
from PySide6.QtCore import QObject, Signal

from sphynx.config import Config
from sphynx.exceptions import SphynxIOError
```
- [ ] **Step 4: Run tests to verify they pass**

Run: `PYTHONPATH=src python -m pytest tests/gui/test_state.py -q`
Expected: PASS (9 passed)

- [ ] **Step 5: Commit**
```bash
git add src/sphynx_gui tests/gui
git commit -m "feat(gui): S4a -- AppState with Qt signals"
```

---

### Task 3: analysis worker

**Files:** Create `src/sphynx_gui/worker.py`; Test `tests/gui/test_worker.py`.
**Interfaces:**
- Consumes: `analyze_session(config, paradigm=None)`, `AppState.build_config()`.
- Produces: `AnalysisWorker(config, paradigm=None)` (QObject) with signals
  `finished(object)`, `failed(str)`, `progress(str)` and a synchronous `run()` slot.

- [ ] **Step 1: Write the failing test** — `tests/gui/test_worker.py`:
```python
import pytest

import sphynx_gui.worker as worker_module
from sphynx.config import Config
from sphynx.exceptions import SphynxIOError
from sphynx_gui.worker import AnalysisWorker


def test_success_emits_finished(qtbot, monkeypatch):
    sentinel = object()
    monkeypatch.setattr(worker_module, "analyze_session",
                        lambda config, paradigm=None: sentinel)
    worker = AnalysisWorker(Config.default(), paradigm="OF")
    with qtbot.waitSignal(worker.finished, timeout=1000) as blocker:
        worker.run()
    assert blocker.args[0] is sentinel


def test_engine_error_emits_failed_not_raise(qtbot, monkeypatch):
    def boom(config, paradigm=None):
        raise SphynxIOError("DLC csv not found: nowhere.csv")

    monkeypatch.setattr(worker_module, "analyze_session", boom)
    worker = AnalysisWorker(Config.default())
    with qtbot.waitSignal(worker.failed, timeout=1000) as blocker:
        worker.run()
    assert "nowhere.csv" in blocker.args[0]


def test_unexpected_error_is_labelled(qtbot, monkeypatch):
    def boom(config, paradigm=None):
        raise ZeroDivisionError("bad maths")

    monkeypatch.setattr(worker_module, "analyze_session", boom)
    worker = AnalysisWorker(Config.default())
    with qtbot.waitSignal(worker.failed, timeout=1000) as blocker:
        worker.run()
    assert "ZeroDivisionError" in blocker.args[0]


def test_paradigm_is_passed_through(qtbot, monkeypatch):
    seen = {}

    def capture(config, paradigm=None):
        seen["paradigm"] = paradigm
        return object()

    monkeypatch.setattr(worker_module, "analyze_session", capture)
    worker = AnalysisWorker(Config.default(), paradigm="Barnes")
    with qtbot.waitSignal(worker.finished, timeout=1000):
        worker.run()
    assert seen["paradigm"] == "Barnes"


def test_progress_is_emitted_before_the_run(qtbot, monkeypatch):
    monkeypatch.setattr(worker_module, "analyze_session",
                        lambda config, paradigm=None: object())
    worker = AnalysisWorker(Config.default())
    messages = []
    worker.progress.connect(messages.append)
    worker.run()
    assert messages and "Analysing" in messages[0]
```
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/gui/test_worker.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'sphynx_gui.worker'`

- [ ] **Step 3: Write the implementation.** Create `src/sphynx_gui/worker.py`:
```python
"""Run one analysis off the UI thread (S4a).

`run()` is an ordinary synchronous method, so it is testable without a thread;
the window moves the worker into a QThread and calls it there.
"""

from __future__ import annotations

from PySide6.QtCore import QObject, Signal, Slot

from sphynx.exceptions import SphynxError
from sphynx.pipeline.analyze import analyze_session


class AnalysisWorker(QObject):
    finished = Signal(object)     # SessionResult
    failed = Signal(str)
    progress = Signal(str)

    def __init__(self, config, paradigm=None, parent=None):
        super().__init__(parent)
        self._config = config
        self._paradigm = paradigm

    @Slot()
    def run(self) -> None:
        self.progress.emit("Analysing session...")
        try:
            result = analyze_session(self._config, paradigm=self._paradigm)
        except SphynxError as e:
            # An engine refusal is a message for the user, not a crash.
            self.failed.emit(str(e))
            return
        except Exception as e:      # noqa: BLE001 - a bug must not kill the app
            self.failed.emit(f"unexpected {type(e).__name__}: {e}")
            return
        self.finished.emit(result)
```
- [ ] **Step 4: Run tests to verify they pass**

Run: `PYTHONPATH=src python -m pytest tests/gui/test_worker.py -q`
Expected: PASS (5 passed)

- [ ] **Step 5: Commit**
```bash
git add src/sphynx_gui/worker.py tests/gui/test_worker.py
git commit -m "feat(gui): S4a -- analysis worker with error signals"
```

---

### Task 4: six-tab shell and entry point

**Files:** Create `src/sphynx_gui/placeholder_tab.py`, `src/sphynx_gui/main_window.py`, `src/sphynx_gui/app.py`; Test `tests/gui/test_main_window.py`, `tests/gui/test_engine_has_no_qt.py`.
**Interfaces:**
- Consumes: `AppState`.
- Produces: `PlaceholderTab(title, slice_name)`; `MainWindow(state=None)` with
  `TAB_TITLES` (tuple of six titles) and `.tabs` (QTabWidget); `main(argv=None) -> int`.

- [ ] **Step 1: Write the failing tests** — `tests/gui/test_main_window.py`:
```python
from sphynx_gui.main_window import MainWindow
from sphynx_gui.placeholder_tab import PlaceholderTab
from sphynx_gui.state import AppState


def test_six_tabs_in_workflow_order(qtbot):
    window = MainWindow()
    qtbot.addWidget(window)
    titles = [window.tabs.tabText(i) for i in range(window.tabs.count())]
    assert titles == [
        "Create Preset", "Preprocess Tracking", "Define Acts",
        "Analyze Session", "Batch Analysis", "Make Output",
    ]


def test_five_tabs_are_placeholders_naming_their_slice(qtbot):
    window = MainWindow()
    qtbot.addWidget(window)
    placeholders = [window.tabs.widget(i) for i in range(window.tabs.count())
                    if isinstance(window.tabs.widget(i), PlaceholderTab)]
    assert len(placeholders) == 5
    for tab in placeholders:
        assert tab.slice_name.startswith("S4")


def test_analyze_tab_is_live_and_selected(qtbot):
    window = MainWindow()
    qtbot.addWidget(window)
    index = window.tabs.indexOf(window.analyze_tab)
    assert index >= 0
    assert not isinstance(window.analyze_tab, PlaceholderTab)
    assert window.tabs.currentIndex() == index


def test_state_is_shared_with_the_analyze_tab(qtbot):
    state = AppState()
    window = MainWindow(state=state)
    qtbot.addWidget(window)
    assert window.state is state
    assert window.analyze_tab.state is state


def test_window_has_a_title(qtbot):
    window = MainWindow()
    qtbot.addWidget(window)
    assert "Sphynx" in window.windowTitle()
```
  and `tests/gui/test_engine_has_no_qt.py`:
```python
import os
import subprocess
import sys


def test_engine_never_imports_qt():
    # The engine must stay usable headless and from the CLI, so importing it
    # must not drag Qt in. A fresh interpreter is the only honest check.
    code = (
        "import sphynx, sphynx.pipeline, sphynx.paradigms, sphynx.metrics, sys;"
        "print(any(m.startswith('PySide') for m in sys.modules))"
    )
    env = dict(os.environ)
    env["PYTHONPATH"] = "src"
    out = subprocess.run([sys.executable, "-c", code], capture_output=True,
                         text=True, env=env)
    assert out.returncode == 0, out.stderr
    assert out.stdout.strip() == "False", out.stderr
```
- [ ] **Step 2: Run tests to verify they fail**

Run: `PYTHONPATH=src python -m pytest tests/gui/test_main_window.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'sphynx_gui.main_window'`

- [ ] **Step 3: Write the placeholder tab.** Create `src/sphynx_gui/placeholder_tab.py`:
```python
"""Stub for a tab that a later slice fills in (S4a)."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import QLabel, QVBoxLayout, QWidget


class PlaceholderTab(QWidget):
    def __init__(self, title: str, slice_name: str, detail: str = "", parent=None):
        super().__init__(parent)
        self.title = title
        self.slice_name = slice_name

        heading = QLabel(title)
        heading.setAlignment(Qt.AlignCenter)
        font = heading.font()
        font.setPointSize(font.pointSize() + 4)
        font.setBold(True)
        heading.setFont(font)

        note = QLabel(f"Arrives in slice {slice_name}." + (f"\n{detail}" if detail else ""))
        note.setAlignment(Qt.AlignCenter)
        note.setWordWrap(True)

        layout = QVBoxLayout(self)
        layout.addStretch(1)
        layout.addWidget(heading)
        layout.addWidget(note)
        layout.addStretch(1)
```
- [ ] **Step 4: Write the window.** Create `src/sphynx_gui/main_window.py`:
```python
"""The application window: six tabs sharing one AppState (S4a)."""

from __future__ import annotations

from PySide6.QtWidgets import QMainWindow, QTabWidget

from sphynx_gui.analyze_tab import AnalyzeTab
from sphynx_gui.placeholder_tab import PlaceholderTab
from sphynx_gui.state import AppState

TAB_TITLES = (
    "Create Preset", "Preprocess Tracking", "Define Acts",
    "Analyze Session", "Batch Analysis", "Make Output",
)

_PLACEHOLDERS = {
    "Create Preset": ("S4d", "Draw zones, mark roles, calibrate, set the arena centre."),
    "Preprocess Tracking": ("S4e", "Per-body-part cleaning, interpolation and smoothing."),
    "Define Acts": ("S4b", "Two-panel act and metric constructor."),
    "Batch Analysis": ("S4c", "Run many sessions and aggregate them."),
    "Make Output": ("S4c", "Build the wide and tidy export tables."),
}


class MainWindow(QMainWindow):
    def __init__(self, state: AppState | None = None, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Sphynx")
        self.state = state if state is not None else AppState()

        self.tabs = QTabWidget()
        self.analyze_tab = AnalyzeTab(self.state)

        for title in TAB_TITLES:
            if title == "Analyze Session":
                self.tabs.addTab(self.analyze_tab, title)
            else:
                slice_name, detail = _PLACEHOLDERS[title]
                self.tabs.addTab(PlaceholderTab(title, slice_name, detail), title)

        self.tabs.setCurrentIndex(self.tabs.indexOf(self.analyze_tab))
        self.setCentralWidget(self.tabs)
        self.resize(1280, 860)
```
- [ ] **Step 5: Write the entry point.** Create `src/sphynx_gui/app.py`:
```python
"""Entry point: `python -m sphynx_gui.app` (S4a)."""

from __future__ import annotations

import sys

from PySide6.QtWidgets import QApplication

from sphynx.paradigms import PARADIGMS, register_builtin_paradigms
from sphynx_gui.main_window import MainWindow


def main(argv=None) -> int:
    if not PARADIGMS:
        register_builtin_paradigms()
    app = QApplication(argv if argv is not None else sys.argv)
    window = MainWindow()
    window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
```
> **Prerequisite:** Task 7 must already be implemented -- `main_window.py` imports
> `AnalyzeTab`. The dispatch order at the end of this plan puts Task 7 first.

- [ ] **Step 6: Run tests to verify they pass**

Run: `PYTHONPATH=src python -m pytest tests/gui -q`
Expected: PASS (all GUI tests, including this task's 5 window tests and the no-Qt guard)

- [ ] **Step 7: Commit**
```bash
git add src/sphynx_gui/main_window.py src/sphynx_gui/placeholder_tab.py src/sphynx_gui/app.py tests/gui/test_main_window.py tests/gui/test_engine_has_no_qt.py
git commit -m "feat(gui): S4a -- six-tab shell and entry point"
```

---

### Task 5: warnings panel

**Files:** Create `src/sphynx_gui/warnings_panel.py`; Test `tests/gui/test_warnings_panel.py`.
**Interfaces:**
- Consumes: `SessionResult.validation` (ValidationReport), `.degraded` (dict),
  `.metrics` (MetricResults).
- Produces: `WarningsPanel` (QWidget) with `.show_result(result)`, `.clear()`,
  `.rows` (list of `(source, level, text)`), `.list_widget` (QListWidget).

- [ ] **Step 1: Write the failing test** — `tests/gui/test_warnings_panel.py`:
```python
from sphynx.metrics.registry import MetricResults
from sphynx.paradigms.validate import ValidationIssue, ValidationReport
from sphynx_gui.warnings_panel import WarningsPanel


class _Result:
    def __init__(self, validation=None, degraded=None, metrics=None):
        self.validation = validation
        self.degraded = degraded or {}
        self.metrics = metrics


def test_empty_result_says_nothing_is_wrong(qtbot):
    panel = WarningsPanel()
    qtbot.addWidget(panel)
    panel.show_result(_Result())
    assert panel.rows == []
    assert "No warnings" in panel.list_widget.item(0).text()


def test_validation_errors_and_warnings_are_listed(qtbot):
    report = ValidationReport(paradigm="EOF", issues=[
        ValidationIssue("needs_object", "error", "needs at least one object"),
        ValidationIssue("soft", "warning", "something to check"),
    ])
    panel = WarningsPanel()
    qtbot.addWidget(panel)
    panel.show_result(_Result(validation=report))
    sources = [row[0] for row in panel.rows]
    levels = [row[1] for row in panel.rows]
    assert sources == ["validation", "validation"]
    assert levels == ["error", "warning"]
    assert "at least one object" in panel.rows[0][2]


def test_degraded_acts_are_listed(qtbot):
    panel = WarningsPanel()
    qtbot.addWidget(panel)
    panel.show_result(_Result(degraded={"nose_at_hole1": ['body part "nose" not found']}))
    assert panel.rows[0][0] == "act"
    assert "nose_at_hole1" in panel.rows[0][2]
    assert "nose" in panel.rows[0][2]


def test_metric_errors_are_listed(qtbot):
    metrics = MetricResults(values={"ok": 1.0},
                            errors={"primary_errors": "missing geometry: target_zone"})
    panel = WarningsPanel()
    qtbot.addWidget(panel)
    panel.show_result(_Result(metrics=metrics))
    assert panel.rows[0][0] == "metric"
    assert "primary_errors" in panel.rows[0][2]


def test_all_three_sources_combine(qtbot):
    report = ValidationReport(paradigm="Barnes", issues=[
        ValidationIssue("needs_one_target", "error", "exactly one target")])
    metrics = MetricResults(errors={"target_ordinal": "no target member"})
    panel = WarningsPanel()
    qtbot.addWidget(panel)
    panel.show_result(_Result(validation=report, degraded={"a": ["gone"]},
                              metrics=metrics))
    assert [row[0] for row in panel.rows] == ["validation", "act", "metric"]
    assert panel.list_widget.count() == 3


def test_clear_resets_the_panel(qtbot):
    panel = WarningsPanel()
    qtbot.addWidget(panel)
    panel.show_result(_Result(degraded={"a": ["gone"]}))
    panel.clear()
    assert panel.rows == []


def test_showing_a_new_result_replaces_the_old_rows(qtbot):
    panel = WarningsPanel()
    qtbot.addWidget(panel)
    panel.show_result(_Result(degraded={"a": ["gone"]}))
    panel.show_result(_Result())
    assert panel.rows == []
```
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/gui/test_warnings_panel.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'sphynx_gui.warnings_panel'`

- [ ] **Step 3: Write the implementation.** Create `src/sphynx_gui/warnings_panel.py`:
```python
"""The section-10 surface: everything the engine refused to guess (S4a).

Three sources in one place -- paradigm validation, degraded acts and metric
failures. An empty panel is a real signal, not an absence of information, so it
says so explicitly.
"""

from __future__ import annotations

from PySide6.QtWidgets import QGroupBox, QListWidget, QVBoxLayout

_PREFIX = {"error": "[!]", "warning": "[?]", "info": "[i]"}


class WarningsPanel(QGroupBox):
    def __init__(self, parent=None):
        super().__init__("Warnings", parent)
        self.rows: list = []
        self.list_widget = QListWidget()
        layout = QVBoxLayout(self)
        layout.addWidget(self.list_widget)
        self._render()

    def clear(self) -> None:
        self.rows = []
        self._render()

    def show_result(self, result) -> None:
        rows: list = []

        report = getattr(result, "validation", None)
        if report is not None:
            for issue in report.issues:
                rows.append(("validation", issue.level,
                             f"{issue.code}: {issue.message}"))

        for act_name, reasons in (getattr(result, "degraded", None) or {}).items():
            rows.append(("act", "warning",
                         f"{act_name}: " + "; ".join(reasons)))

        metrics = getattr(result, "metrics", None)
        if metrics is not None:
            for name, message in metrics.errors.items():
                rows.append(("metric", "error", f"{name}: {message}"))

        self.rows = rows
        self._render()

    def _render(self) -> None:
        self.list_widget.clear()
        if not self.rows:
            self.list_widget.addItem("No warnings: nothing was left unresolved.")
            return
        for source, level, text in self.rows:
            self.list_widget.addItem(
                f"{_PREFIX.get(level, '[i]')} {source}: {text}")
```
- [ ] **Step 4: Run tests to verify they pass**

Run: `PYTHONPATH=src python -m pytest tests/gui/test_warnings_panel.py -q`
Expected: PASS (7 passed)

- [ ] **Step 5: Commit**
```bash
git add src/sphynx_gui/warnings_panel.py tests/gui/test_warnings_panel.py
git commit -m "feat(gui): S4a -- warnings panel (validation + degraded acts + metric errors)"
```

---

### Task 6: 2x2 plot grid

**Files:** Create `src/sphynx_gui/plot_grid.py`; Test `tests/gui/test_plot_grid.py`.
**Interfaces:**
- Consumes: `SessionResult` (body_parts_traces, options).
- Produces: `PlotGrid` (QWidget) with `.show_result(result, heatmap_bin_cm=4.0)`,
  `.clear()`, `.canvases` (dict name -> FigureCanvas), `.maximised` (str | None),
  `.toggle_maximise(name)`. Plot names: `"trajectory"`, `"heatmap"`,
  `"speed_histogram"`, `"speed_vs_time"`.

- [ ] **Step 1: Write the failing test** — `tests/gui/test_plot_grid.py`:
```python
import numpy as np

from sphynx_gui.plot_grid import PlotGrid


class _Trace:
    def __init__(self, name, n=100):
        self.name = name
        self.x_smooth = np.linspace(10.0, 90.0, n)
        self.y_smooth = np.linspace(10.0, 90.0, n)
        self.velocity = np.linspace(0.0, 5.0, n)


class _Options:
    pxl2sm = 10.0
    FrameRate = 30.0
    Width = 100
    Height = 100


class _Result:
    def __init__(self):
        self.body_parts_traces = [_Trace("bodycenter")]
        self.options = _Options()


def test_four_named_canvases(qtbot):
    grid = PlotGrid()
    qtbot.addWidget(grid)
    assert set(grid.canvases) == {
        "trajectory", "heatmap", "speed_histogram", "speed_vs_time"}


def test_show_result_draws_every_panel(qtbot):
    grid = PlotGrid()
    qtbot.addWidget(grid)
    grid.show_result(_Result())
    for canvas in grid.canvases.values():
        assert canvas.figure.axes            # something was plotted


def test_clear_empties_the_figures(qtbot):
    grid = PlotGrid()
    qtbot.addWidget(grid)
    grid.show_result(_Result())
    grid.clear()
    for canvas in grid.canvases.values():
        assert canvas.figure.axes == []


def test_toggle_maximise_hides_the_others(qtbot):
    grid = PlotGrid()
    qtbot.addWidget(grid)
    grid.toggle_maximise("heatmap")
    assert grid.maximised == "heatmap"
    assert grid.canvases["trajectory"].isHidden()
    assert not grid.canvases["heatmap"].isHidden()


def test_toggle_maximise_twice_restores_the_grid(qtbot):
    grid = PlotGrid()
    qtbot.addWidget(grid)
    grid.toggle_maximise("heatmap")
    grid.toggle_maximise("heatmap")
    assert grid.maximised is None
    assert not grid.canvases["trajectory"].isHidden()


def test_missing_trace_does_not_crash(qtbot):
    class _Empty:
        body_parts_traces = []
        options = _Options()

    grid = PlotGrid()
    qtbot.addWidget(grid)
    grid.show_result(_Empty())               # must not raise
    assert grid.canvases
```
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/gui/test_plot_grid.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'sphynx_gui.plot_grid'`

- [ ] **Step 3: Write the implementation.** Create `src/sphynx_gui/plot_grid.py`:
```python
"""Four session plots in a 2x2 grid, any one of which can be maximised (S4a).

Rendering reuses the same maths as sphynx.plot.session_plots but draws onto
embedded canvases instead of writing PNGs.
"""

from __future__ import annotations

import numpy as np
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure
from PySide6.QtWidgets import QGridLayout, QWidget
from scipy.ndimage import gaussian_filter

PLOT_NAMES = ("trajectory", "heatmap", "speed_histogram", "speed_vs_time")
_TITLES = {
    "trajectory": "Trajectory",
    "heatmap": "Occupancy",
    "speed_histogram": "Speed histogram",
    "speed_vs_time": "Speed vs time",
}
_POSITIONS = {"trajectory": (0, 0), "heatmap": (0, 1),
              "speed_histogram": (1, 0), "speed_vs_time": (1, 1)}


class _ClickableCanvas(FigureCanvas):
    def __init__(self, figure, name, on_double_click):
        super().__init__(figure)
        self._name = name
        self._on_double_click = on_double_click

    def mouseDoubleClickEvent(self, event):   # noqa: N802 - Qt naming
        self._on_double_click(self._name)
        super().mouseDoubleClickEvent(event)


def _opt(options, name, default):
    value = getattr(options, name, None) if options is not None else None
    return default if value is None else value


def _reference_trace(result):
    traces = list(getattr(result, "body_parts_traces", []) or [])
    if not traces:
        return None
    for trace in traces:
        if str(getattr(trace, "name", "")).lower() == "bodycenter":
            return trace
    return traces[0]


class PlotGrid(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.canvases: dict = {}
        self.maximised: str | None = None
        self._layout = QGridLayout(self)
        for name in PLOT_NAMES:
            canvas = _ClickableCanvas(Figure(figsize=(4, 3)), name,
                                      self.toggle_maximise)
            self.canvases[name] = canvas
            row, column = _POSITIONS[name]
            self._layout.addWidget(canvas, row, column)

    def clear(self) -> None:
        for canvas in self.canvases.values():
            canvas.figure.clear()
            canvas.draw_idle()

    def toggle_maximise(self, name: str) -> None:
        self.maximised = None if self.maximised == name else name
        for other, canvas in self.canvases.items():
            canvas.setVisible(self.maximised is None or other == self.maximised)

    def show_result(self, result, heatmap_bin_cm: float = 4.0) -> None:
        trace = _reference_trace(result)
        options = getattr(result, "options", None)
        pixels_per_cm = float(_opt(options, "pxl2sm", 1.0)) or 1.0
        frame_rate = float(_opt(options, "FrameRate", 30.0)) or 30.0

        if trace is None:
            self.clear()
            return

        x_cm = np.asarray(trace.x_smooth, dtype=float) / pixels_per_cm
        y_cm = np.asarray(trace.y_smooth, dtype=float) / pixels_per_cm
        velocity = np.asarray(
            trace.velocity if trace.velocity is not None else [], dtype=float)

        self._draw_trajectory(x_cm, y_cm)
        self._draw_heatmap(x_cm, y_cm, options, pixels_per_cm,
                           heatmap_bin_cm, frame_rate)
        self._draw_speed_histogram(velocity)
        self._draw_speed_trace(velocity, frame_rate)
        for canvas in self.canvases.values():
            canvas.draw_idle()

    def _axes(self, name):
        figure = self.canvases[name].figure
        figure.clear()
        axes = figure.add_subplot(111)
        axes.set_title(_TITLES[name], fontsize=10)
        return axes

    def _draw_trajectory(self, x_cm, y_cm):
        axes = self._axes("trajectory")
        axes.plot(x_cm, y_cm, "-", color=(0.10, 0.50, 0.90), linewidth=1.0)
        axes.set_aspect("equal", adjustable="box")
        axes.invert_yaxis()
        axes.set_xlabel("X, cm")
        axes.set_ylabel("Y, cm")

    def _draw_heatmap(self, x_cm, y_cm, options, pixels_per_cm, bin_cm, frame_rate):
        axes = self._axes("heatmap")
        valid = np.isfinite(x_cm) & np.isfinite(y_cm)
        if not valid.any():
            return
        width = _opt(options, "Width", None)
        height = _opt(options, "Height", None)
        extent_x = (float(width) / pixels_per_cm if width is not None
                    else float(np.nanmax(x_cm)))
        extent_y = (float(height) / pixels_per_cm if height is not None
                    else float(np.nanmax(y_cm)))
        edges_x = np.arange(0, max(extent_x, bin_cm) + bin_cm, bin_cm)
        edges_y = np.arange(0, max(extent_y, bin_cm) + bin_cm, bin_cm)
        counts, _, _ = np.histogram2d(x_cm[valid], y_cm[valid],
                                      bins=[edges_x, edges_y])
        seconds = gaussian_filter(counts / frame_rate, sigma=1)
        image = axes.imshow(
            seconds.T, origin="upper", aspect="equal", cmap="viridis",
            extent=[edges_x[0], edges_x[-1], edges_y[-1], edges_y[0]])
        axes.figure.colorbar(image, ax=axes, label="time, s")
        axes.set_xlabel("X, cm")
        axes.set_ylabel("Y, cm")

    def _draw_speed_histogram(self, velocity):
        axes = self._axes("speed_histogram")
        finite = velocity[np.isfinite(velocity)] if velocity.size else velocity
        if finite.size:
            axes.hist(finite, bins=100, color=(0.30, 0.70, 0.30), edgecolor="none")
        axes.set_xlabel("speed, cm/s")
        axes.set_ylabel("frames")

    def _draw_speed_trace(self, velocity, frame_rate):
        axes = self._axes("speed_vs_time")
        if velocity.size:
            axes.plot(np.arange(velocity.size) / frame_rate, velocity, "-",
                      color=(0.30, 0.55, 0.85), linewidth=0.8)
        axes.set_xlabel("time, s")
        axes.set_ylabel("speed, cm/s")
```
- [ ] **Step 4: Run tests to verify they pass**

Run: `PYTHONPATH=src python -m pytest tests/gui/test_plot_grid.py -q`
Expected: PASS (6 passed)

- [ ] **Step 5: Commit**
```bash
git add src/sphynx_gui/plot_grid.py tests/gui/test_plot_grid.py
git commit -m "feat(gui): S4a -- 2x2 plot grid with maximise"
```

---

### Task 7: Analyze tab and controller

**Files:** Create `src/sphynx_gui/analyze_tab.py`, `src/sphynx_gui/analyze_controller.py`; Test `tests/gui/test_analyze_tab.py`.
**Interfaces:**
- Consumes: `AppState`, `AnalysisWorker`, `WarningsPanel`, `PlotGrid`,
  `register_builtin_paradigms()`, `PARADIGMS`.
- Produces: `AnalyzeTab(state)` (QWidget) exposing `.state`, `.controller`,
  `.paradigm_box` (QComboBox), `.run_button`, `.status_label`, `.acts_table`,
  `.metrics_table`, `.warnings`, `.plots`;
  `AnalyzeController(state, tab)` with `.run()`, `.on_finished(result)`,
  `.on_failed(message)`.

- [ ] **Step 1: Write the failing test** — `tests/gui/test_analyze_tab.py`:
```python
import numpy as np
import pytest

from sphynx.acts.stats import act_stats
from sphynx.metrics.registry import MetricResults
from sphynx.paradigms import PARADIGMS, register_builtin_paradigms
from sphynx.paradigms.validate import ValidationIssue, ValidationReport
from sphynx.pipeline.analyze import SessionAct
from sphynx_gui.analyze_tab import AnalyzeTab
from sphynx_gui.state import AppState


@pytest.fixture(autouse=True)
def _builtins():
    saved = dict(PARADIGMS)
    PARADIGMS.clear()
    register_builtin_paradigms()
    yield
    PARADIGMS.clear()
    PARADIGMS.update(saved)


class _Trace:
    name = "bodycenter"
    x_smooth = np.linspace(10.0, 90.0, 50)
    y_smooth = np.linspace(10.0, 90.0, 50)
    velocity = np.linspace(0.0, 4.0, 50)


class _Options:
    pxl2sm = 10.0
    FrameRate = 10.0
    Width = 100
    Height = 100


def _result():
    mask = np.zeros(50)
    mask[5:15] = 1.0

    class _R:
        body_parts_traces = [_Trace()]
        options = _Options()
        acts = [SessionAct("rest", mask, "builtin", act_stats(mask, 10.0))]
        validation = ValidationReport(paradigm="OF", issues=[
            ValidationIssue("needs_calibration", "error", "pxl2sm is not set")])
        degraded = {}
        metrics = MetricResults(values={"path_length": 12.5},
                                errors={"target_ordinal": "no target member"})
    return _R()


def test_paradigm_box_lists_the_registered_paradigms(qtbot):
    tab = AnalyzeTab(AppState())
    qtbot.addWidget(tab)
    items = [tab.paradigm_box.itemText(i) for i in range(tab.paradigm_box.count())]
    assert "OF" in items and "Barnes" in items


def test_choosing_a_paradigm_updates_the_state(qtbot):
    state = AppState()
    tab = AnalyzeTab(state)
    qtbot.addWidget(tab)
    tab.paradigm_box.setCurrentText("Barnes")
    assert state.paradigm == "Barnes"


def test_run_without_paths_reports_instead_of_starting(qtbot):
    state = AppState()
    tab = AnalyzeTab(state)
    qtbot.addWidget(tab)
    tab.controller.run()
    assert "DLC" in tab.status_label.text() or "preset" in tab.status_label.text()


def test_on_finished_fills_the_acts_table(qtbot):
    tab = AnalyzeTab(AppState())
    qtbot.addWidget(tab)
    tab.controller.on_finished(_result())
    assert tab.acts_table.rowCount() == 1
    assert tab.acts_table.item(0, 0).text() == "rest"


def test_on_finished_fills_metrics_including_errors(qtbot):
    tab = AnalyzeTab(AppState())
    qtbot.addWidget(tab)
    tab.controller.on_finished(_result())
    names = [tab.metrics_table.item(r, 0).text()
             for r in range(tab.metrics_table.rowCount())]
    assert "path_length" in names
    assert "target_ordinal" in names          # a failed metric is still shown
    row = names.index("target_ordinal")
    assert "no target member" in tab.metrics_table.item(row, 1).text()


def test_on_finished_populates_warnings(qtbot):
    tab = AnalyzeTab(AppState())
    qtbot.addWidget(tab)
    tab.controller.on_finished(_result())
    sources = [row[0] for row in tab.warnings.rows]
    assert "validation" in sources and "metric" in sources


def test_on_finished_stores_the_result_in_state(qtbot):
    state = AppState()
    tab = AnalyzeTab(state)
    qtbot.addWidget(tab)
    result = _result()
    tab.controller.on_finished(result)
    assert state.result is result


def test_on_failed_shows_the_message_and_reenables_run(qtbot):
    tab = AnalyzeTab(AppState())
    qtbot.addWidget(tab)
    tab.run_button.setEnabled(False)
    tab.controller.on_failed("DLC csv not found: nowhere.csv")
    assert "nowhere.csv" in tab.status_label.text()
    assert tab.run_button.isEnabled()
```
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/gui/test_analyze_tab.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'sphynx_gui.analyze_tab'`

- [ ] **Step 3: Write the controller.** Create `src/sphynx_gui/analyze_controller.py`:
```python
"""Analyze tab controller (S4a).

The widget holds no engine logic: this object reads AppState, starts the worker
on a thread, and pushes the result into the widget.
"""

from __future__ import annotations

import math

from PySide6.QtCore import QObject, QThread

from sphynx_gui.worker import AnalysisWorker

_ACT_COLUMNS = ("Act", "%", "Episodes", "Duration, s", "Distance, cm", "Speed, cm/s")


def _format(value) -> str:
    if value is None:
        return ""
    if isinstance(value, float):
        return "n/a" if math.isnan(value) else f"{value:.2f}"
    return str(value)


class AnalyzeController(QObject):
    def __init__(self, state, tab, parent=None):
        super().__init__(parent)
        self.state = state
        self.tab = tab
        self._thread = None
        self._worker = None

    def run(self) -> None:
        if not self.state.dlc_path:
            self.tab.set_status("Choose a DLC csv first.")
            return
        if not self.state.preset_path:
            self.tab.set_status("Choose a preset .mat first.")
            return

        self.tab.set_busy(True)
        self.tab.set_status("Analysing session...")

        config = self.state.build_config()
        self._worker = AnalysisWorker(config, paradigm=self.state.paradigm or None)
        self._thread = QThread()
        self._worker.moveToThread(self._thread)
        self._thread.started.connect(self._worker.run)
        self._worker.progress.connect(self.tab.set_status)
        self._worker.finished.connect(self.on_finished)
        self._worker.failed.connect(self.on_failed)
        self._worker.finished.connect(self._thread.quit)
        self._worker.failed.connect(self._thread.quit)
        self._thread.start()

    def on_finished(self, result) -> None:
        self.tab.set_busy(False)
        self.state.result = result
        self.tab.show_result(result)
        acts = len(getattr(result, "acts", []) or [])
        self.tab.set_status(f"Done: {acts} acts over "
                            f"{getattr(result, 'n_frames', 0)} frames.")

    def on_failed(self, message: str) -> None:
        self.tab.set_busy(False)
        self.tab.set_status(f"Failed: {message}")
```
- [ ] **Step 4: Write the tab.** Create `src/sphynx_gui/analyze_tab.py`:
```python
"""Analyze Session tab (S4a)."""

from __future__ import annotations

from PySide6.QtWidgets import (
    QComboBox, QDoubleSpinBox, QFileDialog, QFormLayout, QGroupBox, QHBoxLayout,
    QLabel, QPushButton, QSpinBox, QSplitter, QTableWidget, QTableWidgetItem,
    QVBoxLayout, QWidget,
)
from PySide6.QtCore import Qt

from sphynx.paradigms import PARADIGMS, register_builtin_paradigms
from sphynx_gui.analyze_controller import _ACT_COLUMNS, AnalyzeController, _format
from sphynx_gui.plot_grid import PlotGrid
from sphynx_gui.warnings_panel import WarningsPanel


class AnalyzeTab(QWidget):
    def __init__(self, state, parent=None):
        super().__init__(parent)
        self.state = state
        if not PARADIGMS:
            register_builtin_paradigms()

        self.controller = AnalyzeController(state, self)
        self._build_ui()
        self._connect()

    # --- construction ---
    def _build_ui(self) -> None:
        self.dlc_label = QLabel("(none)")
        self.preset_label = QLabel("(none)")
        self.out_label = QLabel("(none)")
        for label in (self.dlc_label, self.preset_label, self.out_label):
            label.setWordWrap(True)

        self.dlc_button = QPushButton("DLC csv...")
        self.preset_button = QPushButton("Preset .mat...")
        self.out_button = QPushButton("Output dir...")

        self.paradigm_box = QComboBox()
        self.paradigm_box.addItems(sorted(PARADIGMS))
        if self.state.paradigm in PARADIGMS:
            self.paradigm_box.setCurrentText(self.state.paradigm)

        self.end_frame_box = QSpinBox()
        self.end_frame_box.setRange(0, 10_000_000)
        self.end_frame_box.setSpecialValueText("all")
        self.heatmap_bin_box = QDoubleSpinBox()
        self.heatmap_bin_box.setRange(0.5, 50.0)
        self.heatmap_bin_box.setValue(self.state.heatmap_bin_cm)

        self.run_button = QPushButton("Run analyze")
        self.status_label = QLabel("Ready.")
        self.status_label.setWordWrap(True)
        self.warnings = WarningsPanel()

        paths = QGroupBox("Session")
        paths_form = QFormLayout(paths)
        paths_form.addRow(self.dlc_button, self.dlc_label)
        paths_form.addRow(self.preset_button, self.preset_label)
        paths_form.addRow(self.out_button, self.out_label)

        options = QGroupBox("Options")
        options_form = QFormLayout(options)
        options_form.addRow("Paradigm", self.paradigm_box)
        options_form.addRow("Last frame", self.end_frame_box)
        options_form.addRow("Heatmap bin, cm", self.heatmap_bin_box)

        left = QWidget()
        left_layout = QVBoxLayout(left)
        left_layout.addWidget(paths)
        left_layout.addWidget(options)
        left_layout.addWidget(self.run_button)
        left_layout.addWidget(self.status_label)
        left_layout.addWidget(self.warnings, 1)

        self.plots = PlotGrid()
        self.acts_table = QTableWidget(0, len(_ACT_COLUMNS))
        self.acts_table.setHorizontalHeaderLabels(list(_ACT_COLUMNS))
        self.metrics_table = QTableWidget(0, 2)
        self.metrics_table.setHorizontalHeaderLabels(["Metric", "Value"])

        tables = QWidget()
        tables_layout = QHBoxLayout(tables)
        tables_layout.addWidget(self.acts_table, 2)
        tables_layout.addWidget(self.metrics_table, 1)

        right = QSplitter(Qt.Vertical)
        right.addWidget(self.plots)
        right.addWidget(tables)
        right.setSizes([600, 260])

        splitter = QSplitter(Qt.Horizontal)
        splitter.addWidget(left)
        splitter.addWidget(right)
        splitter.setSizes([330, 950])

        layout = QVBoxLayout(self)
        layout.addWidget(splitter)

    def _connect(self) -> None:
        self.dlc_button.clicked.connect(self._pick_dlc)
        self.preset_button.clicked.connect(self._pick_preset)
        self.out_button.clicked.connect(self._pick_out_dir)
        self.paradigm_box.currentTextChanged.connect(self._on_paradigm)
        self.end_frame_box.valueChanged.connect(self._on_end_frame)
        self.heatmap_bin_box.valueChanged.connect(self._on_heatmap_bin)
        self.run_button.clicked.connect(self.controller.run)
        self.state.paths_changed.connect(self._refresh_paths)

    # --- slots ---
    def _pick_dlc(self) -> None:
        path, _ = QFileDialog.getOpenFileName(self, "Choose DLC csv", "",
                                              "CSV files (*.csv)")
        if path:
            self.state.dlc_path = path

    def _pick_preset(self) -> None:
        path, _ = QFileDialog.getOpenFileName(self, "Choose preset", "",
                                              "MAT files (*.mat)")
        if path:
            self.state.preset_path = path

    def _pick_out_dir(self) -> None:
        path = QFileDialog.getExistingDirectory(self, "Choose output directory")
        if path:
            self.state.out_dir = path

    def _on_paradigm(self, name: str) -> None:
        self.state.paradigm = name

    def _on_end_frame(self, value: int) -> None:
        self.state.end_frame = int(value)

    def _on_heatmap_bin(self, value: float) -> None:
        self.state.heatmap_bin_cm = float(value)

    def _refresh_paths(self) -> None:
        self.dlc_label.setText(self.state.dlc_path or "(none)")
        self.preset_label.setText(self.state.preset_path or "(none)")
        self.out_label.setText(self.state.out_dir or "(none)")

    # --- controller callbacks ---
    def set_status(self, text: str) -> None:
        self.status_label.setText(text)

    def set_busy(self, busy: bool) -> None:
        self.run_button.setEnabled(not busy)

    def show_result(self, result) -> None:
        self.warnings.show_result(result)
        self.plots.show_result(result, heatmap_bin_cm=self.state.heatmap_bin_cm)
        self._fill_acts(result)
        self._fill_metrics(result)

    def _fill_acts(self, result) -> None:
        acts = [a for a in (getattr(result, "acts", []) or []) if a.stats is not None]
        self.acts_table.setRowCount(len(acts))
        for row, act in enumerate(acts):
            stats = act.stats
            values = (act.name, _format(stats.percent), _format(stats.count),
                      _format(stats.duration_s), _format(stats.distance_cm),
                      _format(stats.mean_velocity))
            for column, value in enumerate(values):
                self.acts_table.setItem(row, column, QTableWidgetItem(value))

    def _fill_metrics(self, result) -> None:
        metrics = getattr(result, "metrics", None)
        rows = []
        if metrics is not None:
            rows.extend((name, _format(value))
                        for name, value in metrics.values.items())
            # A metric that could not be computed is a result too, not a blank.
            rows.extend((name, f"error: {message}")
                        for name, message in metrics.errors.items())
        self.metrics_table.setRowCount(len(rows))
        for row, (name, value) in enumerate(rows):
            self.metrics_table.setItem(row, 0, QTableWidgetItem(name))
            self.metrics_table.setItem(row, 1, QTableWidgetItem(value))
```
- [ ] **Step 5: Run tests to verify they pass**

Run: `PYTHONPATH=src python -m pytest tests/gui/test_analyze_tab.py -q`
Expected: PASS (8 passed)

- [ ] **Step 6: Commit**
```bash
git add src/sphynx_gui/analyze_tab.py src/sphynx_gui/analyze_controller.py tests/gui/test_analyze_tab.py
git commit -m "feat(gui): S4a -- Analyze tab and controller"
```

---

### Task 8: end-to-end check on the demo session

**Files:** Test `tests/integration/test_analyze_with_paradigm.py`.
**Interfaces:** Consumes `analyze_session(config, paradigm=...)`.

- [ ] **Step 1: Write the failing test** — `tests/integration/test_analyze_with_paradigm.py`:
```python
"""S4a acceptance: the paradigm path runs on the real demo session."""

from pathlib import Path

import pytest

from sphynx.config import Config
from sphynx.paradigms import PARADIGMS, register_builtin_paradigms
from sphynx.pipeline import analyze_session

_ROOT = Path(__file__).resolve().parents[2]
_DLC = _ROOT / "Demo/DLC/NOF_H01_1DDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv"
_PRESET = _ROOT / "Demo/Preset/NOF_H01_1D_Preset.mat"

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
    config.frames.end_frame = 2000
    config.verbose = "warn"
    return config


def test_open_field_validates_clean(_config):
    result = analyze_session(_config, paradigm="OF")
    assert result.paradigm == "OF"
    assert result.validation is not None
    assert result.validation.ok is True          # the preset carries pxl2sm


def test_builtin_acts_still_computed_with_a_paradigm(_config):
    result = analyze_session(_config, paradigm="OF")
    names = [a.name for a in result.acts]
    for expected in ("rest", "walk", "locomotion", "freezing"):
        assert expected in names


def test_nor_reports_missing_objects_instead_of_lying(_config):
    result = analyze_session(_config, paradigm="NOR")
    assert result.validation.ok is False
    assert "needs_object" in [i.code for i in result.validation.errors]


def test_without_a_paradigm_nothing_changes(_config):
    result = analyze_session(_config)
    assert result.paradigm == ""
    assert result.validation is None
    assert result.metrics is None
```
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/integration/test_analyze_with_paradigm.py -q`
Expected: FAIL until Task 1 is implemented; after Task 1 it should PASS.

- [ ] **Step 3: Run the full suite**

Run: `PYTHONPATH=src python -m pytest -q`
Expected: PASS, no regressions.

- [ ] **Step 4: Launch the app once by hand**

Run: `PYTHONPATH=src python -m sphynx_gui.app`
Expected: a window with six tabs opens, Analyze Session selected.

- [ ] **Step 5: Commit**
```bash
git add tests/integration/test_analyze_with_paradigm.py
git commit -m "test(python): S4a acceptance -- paradigm path on the demo session"
```

---

## Task order

Dispatch: **1, 2, 3, 5, 6, 7, 4, 8.** Task 4's window imports `AnalyzeTab`, so Task 7 lands
first; Task 8 closes the slice with the demo-session acceptance run.

## Done criteria
- `PYTHONPATH=src python -m pytest -q` green (535 + new).
- `python -m sphynx_gui.app` opens a six-tab window; Analyze Session runs the demo session
  in the background and fills plots, both tables and the warnings panel.
- Choosing NOR on the demo preset shows a validation error rather than silent numbers.
- `sphynx` still imports without Qt (enforced by test).
