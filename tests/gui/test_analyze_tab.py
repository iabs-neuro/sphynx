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
