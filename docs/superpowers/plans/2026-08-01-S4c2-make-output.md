# S4c2 — Make Output Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Named paradigm metrics reach the output tables, columns can be selected, and both
tables export to CSV or Excel.

**Architecture:** The tidy builder gains a second row source and a `metric_kind` column; the
selection is data on the project; the tab is a preview plus export. Spec:
`docs/superpowers/specs/2026-08-01-S4c2-make-output-design.md`.

**Tech Stack:** Python 3.11+, PySide6, pandas; pytest, pytest-qt.

## Global Constraints
- Python at repo ROOT; commands from root with `PYTHONPATH=src`.
- `sphynx` must not import Qt.
- No silent fallbacks (§10): a metric that failed exports as NaN WITH its error text; a
  non-numeric metric value is exported as it is, never dropped; an empty selection means
  everything and says so; an unavailable Excel writer is reported, never downgraded to CSV
  behind the user's back.
- Backward compatibility: the existing tidy columns keep their names and meaning; the
  current `tests/unit/test_run_batch.py` and `test_batch_resilience.py` must pass unchanged.
- ASCII only, including UI strings. TDD: failing test first.

## File Structure
- Modify `src/sphynx/pipeline/batch.py` — named-metric rows, `metric_kind`, `error`.
- Create `src/sphynx/pipeline/output.py` — selection, filtering, wide pivot, export.
- Modify `src/sphynx/project/model.py` + `io.py` — `output_selection`.
- Create `src/sphynx_gui/output_tab.py`, `src/sphynx_gui/output_controller.py`.
- Modify `src/sphynx_gui/main_window.py`, `src/sphynx_gui/state.py`.

---

### Task 1: named metrics reach the tidy table

**Files:** Modify `src/sphynx/pipeline/batch.py`; Test `tests/unit/test_tidy_named_metrics.py`.
**Interfaces:**
- Tidy columns become `session_name, mouse, group, line, trial, metric_kind, act_name, metric, value, error`.
- `metric_kind` is `"act_stat"` for act statistics and `"named"` for paradigm metrics.
- A failed metric contributes a row with `value = NaN` and `error` set.
- A non-numeric metric value is kept as-is in `value`.

- [ ] **Step 1: Write the failing test** — `tests/unit/test_tidy_named_metrics.py`:
```python
import math

import numpy as np
import pandas as pd

from sphynx.acts.stats import act_stats
from sphynx.metrics.registry import MetricResults
from sphynx.pipeline.analyze import SessionAct
from sphynx.pipeline.batch import run_batch


class _Res:
    def __init__(self, metrics=None):
        mask = np.zeros(10)
        mask[2:6] = 1
        self.acts = [SessionAct("rest", mask, "builtin", act_stats(mask, 10.0))]
        self.metrics = metrics


def _spec(name="a"):
    return {"session_name": name, "mouse": "A", "trial": "1D"}


def _tidy(metrics):
    return run_batch([_spec()], preloaded=[_Res(metrics)]).tidy


def test_act_statistics_are_still_there():
    tidy = _tidy(None)
    acts = tidy[tidy["metric_kind"] == "act_stat"]
    assert set(acts["metric"]) >= {"ActPercent", "ActNumber", "ActDuration"}
    assert (acts["act_name"] == "rest").all()


def test_named_metrics_get_their_own_rows():
    tidy = _tidy(MetricResults(values={"path_length": 12.5, "mean_speed": 3.0}))
    named = tidy[tidy["metric_kind"] == "named"]
    assert set(named["metric"]) == {"path_length", "mean_speed"}
    assert float(named[named["metric"] == "path_length"]["value"].iloc[0]) == 12.5


def test_a_failed_metric_exports_as_nan_with_its_reason():
    tidy = _tidy(MetricResults(values={}, errors={"primary_errors": "no target"}))
    row = tidy[tidy["metric"] == "primary_errors"].iloc[0]
    assert math.isnan(float(row["value"]))
    assert "no target" in row["error"]
    assert row["metric_kind"] == "named"


def test_a_non_numeric_metric_value_survives():
    # visit_order is a list of holes and search_strategy a word; dropping them
    # would silently lose a result.
    tidy = _tidy(MetricResults(values={"search_strategy": "serial",
                                       "visit_order": ["h3", "h1"]}))
    values = dict(zip(tidy["metric"], tidy["value"]))
    assert values["search_strategy"] == "serial"
    assert values["visit_order"] == ["h3", "h1"]


def test_the_error_column_is_empty_for_a_good_row():
    tidy = _tidy(MetricResults(values={"path_length": 1.0}))
    assert (tidy["error"] == "").all()


def test_no_metrics_object_means_no_named_rows():
    tidy = _tidy(None)
    assert (tidy["metric_kind"] == "act_stat").all()


def test_the_columns_are_stable():
    tidy = _tidy(MetricResults(values={"path_length": 1.0}))
    assert list(tidy.columns) == [
        "session_name", "mouse", "group", "line", "trial",
        "metric_kind", "act_name", "metric", "value", "error"]


def test_named_rows_carry_the_session_metadata():
    tidy = _tidy(MetricResults(values={"path_length": 1.0}))
    row = tidy[tidy["metric_kind"] == "named"].iloc[0]
    assert row["mouse"] == "A"
    assert row["trial"] == "1D"
    assert row["act_name"] == ""
```
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_tidy_named_metrics.py -q`
Expected: FAIL with `KeyError: 'metric_kind'`

- [ ] **Step 3: Implement.** In `src/sphynx/pipeline/batch.py`, replace `_build_tidy` with:
```python
def _build_tidy(specs, results) -> pd.DataFrame:
    """One row per measurement.

    Two sources: the per-act statistics, and the paradigm's NAMED metrics --
    which reached no export at all before, so every Barnes metric was
    unexportable. A metric that could not be computed still gets a row, with
    NaN and the reason, because a blank cell cannot be told apart from a
    measured zero."""
    rows = []
    for spec, result in zip(specs, results):
        common = {
            "session_name": str(_spec_get(spec, "session_name")),
            "mouse": str(_spec_get(spec, "mouse")),
            "group": str(_spec_get(spec, "group")),
            "line": str(_spec_get(spec, "line")),
            "trial": str(_spec_get(spec, "trial")),
        }
        for act in result.acts:
            for label, attr in _METRIC_ATTR.items():
                value = getattr(act.stats, attr, None) if act.stats is not None else None
                rows.append({**common, "metric_kind": "act_stat",
                             "act_name": str(act.name), "metric": label,
                             "value": np.nan if value is None else value,
                             "error": ""})

        metrics = getattr(result, "metrics", None)
        if metrics is None:
            continue
        for name, value in getattr(metrics, "values", {}).items():
            rows.append({**common, "metric_kind": "named", "act_name": "",
                         "metric": str(name), "value": value, "error": ""})
        for name, message in getattr(metrics, "errors", {}).items():
            rows.append({**common, "metric_kind": "named", "act_name": "",
                         "metric": str(name), "value": np.nan,
                         "error": str(message)})

    return pd.DataFrame(rows, columns=[
        "session_name", "mouse", "group", "line", "trial",
        "metric_kind", "act_name", "metric", "value", "error",
    ])
```
  and in `_tidy_to_wide`, build the column key from the act name when there is one and the
  metric name alone otherwise, so the two kinds do not collide -- replace the `keys` lines
  with:
```python
    keys = tidy.apply(
        lambda r: (f"{r['act_name']}_{r['metric']}" if r["act_name"]
                   else str(r["metric"])), axis=1)
    if (tidy["trial"] != "").any():
        keys = keys + "_" + tidy["trial"]
```
- [ ] **Step 4: Run tests to verify they pass**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_tidy_named_metrics.py tests/unit/test_run_batch.py tests/unit/test_batch_resilience.py -q`
Expected: PASS (8 new; the 10 existing batch tests unchanged). Then the full suite.

- [ ] **Step 5: Commit**
```bash
git add src/sphynx/pipeline/batch.py tests/unit/test_tidy_named_metrics.py
git commit -m "feat(python): S4c2 -- named metrics reach the output tables"
```

---

### Task 2: selection, wide pivot and export

**Files:** Create `src/sphynx/pipeline/output.py`; Modify `src/sphynx/pipeline/__init__.py`; Test `tests/unit/test_output.py`.
**Interfaces:**
- `OutputSelection(acts=[], act_stats=[], named_metrics=[])` — an empty list means "all".
- `available_columns(tidy) -> dict` with keys `acts`, `act_stats`, `named_metrics`.
- `filter_tidy(tidy, selection) -> pd.DataFrame`.
- `wide_column_count(tidy, selection) -> int`.
- `export_tables(tidy, wide, path, fmt="csv") -> list[str]` — CSV writes two files
  (`<stem>_tidy.csv`, `<stem>_wide.csv`); `fmt="excel"` writes one workbook with two sheets
  and raises `SphynxIOError` naming `openpyxl` when no writer is available.

- [ ] **Step 1: Write the failing test** — `tests/unit/test_output.py`:
```python
import numpy as np
import pandas as pd
import pytest

from sphynx.exceptions import SphynxIOError
from sphynx.pipeline.output import (
    OutputSelection, available_columns, export_tables, filter_tidy,
    wide_column_count,
)


def _tidy():
    return pd.DataFrame([
        {"session_name": "a", "mouse": "A", "group": "", "line": "",
         "trial": "1D", "metric_kind": "act_stat", "act_name": "rest",
         "metric": "ActPercent", "value": 10.0, "error": ""},
        {"session_name": "a", "mouse": "A", "group": "", "line": "",
         "trial": "1D", "metric_kind": "act_stat", "act_name": "rest",
         "metric": "ActNumber", "value": 3, "error": ""},
        {"session_name": "a", "mouse": "A", "group": "", "line": "",
         "trial": "1D", "metric_kind": "act_stat", "act_name": "walk",
         "metric": "ActPercent", "value": 20.0, "error": ""},
        {"session_name": "a", "mouse": "A", "group": "", "line": "",
         "trial": "1D", "metric_kind": "named", "act_name": "",
         "metric": "path_length", "value": 120.0, "error": ""},
    ])


def test_available_columns_lists_what_the_run_produced():
    got = available_columns(_tidy())
    assert got["acts"] == ["rest", "walk"]
    assert got["act_stats"] == ["ActNumber", "ActPercent"]
    assert got["named_metrics"] == ["path_length"]


def test_an_empty_selection_means_everything():
    tidy = _tidy()
    assert len(filter_tidy(tidy, OutputSelection())) == len(tidy)


def test_selecting_acts_filters_rows():
    got = filter_tidy(_tidy(), OutputSelection(acts=["rest"]))
    assert set(got[got["metric_kind"] == "act_stat"]["act_name"]) == {"rest"}


def test_selecting_stats_filters_rows():
    got = filter_tidy(_tidy(), OutputSelection(act_stats=["ActPercent"]))
    stats = got[got["metric_kind"] == "act_stat"]
    assert set(stats["metric"]) == {"ActPercent"}


def test_selecting_named_metrics_filters_them():
    got = filter_tidy(_tidy(), OutputSelection(named_metrics=["nothing"]))
    assert got[got["metric_kind"] == "named"].empty


def test_act_selection_does_not_drop_named_metrics():
    # The three lists are independent: narrowing the acts must not silently
    # remove the paradigm metrics as well.
    got = filter_tidy(_tidy(), OutputSelection(acts=["rest"]))
    assert not got[got["metric_kind"] == "named"].empty


def test_wide_column_count_reflects_the_selection():
    tidy = _tidy()
    assert wide_column_count(tidy, OutputSelection()) == 4
    assert wide_column_count(tidy, OutputSelection(acts=["rest"])) == 3


def test_csv_export_writes_both_tables(tmp_path):
    written = export_tables(_tidy(), pd.DataFrame({"mouse": ["A"]}),
                            tmp_path / "out.csv")
    assert len(written) == 2
    assert (tmp_path / "out_tidy.csv").is_file()
    assert (tmp_path / "out_wide.csv").is_file()


def test_csv_export_keeps_the_error_column(tmp_path):
    tidy = _tidy()
    tidy.loc[0, "error"] = "no target"
    export_tables(tidy, pd.DataFrame(), tmp_path / "out.csv")
    text = (tmp_path / "out_tidy.csv").read_text(encoding="utf-8")
    assert "no target" in text


def test_unknown_format_raises(tmp_path):
    with pytest.raises(SphynxIOError):
        export_tables(_tidy(), pd.DataFrame(), tmp_path / "out.xyz", fmt="xyz")


def test_excel_without_a_writer_says_which_package(tmp_path, monkeypatch):
    import sphynx.pipeline.output as output_module

    monkeypatch.setattr(output_module, "_excel_writer_available",
                        lambda: False)
    with pytest.raises(SphynxIOError) as exc:
        export_tables(_tidy(), pd.DataFrame(), tmp_path / "out.xlsx",
                      fmt="excel")
    assert "openpyxl" in str(exc.value)
```
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_output.py -q`
Expected: FAIL with `ModuleNotFoundError: No module named 'sphynx.pipeline.output'`

- [ ] **Step 3: Write the implementation.** Create `src/sphynx/pipeline/output.py`:
```python
"""Choose what goes into the output tables and write them out (S4c2).

An empty selection list means EVERYTHING rather than nothing -- a fresh project
should export what it measured, not an empty file. The three lists are
independent, so narrowing the acts never removes the paradigm's named metrics.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import pandas as pd

from sphynx.exceptions import SphynxIOError

ACT_STAT, NAMED = "act_stat", "named"


@dataclass
class OutputSelection:
    acts: list = field(default_factory=list)            # empty = all
    act_stats: list = field(default_factory=list)       # empty = all
    named_metrics: list = field(default_factory=list)   # empty = all


def available_columns(tidy) -> dict:
    if tidy is None or tidy.empty:
        return {"acts": [], "act_stats": [], "named_metrics": []}
    stats = tidy[tidy["metric_kind"] == ACT_STAT]
    named = tidy[tidy["metric_kind"] == NAMED]
    return {
        "acts": sorted(set(stats["act_name"])),
        "act_stats": sorted(set(stats["metric"])),
        "named_metrics": sorted(set(named["metric"])),
    }


def filter_tidy(tidy, selection: OutputSelection):
    if tidy is None or tidy.empty:
        return tidy
    is_stat = tidy["metric_kind"] == ACT_STAT
    keep_stat = is_stat.copy()
    if selection.acts:
        keep_stat &= tidy["act_name"].isin(selection.acts)
    if selection.act_stats:
        keep_stat &= tidy["metric"].isin(selection.act_stats)

    keep_named = tidy["metric_kind"] == NAMED
    if selection.named_metrics:
        keep_named &= tidy["metric"].isin(selection.named_metrics)

    return tidy[keep_stat | keep_named].reset_index(drop=True)


def wide_column_count(tidy, selection: OutputSelection) -> int:
    """How many value columns the wide table would carry."""
    kept = filter_tidy(tidy, selection)
    if kept is None or kept.empty:
        return 0
    keys = kept.apply(
        lambda r: (f"{r['act_name']}_{r['metric']}" if r["act_name"]
                   else str(r["metric"])), axis=1)
    if (kept["trial"] != "").any():
        keys = keys + "_" + kept["trial"]
    return len(set(keys))


def _excel_writer_available() -> bool:
    try:
        import openpyxl  # noqa: F401
    except ImportError:
        return False
    return True


def export_tables(tidy, wide, path, fmt: str = "csv") -> list:
    """Write both tables. Returns the paths written."""
    target = Path(path)
    fmt = str(fmt).lower()
    if fmt not in ("csv", "excel"):
        raise SphynxIOError(f"unknown export format {fmt!r}; use csv or excel")

    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        if fmt == "csv":
            tidy_path = target.with_name(f"{target.stem}_tidy.csv")
            wide_path = target.with_name(f"{target.stem}_wide.csv")
            (tidy if tidy is not None else pd.DataFrame()).to_csv(
                tidy_path, index=False)
            (wide if wide is not None else pd.DataFrame()).to_csv(
                wide_path, index=False)
            return [str(tidy_path), str(wide_path)]

        if not _excel_writer_available():
            # Writing a CSV under an .xlsx name instead would be a quiet
            # substitution of one format for another.
            raise SphynxIOError(
                "writing Excel needs the openpyxl package; install it or "
                "export CSV instead")
        with pd.ExcelWriter(target) as writer:
            (tidy if tidy is not None else pd.DataFrame()).to_excel(
                writer, sheet_name="tidy", index=False)
            (wide if wide is not None else pd.DataFrame()).to_excel(
                writer, sheet_name="wide", index=False)
        return [str(target)]
    except OSError as e:
        raise SphynxIOError(f"cannot write {target}: {e}") from e
```
- [ ] **Step 4: Export.** In `src/sphynx/pipeline/__init__.py` add
  `from sphynx.pipeline.output import (OutputSelection, available_columns, export_tables, filter_tidy, wide_column_count)`
  and those five names to `__all__`.
- [ ] **Step 5: Run tests to verify they pass**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_output.py -q`
Expected: PASS (11 passed). Then the full suite.

- [ ] **Step 6: Commit**
```bash
git add src/sphynx/pipeline/output.py src/sphynx/pipeline/__init__.py tests/unit/test_output.py
git commit -m "feat(python): S4c2 -- output selection, column count and export"
```

---

### Task 3: remember the selection in the project

**Files:** Modify `src/sphynx/project/model.py`, `src/sphynx/project/io.py`; Test `tests/unit/test_project_io.py` (append).
**Interfaces:** `Project` gains `output_selection: dict` with keys `acts`, `act_stats`,
`named_metrics` (lists of names), round-tripping through JSON.

- [ ] **Step 1: Write the failing test** — append to `tests/unit/test_project_io.py`:
```python
def test_output_selection_round_trips():
    project = Project(output_selection={"acts": ["rest"],
                                        "act_stats": ["ActPercent"],
                                        "named_metrics": ["path_length"]})
    back = project_from_dict(project_to_dict(project))
    assert back.output_selection["acts"] == ["rest"]
    assert back.output_selection["named_metrics"] == ["path_length"]


def test_output_selection_defaults_to_empty():
    assert Project().output_selection == {}
    assert project_from_dict(project_to_dict(Project())).output_selection == {}
```
- [ ] **Step 2: Run test to verify it fails**

Run: `PYTHONPATH=src python -m pytest tests/unit/test_project_io.py -q`
Expected: FAIL with `TypeError: Project.__init__() got an unexpected keyword argument`

- [ ] **Step 3: Implement.** In `src/sphynx/project/model.py` add to `Project`:
```python
    # Which acts, act statistics and named metrics the export keeps; empty
    # lists (or an absent key) mean everything.
    output_selection: dict = field(default_factory=dict)
```
  and in `src/sphynx/project/io.py` add `"output_selection"` to `_TOP_LEVEL`, write it in
  `project_to_dict` as `dict(project.output_selection)`, and read it in
  `project_from_dict` as `output_selection=dict(data.get("output_selection", {}))`.
- [ ] **Step 4: Run tests to verify they pass**, then the full suite.
- [ ] **Step 5: Commit**
```bash
git add src/sphynx/project tests/unit/test_project_io.py
git commit -m "feat(python): S4c2 -- the project remembers its output selection"
```

---

### Task 4: Make Output tab

**Files:** Create `src/sphynx_gui/output_controller.py`, `src/sphynx_gui/output_tab.py`; Modify `src/sphynx_gui/state.py`; Test `tests/gui/test_output_tab.py`.
**Interfaces:**
- `AppState` gains `batch` (the last `BatchResult`) and signal `batch_changed`; the batch
  controller sets it in `on_finished`.
- `OutputTab(state)` with `.acts_list`, `.stats_list`, `.metrics_list` (QListWidget with
  checkboxes), `.count_label`, `.tidy_preview`, `.wide_preview`, `.export_csv_button`,
  `.export_excel_button`, `.status_label`, `.controller`.
- `OutputController(state, tab)` with `.refresh()`, `.selection() -> OutputSelection`,
  `.preview()`, `.export(path, fmt)`.

> **NOTE for the controller:** this task wires the batch result, the selection and the
> project together. Build it in the main loop, not via a transcribing implementer.

- [ ] **Step 1: Write the failing test** — `tests/gui/test_output_tab.py` covering: the three
  lists fill from the last batch; with no batch the tab says so instead of showing empty
  lists; ticking acts narrows the column count; the count label states the number; the
  previews show both tables; export writes files and reports the paths; export with nothing
  run reports it; the selection is stored on the project.
- [ ] **Step 2: Run tests to verify they fail**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests to verify they pass**, then the full suite.
- [ ] **Step 5: Commit**
```bash
git add src/sphynx_gui/output_tab.py src/sphynx_gui/output_controller.py src/sphynx_gui/state.py tests/gui/test_output_tab.py
git commit -m "feat(gui): S4c2 -- Make Output tab"
```

---

### Task 5: make the tab live and check the slice end to end

**Files:** Modify `src/sphynx_gui/main_window.py`, `src/sphynx_gui/batch_controller.py`; Test `tests/gui/test_main_window.py` (append), `tests/integration/test_output_on_demo.py`.
**Interfaces:** `MainWindow.output_tab` is an `OutputTab`; the batch controller publishes its
result to `state.batch`.

- [ ] **Step 1: Write the failing tests** — append to `tests/gui/test_main_window.py` that
  `window.output_tab` is an `OutputTab` and only two placeholders remain; and
  `tests/integration/test_output_on_demo.py` that runs a two-session demo project with the
  EOF paradigm and asserts the tidy table carries both `act_stat` and `named` rows, that
  `path_length` and `mean_speed` are present, that a CSV export writes two readable files,
  and that the wide table has one row per mouse.
- [ ] **Step 2: Run tests to verify they fail**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests to verify they pass**, then the full suite.
- [ ] **Step 5: Launch the app by hand**

Run: `PYTHONPATH=src python -m sphynx_gui.app`
Expected: after a batch run, Make Output lists the acts, statistics and metrics, the column
count responds to the ticks, and Export CSV writes both files.

- [ ] **Step 6: Commit**
```bash
git add -A src/sphynx_gui tests
git commit -m "feat(gui): S4c2 -- Make Output live, export end to end"
```

---

## Task order
Dispatch 1, 2, 3, 4, 5 in order.

## Done criteria
- `PYTHONPATH=src python -m pytest -q` green (757 + new).
- Named paradigm metrics appear in both tables and in the exported files.
- A failed metric exports as NaN with its reason rather than a blank cell.
- Ticking acts or statistics changes the column count the tab reports.
