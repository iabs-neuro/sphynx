# S4c — Project + Batch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A project that holds sessions, their metadata and preset-assignment rules, and a
Batch tab that runs the whole project without one bad session killing the rest.

**Architecture:** The project model, its file, the folder scan, the rule resolution and the
resilient runner all live in the engine, so a project is scriptable; the tab is a table over
it. Spec: `docs/superpowers/specs/2026-08-01-S4c-project-batch-design.md`.

**Tech Stack:** Python 3.11+, PySide6, pandas; pytest, pytest-qt.

## Global Constraints
- Python at repo ROOT; commands from root with `PYTHONPATH=src`.
- `sphynx` must not import Qt (a test enforces it).
- No silent fallbacks (§10): a session with no preset does NOT run and is marked; a name the
  pattern cannot parse is marked, never guessed; every preset assignment records where it
  came from; a failing session is recorded with its message, not skipped.
- Unknown JSON fields and schema versions raise (reuse `sphynx.io.jsonio`).
- ASCII only, including UI strings. TDD: failing test first.

## File Structure
- Create `src/sphynx/project/__init__.py`, `model.py`, `io.py`, `scan.py`, `presets.py`.
- Modify `src/sphynx/pipeline/batch.py` — progress, per-session errors, paradigm/library.
- Create `src/sphynx_gui/sessions_table.py`, `src/sphynx_gui/batch_tab.py`,
  `src/sphynx_gui/batch_controller.py`.
- Modify `src/sphynx_gui/state.py`, `src/sphynx_gui/main_window.py`.

---

### Task 1: project model and file

**Files:** Create `src/sphynx/project/__init__.py`, `src/sphynx/project/model.py`, `src/sphynx/project/io.py`; Test `tests/unit/test_project_io.py`.
**Interfaces:**
- `ProjectSession(name, dlc_path="", preset_path="", metadata: dict = {})`.
- `PresetRule(preset_path, match: dict = {})`.
- `Project(name="", sessions=[], preset_rules=[], paradigm="OF", library_path="", out_dir="", name_pattern=DEFAULT_PATTERN)`.
- `project_to_dict`, `project_from_dict`, `save_project(project, path) -> str`,
  `load_project(path) -> Project`, `SCHEMA_VERSION = 1`.
- `DEFAULT_PATTERN = r"^(?P<exp>[^_]+)_(?P<mouse>[^_]+)_(?P<session>.+)$"`.

- [ ] **Step 1: Write the failing test** — `tests/unit/test_project_io.py`:
```python
import pytest

from sphynx.exceptions import SphynxIOError, SphynxValueError
from sphynx.project import (
    PresetRule, Project, ProjectSession, load_project, project_from_dict,
    project_to_dict, save_project,
)


def _project():
    return Project(
        name="NOF pilot",
        sessions=[
            ProjectSession(name="NOF_H01_1D", dlc_path="a.csv",
                           metadata={"mouse": "H01", "day": "1D"}),
            ProjectSession(name="NOF_H01_2D", dlc_path="b.csv",
                           preset_path="manual.mat",
                           metadata={"mouse": "H01", "day": "2D"}),
        ],
        preset_rules=[PresetRule("all.mat"), PresetRule("day3.mat", {"day": "3D"})],
        paradigm="EOF", library_path="acts.json", out_dir="out",
    )


def test_dict_round_trip():
    back = project_from_dict(project_to_dict(_project()))
    assert back.name == "NOF pilot"
    assert [s.name for s in back.sessions] == ["NOF_H01_1D", "NOF_H01_2D"]
    assert back.sessions[1].preset_path == "manual.mat"
    assert back.sessions[0].metadata == {"mouse": "H01", "day": "1D"}
    assert [r.preset_path for r in back.preset_rules] == ["all.mat", "day3.mat"]
    assert back.preset_rules[1].match == {"day": "3D"}
    assert back.paradigm == "EOF"
    assert back.library_path == "acts.json"
    assert back.out_dir == "out"


def test_file_round_trip(tmp_path):
    path = tmp_path / "nested" / "project.json"
    save_project(_project(), path)
    assert path.is_file()
    assert load_project(path).name == "NOF pilot"


def test_unknown_top_level_field_raises():
    data = project_to_dict(_project())
    data["sesions"] = data.pop("sessions")
    with pytest.raises(SphynxValueError):
        project_from_dict(data)


def test_unknown_session_field_raises():
    data = project_to_dict(_project())
    data["sessions"][0]["dlc_pth"] = "typo.csv"
    with pytest.raises(SphynxValueError):
        project_from_dict(data)


def test_missing_schema_version_raises():
    data = project_to_dict(_project())
    del data["schema_version"]
    with pytest.raises(SphynxValueError):
        project_from_dict(data)


def test_unknown_schema_version_raises():
    data = project_to_dict(_project())
    data["schema_version"] = 99
    with pytest.raises(SphynxValueError):
        project_from_dict(data)


def test_missing_file_raises():
    with pytest.raises(SphynxIOError):
        load_project("no_such_project.json")


def test_empty_project_round_trips():
    back = project_from_dict(project_to_dict(Project()))
    assert back.sessions == []
    assert back.preset_rules == []
    assert back.paradigm == "OF"
```
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_project_io.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'sphynx.project'`

- [ ] **Step 3: Write the model.** Create `src/sphynx/project/model.py`:
```python
"""Project model (S4c).

A project references its data rather than copying it: DLC files and presets stay
where they are and the project stores paths. A path that no longer resolves is a
visible state of the row, not a silent skip.
"""

from __future__ import annotations

from dataclasses import dataclass, field

DEFAULT_PATTERN = r"^(?P<exp>[^_]+)_(?P<mouse>[^_]+)_(?P<session>.+)$"


@dataclass
class ProjectSession:
    name: str = ""
    dlc_path: str = ""
    preset_path: str = ""          # set by hand; overrides every rule
    metadata: dict = field(default_factory=dict)


@dataclass
class PresetRule:
    """A preset plus the metadata it applies to. An empty match means all
    sessions; several fields are ANDed."""

    preset_path: str = ""
    match: dict = field(default_factory=dict)


@dataclass
class Project:
    name: str = ""
    sessions: list = field(default_factory=list)        # ProjectSession
    preset_rules: list = field(default_factory=list)    # PresetRule
    paradigm: str = "OF"
    library_path: str = ""
    out_dir: str = ""
    name_pattern: str = DEFAULT_PATTERN
```
- [ ] **Step 4: Write the codec.** Create `src/sphynx/project/io.py`:
```python
"""Save/load a project as JSON (S4c)."""

from __future__ import annotations

from dataclasses import asdict

from sphynx.exceptions import SphynxValueError
from sphynx.io.jsonio import check_keys, from_fields, read_json, write_json
from sphynx.project.model import DEFAULT_PATTERN, PresetRule, Project, ProjectSession

SCHEMA_VERSION = 1

_TOP_LEVEL = {"schema_version", "name", "sessions", "preset_rules", "paradigm",
              "library_path", "out_dir", "name_pattern"}


def project_to_dict(project: Project) -> dict:
    return {
        "schema_version": SCHEMA_VERSION,
        "name": project.name,
        "sessions": [asdict(s) for s in project.sessions],
        "preset_rules": [asdict(r) for r in project.preset_rules],
        "paradigm": project.paradigm,
        "library_path": project.library_path,
        "out_dir": project.out_dir,
        "name_pattern": project.name_pattern,
    }


def project_from_dict(data: dict) -> Project:
    check_keys(data, _TOP_LEVEL, "project")
    if "schema_version" not in data:
        raise SphynxValueError("project has no schema_version")
    if data["schema_version"] != SCHEMA_VERSION:
        raise SphynxValueError(
            f"unsupported project schema version {data['schema_version']}; "
            f"this build reads version {SCHEMA_VERSION}")
    return Project(
        name=data.get("name", ""),
        sessions=[from_fields(ProjectSession, s, "project session")
                  for s in data.get("sessions", [])],
        preset_rules=[from_fields(PresetRule, r, "preset rule")
                      for r in data.get("preset_rules", [])],
        paradigm=data.get("paradigm", "OF"),
        library_path=data.get("library_path", ""),
        out_dir=data.get("out_dir", ""),
        name_pattern=data.get("name_pattern", DEFAULT_PATTERN),
    )


def save_project(project: Project, path) -> str:
    return write_json(project_to_dict(project), path)


def load_project(path) -> Project:
    return project_from_dict(read_json(path))
```
- [ ] **Step 5: Package init.** Create `src/sphynx/project/__init__.py`:
```python
"""Project: sessions, metadata, preset rules (S4c)."""

from sphynx.project.io import (
    SCHEMA_VERSION,
    load_project,
    project_from_dict,
    project_to_dict,
    save_project,
)
from sphynx.project.model import (
    DEFAULT_PATTERN,
    PresetRule,
    Project,
    ProjectSession,
)

__all__ = [
    "Project", "ProjectSession", "PresetRule", "DEFAULT_PATTERN",
    "project_to_dict", "project_from_dict", "save_project", "load_project",
    "SCHEMA_VERSION",
]
```
- [ ] **Step 6: Run tests to verify they pass**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_project_io.py -q`
Expected: PASS (8 passed). Then the full suite.

- [ ] **Step 7: Commit**
```bash
git add src/sphynx/project tests/unit/test_project_io.py
git commit -m "feat(python): S4c -- project model and JSON codec"
```

---

### Task 2: folder scan and name parsing

**Files:** Create `src/sphynx/project/scan.py`; Modify `src/sphynx/project/__init__.py`; Test `tests/unit/test_project_scan.py`.
**Interfaces:**
- `parse_session_name(name, pattern) -> dict` — the named groups, or `{}` when the pattern
  does not match.
- `scan_folder(root, pattern=DEFAULT_PATTERN, existing=None) -> list[ProjectSession]` —
  finds `*.csv` recursively, keeps sessions already in `existing` untouched, and returns the
  merged list in a stable order.
- `session_is_parsed(session) -> bool`.

- [ ] **Step 1: Write the failing test** — `tests/unit/test_project_scan.py`:
```python
import pytest

from sphynx.exceptions import SphynxIOError
from sphynx.project import DEFAULT_PATTERN, ProjectSession
from sphynx.project.scan import parse_session_name, scan_folder, session_is_parsed


def _make(root, *names):
    for name in names:
        (root / name).write_text("x", encoding="utf-8")
    return root


def test_parses_the_default_pattern():
    got = parse_session_name("NOF_H01_1D", DEFAULT_PATTERN)
    assert got == {"exp": "NOF", "mouse": "H01", "session": "1D"}


def test_unparsed_name_returns_empty():
    assert parse_session_name("whatever", DEFAULT_PATTERN) == {}


def test_scan_finds_csv_files(tmp_path):
    _make(tmp_path, "NOF_H01_1D.csv", "NOF_H01_2D.csv")
    sessions = scan_folder(tmp_path)
    assert [s.name for s in sessions] == ["NOF_H01_1D", "NOF_H01_2D"]
    assert all(s.dlc_path for s in sessions)


def test_scan_is_recursive(tmp_path):
    nested = tmp_path / "day1"
    nested.mkdir()
    _make(nested, "NOF_H01_1D.csv")
    assert [s.name for s in scan_folder(tmp_path)] == ["NOF_H01_1D"]


def test_metadata_comes_from_the_name(tmp_path):
    _make(tmp_path, "NOF_H01_1D.csv")
    session = scan_folder(tmp_path)[0]
    assert session.metadata["mouse"] == "H01"
    assert session.metadata["session"] == "1D"
    assert session_is_parsed(session) is True


def test_unparsed_name_is_marked_not_guessed(tmp_path):
    _make(tmp_path, "randomfile.csv")
    session = scan_folder(tmp_path)[0]
    assert session.metadata == {}
    assert session_is_parsed(session) is False


def test_rescan_keeps_edited_sessions(tmp_path):
    _make(tmp_path, "NOF_H01_1D.csv")
    edited = ProjectSession(name="NOF_H01_1D", dlc_path="old.csv",
                            preset_path="chosen.mat",
                            metadata={"mouse": "H01", "group": "control"})
    sessions = scan_folder(tmp_path, existing=[edited])
    assert len(sessions) == 1
    assert sessions[0].preset_path == "chosen.mat"
    assert sessions[0].metadata["group"] == "control"


def test_rescan_adds_new_files(tmp_path):
    _make(tmp_path, "NOF_H01_1D.csv", "NOF_H01_2D.csv")
    existing = [ProjectSession(name="NOF_H01_1D", dlc_path="old.csv")]
    sessions = scan_folder(tmp_path, existing=existing)
    assert [s.name for s in sessions] == ["NOF_H01_1D", "NOF_H01_2D"]


def test_missing_folder_raises(tmp_path):
    with pytest.raises(SphynxIOError):
        scan_folder(tmp_path / "nope")


def test_bad_pattern_raises(tmp_path):
    _make(tmp_path, "NOF_H01_1D.csv")
    with pytest.raises(SphynxIOError):
        scan_folder(tmp_path, pattern="([unclosed")
```
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_project_scan.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'sphynx.project.scan'`

- [ ] **Step 3: Write the implementation.** Create `src/sphynx/project/scan.py`:
```python
"""Find sessions in a folder and read what their names state (S4c).

A name the pattern does not match is MARKED, never guessed at: the row keeps
empty metadata and the caller fills it in. Rescanning adds new files and leaves
sessions already in the project alone, so hand-edited metadata survives.
"""

from __future__ import annotations

import re
from pathlib import Path

from sphynx.exceptions import SphynxIOError
from sphynx.project.model import DEFAULT_PATTERN, ProjectSession


def parse_session_name(name, pattern) -> dict:
    """Named groups the pattern finds in `name`, or {} when it does not match."""
    try:
        match = re.match(pattern, str(name))
    except re.error as e:
        raise SphynxIOError(f"invalid session-name pattern: {e}") from e
    return {k: v for k, v in (match.groupdict().items() if match else [])
            if v is not None}


def session_is_parsed(session) -> bool:
    return bool(session.metadata)


def scan_folder(root, pattern: str = DEFAULT_PATTERN, existing=None) -> list:
    """Sessions for every csv under `root`, merged with the ones already known."""
    folder = Path(root)
    if not folder.is_dir():
        raise SphynxIOError(f"folder not found: {folder}")
    try:
        re.compile(pattern)
    except re.error as e:
        raise SphynxIOError(f"invalid session-name pattern: {e}") from e

    known = {s.name: s for s in (existing or [])}
    order = [s.name for s in (existing or [])]

    for path in sorted(folder.rglob("*.csv")):
        name = path.stem
        if name in known:
            continue          # already in the project, possibly hand-edited
        known[name] = ProjectSession(
            name=name, dlc_path=str(path),
            metadata=parse_session_name(name, pattern))
        order.append(name)

    return [known[name] for name in order]
```
- [ ] **Step 4: Export.** In `src/sphynx/project/__init__.py` add
  `from sphynx.project.scan import parse_session_name, scan_folder, session_is_parsed`
  and those three names to `__all__`.
- [ ] **Step 5: Run tests to verify they pass**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_project_scan.py -q`
Expected: PASS (10 passed). Then the full suite.

- [ ] **Step 6: Commit**
```bash
git add src/sphynx/project/scan.py src/sphynx/project/__init__.py tests/unit/test_project_scan.py
git commit -m "feat(python): S4c -- folder scan with name parsing"
```

---

### Task 3: preset assignment by rules

**Files:** Create `src/sphynx/project/presets.py`; Modify `src/sphynx/project/__init__.py`; Test `tests/unit/test_project_presets.py`.
**Interfaces:**
- `PresetAssignment(preset_path, source)` — `source` is `"manual"`, `"rule: day=3D"` or
  `"unassigned"`.
- `resolve_preset(session, rules) -> PresetAssignment`.
- `assign_presets(project) -> dict[str, PresetAssignment]` keyed by session name.
- `runnable_sessions(project) -> tuple[list, list]` — `(ready, blocked)`; a session is
  blocked when it has no preset or no dlc path.

- [ ] **Step 1: Write the failing test** — `tests/unit/test_project_presets.py`:
```python
from sphynx.project import PresetRule, Project, ProjectSession
from sphynx.project.presets import (
    assign_presets, resolve_preset, runnable_sessions,
)


def _session(name, **metadata):
    return ProjectSession(name=name, dlc_path=f"{name}.csv", metadata=metadata)


def test_no_rules_means_unassigned():
    got = resolve_preset(_session("s", day="1D"), [])
    assert got.preset_path == ""
    assert got.source == "unassigned"


def test_empty_match_applies_to_every_session():
    got = resolve_preset(_session("s", day="1D"), [PresetRule("all.mat")])
    assert got.preset_path == "all.mat"
    assert got.source == "rule: all sessions"


def test_rule_matches_on_metadata():
    rules = [PresetRule("all.mat"), PresetRule("day3.mat", {"day": "3D"})]
    assert resolve_preset(_session("s", day="3D"), rules).preset_path == "day3.mat"
    assert resolve_preset(_session("s", day="1D"), rules).preset_path == "all.mat"


def test_the_last_matching_rule_wins():
    rules = [PresetRule("first.mat", {"day": "1D"}),
             PresetRule("second.mat", {"day": "1D"})]
    assert resolve_preset(_session("s", day="1D"), rules).preset_path == "second.mat"


def test_several_fields_are_anded():
    rules = [PresetRule("both.mat", {"day": "1D", "group": "control"})]
    assert resolve_preset(_session("a", day="1D", group="control"),
                          rules).preset_path == "both.mat"
    assert resolve_preset(_session("b", day="1D", group="test"),
                          rules).source == "unassigned"


def test_the_source_names_the_rule():
    rules = [PresetRule("day3.mat", {"day": "3D"})]
    assert resolve_preset(_session("s", day="3D"), rules).source == "rule: day=3D"


def test_manual_path_overrides_every_rule():
    session = _session("s", day="3D")
    session.preset_path = "mine.mat"
    got = resolve_preset(session, [PresetRule("day3.mat", {"day": "3D"})])
    assert got.preset_path == "mine.mat"
    assert got.source == "manual"


def test_assign_presets_covers_every_session():
    project = Project(sessions=[_session("a", day="1D"), _session("b", day="3D")],
                      preset_rules=[PresetRule("all.mat")])
    assigned = assign_presets(project)
    assert set(assigned) == {"a", "b"}
    assert assigned["b"].preset_path == "all.mat"


def test_sessions_without_a_preset_are_blocked_not_run():
    project = Project(sessions=[_session("a"), _session("b")],
                      preset_rules=[PresetRule("all.mat", {"day": "1D"})])
    ready, blocked = runnable_sessions(project)
    assert [s.name for s, _ in ready] == []
    assert [s.name for s, _ in blocked] == ["a", "b"]


def test_ready_sessions_carry_their_assignment():
    project = Project(sessions=[_session("a", day="1D")],
                      preset_rules=[PresetRule("all.mat")])
    ready, blocked = runnable_sessions(project)
    assert blocked == []
    session, assignment = ready[0]
    assert session.name == "a"
    assert assignment.preset_path == "all.mat"


def test_a_session_without_a_dlc_path_is_blocked():
    session = ProjectSession(name="a", metadata={"day": "1D"})
    project = Project(sessions=[session], preset_rules=[PresetRule("all.mat")])
    ready, blocked = runnable_sessions(project)
    assert ready == []
    assert blocked[0][1] == "no DLC file"
```
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_project_presets.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'sphynx.project.presets'`

- [ ] **Step 3: Write the implementation.** Create `src/sphynx/project/presets.py`:
```python
"""Assign a preset to each session by declarative rules (S4c).

One spatial layout often covers a whole experiment, but the design can depend on
the day or the group, so a preset is chosen by matching metadata rather than
typed per row. Every assignment carries WHERE it came from: an assignment nobody
can see is the silent substitution section 10 forbids.
"""

from __future__ import annotations

from dataclasses import dataclass

UNASSIGNED = "unassigned"
MANUAL = "manual"


@dataclass
class PresetAssignment:
    preset_path: str = ""
    source: str = UNASSIGNED


def _describe(rule) -> str:
    if not rule.match:
        return "rule: all sessions"
    return "rule: " + ", ".join(f"{k}={v}" for k, v in sorted(rule.match.items()))


def _matches(session, rule) -> bool:
    return all(str(session.metadata.get(key, "")) == str(value)
               for key, value in rule.match.items())


def resolve_preset(session, rules) -> PresetAssignment:
    """A hand-typed path wins; otherwise the LAST matching rule does, so a
    general rule can be written first and refined by the ones below it."""
    if session.preset_path:
        return PresetAssignment(session.preset_path, MANUAL)
    chosen = None
    for rule in rules or []:
        if _matches(session, rule):
            chosen = rule
    if chosen is None:
        return PresetAssignment("", UNASSIGNED)
    return PresetAssignment(chosen.preset_path, _describe(chosen))


def assign_presets(project) -> dict:
    return {s.name: resolve_preset(s, project.preset_rules)
            for s in project.sessions}


def runnable_sessions(project):
    """Split the project into (ready, blocked).

    Blocked sessions are NOT run with some stand-in preset -- they are returned
    with the reason so the table can show it."""
    ready, blocked = [], []
    for session in project.sessions:
        assignment = resolve_preset(session, project.preset_rules)
        if not session.dlc_path:
            blocked.append((session, "no DLC file"))
        elif not assignment.preset_path:
            blocked.append((session, "no preset assigned"))
        else:
            ready.append((session, assignment))
    return ready, blocked
```
- [ ] **Step 4: Export.** In `src/sphynx/project/__init__.py` add
  `from sphynx.project.presets import (PresetAssignment, assign_presets, resolve_preset, runnable_sessions)`
  and those four names to `__all__`.
- [ ] **Step 5: Run tests to verify they pass**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_project_presets.py -q`
Expected: PASS (11 passed). Then the full suite.

- [ ] **Step 6: Commit**
```bash
git add src/sphynx/project/presets.py src/sphynx/project/__init__.py tests/unit/test_project_presets.py
git commit -m "feat(python): S4c -- preset assignment by rules"
```

---

### Task 4: a batch that survives a failing session

**Files:** Modify `src/sphynx/pipeline/batch.py`; Create `src/sphynx/project/run.py`; Modify `src/sphynx/project/__init__.py`; Test `tests/unit/test_batch_resilience.py`.
**Interfaces:**
- `BatchResult` gains `errors: dict` (session name -> message).
- `run_batch(specs, config=None, out_dir="", preloaded=None, paradigm=None, library=None, on_progress=None, continue_on_error=False) -> BatchResult`;
  `on_progress(index, total, session_name)` is called before each session.
- `project_specs(project) -> tuple[list, list]` — `(specs, blocked)`.
- `run_project(project, config=None, on_progress=None, should_stop=None) -> BatchResult`.

- [ ] **Step 1: Write the failing test** — `tests/unit/test_batch_resilience.py`:
```python
import numpy as np
import pytest

import sphynx.pipeline.batch as batch_module
from sphynx.acts.stats import act_stats
from sphynx.exceptions import SphynxIOError
from sphynx.pipeline.analyze import SessionAct
from sphynx.pipeline.batch import run_batch
from sphynx.project import PresetRule, Project, ProjectSession
from sphynx.project.run import project_specs, run_project


class _Res:
    def __init__(self):
        mask = np.ones(10)
        self.acts = [SessionAct("rest", mask, "builtin", act_stats(mask, 10.0))]


def _specs():
    return [{"session_name": "a", "dlc_path": "a.csv", "preset_path": "p.mat",
             "mouse": "A", "trial": "1D"},
            {"session_name": "b", "dlc_path": "b.csv", "preset_path": "p.mat",
             "mouse": "B", "trial": "1D"}]


def test_a_failing_session_does_not_kill_the_batch(monkeypatch):
    def flaky(config, paradigm=None, library=None):
        if config.paths.dlc == "a.csv":
            raise SphynxIOError("DLC csv not found: a.csv")
        return _Res()

    monkeypatch.setattr(batch_module, "analyze_session", flaky)
    out = run_batch(_specs(), continue_on_error=True)
    assert "a" in out.errors
    assert "a.csv" in out.errors["a"]
    assert len(out.results) == 1            # b still computed
    assert not out.tidy.empty


def test_without_continue_on_error_the_failure_propagates(monkeypatch):
    def flaky(config, paradigm=None, library=None):
        raise SphynxIOError("boom")

    monkeypatch.setattr(batch_module, "analyze_session", flaky)
    with pytest.raises(SphynxIOError):
        run_batch(_specs())


def test_progress_is_reported_per_session(monkeypatch):
    monkeypatch.setattr(batch_module, "analyze_session",
                        lambda config, paradigm=None, library=None: _Res())
    seen = []
    run_batch(_specs(), on_progress=lambda i, n, name: seen.append((i, n, name)))
    assert seen == [(1, 2, "a"), (2, 2, "b")]


def test_paradigm_and_library_reach_the_engine(monkeypatch):
    seen = {}

    def capture(config, paradigm=None, library=None):
        seen["paradigm"] = paradigm
        seen["library"] = library
        return _Res()

    monkeypatch.setattr(batch_module, "analyze_session", capture)
    run_batch(_specs()[:1], paradigm="EOF", library="LIB")
    assert seen == {"paradigm": "EOF", "library": "LIB"}


def test_project_specs_skips_blocked_sessions():
    project = Project(
        sessions=[ProjectSession(name="a", dlc_path="a.csv",
                                 metadata={"mouse": "A", "day": "1D"}),
                  ProjectSession(name="b", dlc_path="")],
        preset_rules=[PresetRule("all.mat")])
    specs, blocked = project_specs(project)
    assert [s["session_name"] for s in specs] == ["a"]
    assert specs[0]["preset_path"] == "all.mat"
    assert [s.name for s, _ in blocked] == ["b"]


def test_project_specs_carry_metadata():
    project = Project(
        sessions=[ProjectSession(name="a", dlc_path="a.csv",
                                 metadata={"mouse": "A", "group": "ctrl",
                                           "session": "1D"})],
        preset_rules=[PresetRule("all.mat")])
    spec = project_specs(project)[0][0]
    assert spec["mouse"] == "A"
    assert spec["group"] == "ctrl"
    assert spec["trial"] == "1D"


def test_run_project_stops_when_asked(monkeypatch):
    monkeypatch.setattr(batch_module, "analyze_session",
                        lambda config, paradigm=None, library=None: _Res())
    project = Project(
        sessions=[ProjectSession(name=n, dlc_path=f"{n}.csv",
                                 metadata={"mouse": n}) for n in "abc"],
        preset_rules=[PresetRule("all.mat")])
    out = run_project(project, should_stop=lambda: True)
    assert out.results == []
```
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_batch_resilience.py -q`
Expected: FAIL with `TypeError: run_batch() got an unexpected keyword argument 'continue_on_error'`

- [ ] **Step 3: Make the batch resilient.** In `src/sphynx/pipeline/batch.py`, add
  `errors: dict = field(default_factory=dict)` to `BatchResult` (importing `field` from
  dataclasses), and replace `run_batch` with:
```python
def run_batch(specs, config: Config | None = None, out_dir: str = "", preloaded=None,
              paradigm=None, library=None, on_progress=None,
              continue_on_error: bool = False) -> BatchResult:
    """Run every spec through analyze_session (or use `preloaded`) and aggregate.

    `specs` is a list of dicts. Recognised keys: session_name (required),
    dlc_path, preset_path, mouse, group, line, trial. With
    `continue_on_error` a session that fails is RECORDED in `errors` and the
    rest of the batch proceeds -- one unreadable file should not cost a
    twelve-session run."""
    n = len(specs)
    errors: dict = {}
    if preloaded is not None:
        if len(preloaded) != n:
            raise SphynxValueError(
                f"preloaded length {len(preloaded)} != specs length {n}"
            )
        results = list(preloaded)
        kept_specs = list(specs)
    else:
        results = []
        kept_specs = []
        base = config if config is not None else Config.default()
        for k, spec in enumerate(specs):
            name = str(_spec_get(spec, "session_name"))
            if on_progress is not None:
                on_progress(k + 1, n, name)
            cfg = copy.deepcopy(base)
            cfg.paths.dlc = _spec_get(spec, "dlc_path")
            cfg.paths.preset = _spec_get(spec, "preset_path")
            if out_dir:
                cfg.paths.out_dir = out_dir
                cfg.io.save_workspace = True
                cfg.io.session_name = name
            else:
                cfg.io.save_workspace = False
            _log.info("Batch %d/%d: %s", k + 1, n, name)
            try:
                results.append(analyze_session(cfg, paradigm=paradigm,
                                               library=library))
            except SphynxError as e:
                if not continue_on_error:
                    raise
                errors[name] = str(e)
                _log.warning("Session %s failed: %s", name, e)
                continue
            kept_specs.append(spec)

    tidy = _build_tidy(kept_specs, results)
    wide = _tidy_to_wide(tidy)
    return BatchResult(results=results, tidy=tidy, wide=wide, errors=errors)
```
  and add `from sphynx.exceptions import SphynxError, SphynxValueError` (replacing the
  existing exceptions import).
- [ ] **Step 4: Write the project runner.** Create `src/sphynx/project/run.py`:
```python
"""Turn a project into batch specs and run it (S4c)."""

from __future__ import annotations

from sphynx.pipeline.batch import BatchResult, run_batch
from sphynx.project.presets import runnable_sessions


def project_specs(project):
    """(specs, blocked). Blocked sessions never reach the engine."""
    ready, blocked = runnable_sessions(project)
    specs = []
    for session, assignment in ready:
        metadata = session.metadata or {}
        specs.append({
            "session_name": session.name,
            "dlc_path": session.dlc_path,
            "preset_path": assignment.preset_path,
            "mouse": metadata.get("mouse", ""),
            "group": metadata.get("group", ""),
            "line": metadata.get("line", ""),
            "trial": metadata.get("trial", metadata.get("session", "")),
        })
    return specs, blocked


def run_project(project, config=None, on_progress=None,
                should_stop=None) -> BatchResult:
    """Run every ready session. A failing session is recorded, not fatal."""
    specs, _blocked = project_specs(project)
    if should_stop is not None:
        wanted = []
        for spec in specs:
            if should_stop():
                break
            wanted.append(spec)
        specs = wanted
    return run_batch(
        specs, config=config, out_dir=project.out_dir or "",
        paradigm=project.paradigm or None, on_progress=on_progress,
        continue_on_error=True)
```
- [ ] **Step 5: Export.** In `src/sphynx/project/__init__.py` add
  `from sphynx.project.run import project_specs, run_project` and both names to `__all__`.
- [ ] **Step 6: Run tests to verify they pass**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_batch_resilience.py -q`
Expected: PASS (7 passed). Then the full suite -- the existing `tests/unit/test_run_batch.py`
must still pass unchanged.

- [ ] **Step 7: Commit**
```bash
git add src/sphynx/pipeline/batch.py src/sphynx/project tests/unit/test_batch_resilience.py
git commit -m "feat(python): S4c -- resilient batch and project runner"
```

---

### Task 5: sessions table widget

**Files:** Create `src/sphynx_gui/sessions_table.py`; Modify `src/sphynx_gui/state.py`; Test `tests/gui/test_sessions_table.py`.
**Interfaces:**
- `AppState` gains `project` (a `Project`) and signal `project_changed`.
- `SessionsTable(parent=None)` (QTableWidget subclass or wrapper) with `.show_project(project)`,
  `.selected_names() -> list[str]`, `.rows` (list of dicts with `name`, `preset`, `source`,
  `status`), and columns Session / Mouse / Group / Line / Day / Preset / From / Status.
- Editing a metadata cell writes back through `.apply_edits(project)`.

- [ ] **Step 1: Write the failing test** — `tests/gui/test_sessions_table.py` covering: the
  table shows a row per session with metadata columns; the preset column shows the resolved
  path and the From column its source (`rule: day=3D` / `manual` / `unassigned`); a session
  with no preset shows a blocked status; editing a metadata cell and calling `apply_edits`
  updates the project; `selected_names` returns the highlighted rows.
- [ ] **Step 2: Run tests to verify they fail**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests to verify they pass**, then the full suite.
- [ ] **Step 5: Commit**
```bash
git add src/sphynx_gui/sessions_table.py src/sphynx_gui/state.py tests/gui/test_sessions_table.py
git commit -m "feat(gui): S4c -- sessions table with preset provenance"
```

---

### Task 6: Batch tab and controller

**Files:** Create `src/sphynx_gui/batch_tab.py`, `src/sphynx_gui/batch_controller.py`; Test `tests/gui/test_batch_tab.py`.
**Interfaces:**
- `BatchTab(state)` with `.table`, `.scan_button`, `.run_button`, `.cancel_button`,
  `.progress_label`, `.warnings`, `.results_table`, `.controller`,
  `.new_project_button`, `.open_button`, `.save_button`, `.assign_preset_button`.
- `BatchController(state, tab)` with `.scan(folder)`, `.assign_preset_to_selected(path)`,
  `.run()`, `.cancel()`, `.on_finished(batch_result)`, `.on_failed(message)`,
  `.open_project(path)`, `.save_project(path)`.

> **NOTE for the controller:** this task wires the project, the rules and the threaded run
> together. Build it in the main loop, not via a transcribing implementer.

- [ ] **Step 1: Write the failing test** — `tests/gui/test_batch_tab.py` covering: scanning a
  temp folder fills the project and the table; assigning a preset to the selected rows adds
  a manual path; running with no ready session reports it instead of starting; a finished
  batch fills the results table and shows per-session errors in the warnings panel; cancel
  sets the stop flag; save and open round-trip the project through a file.
- [ ] **Step 2: Run tests to verify they fail**
- [ ] **Step 3: Implement**, reusing the worker pattern from `analyze_controller` (QThread,
  re-entrancy guard, `shutdown()` waited on by the window).
- [ ] **Step 4: Run tests to verify they pass**, then the full suite.
- [ ] **Step 5: Commit**
```bash
git add src/sphynx_gui/batch_tab.py src/sphynx_gui/batch_controller.py tests/gui/test_batch_tab.py
git commit -m "feat(gui): S4c -- Batch tab"
```

---

### Task 7: make the tab live and check the slice end to end

**Files:** Modify `src/sphynx_gui/main_window.py`; Test `tests/gui/test_main_window.py` (append), `tests/integration/test_project_on_demo.py`.
**Interfaces:** `MainWindow.batch_tab` is a `BatchTab`; `closeEvent` also waits on its
controller.

- [ ] **Step 1: Write the failing tests** — append to `tests/gui/test_main_window.py` that
  `window.batch_tab` is a `BatchTab` and only three placeholders remain; and
  `tests/integration/test_project_on_demo.py` that scans `Demo/DLC`, assigns
  `Demo/Preset_v2/NOF_H01_1D_Preset_v2.mat` by a rule with an empty match, runs the project
  with `end_frame` capped, and asserts every NOF session either produced a result or is
  recorded in `errors` -- nothing vanishes silently.
- [ ] **Step 2: Run tests to verify they fail**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests to verify they pass**, then the full suite.
- [ ] **Step 5: Launch the app by hand**

Run: `PYTHONPATH=src python -m sphynx_gui.app`
Expected: Batch Analysis is live; scanning `Demo/DLC`, adding one preset rule and pressing
Run analyses the NOF sessions with a progress readout.

- [ ] **Step 6: Commit**
```bash
git add -A src/sphynx_gui tests
git commit -m "feat(gui): S4c -- Batch tab live, project runs end to end"
```

---

## Task order
Dispatch 1, 2, 3, 4, 5, 6, 7 in order.

## Done criteria
- `PYTHONPATH=src python -m pytest -q` green (679 + new).
- A project scans a folder, keeps hand-edited metadata across rescans, assigns presets by
  rule with the source visible, and refuses to run a session that has none.
- The four demo NOF sessions run from one button; a session with a broken path is recorded
  in `errors` while the others complete.
