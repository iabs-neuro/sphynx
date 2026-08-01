"""Make Output tab: column choice, previews, export (S4c2)."""

import numpy as np
import pandas as pd
import pytest
from PySide6.QtCore import Qt

from sphynx.acts.stats import act_stats
from sphynx.metrics.registry import MetricResults
from sphynx.pipeline.analyze import SessionAct
from sphynx.pipeline.batch import run_batch
from sphynx_gui.output_tab import OutputTab
from sphynx_gui.state import AppState


class _Res:
    def __init__(self):
        rest = np.zeros(10)
        rest[2:6] = 1
        walk = np.zeros(10)
        walk[6:9] = 1
        self.acts = [SessionAct("rest", rest, "builtin", act_stats(rest, 10.0)),
                     SessionAct("walk", walk, "builtin", act_stats(walk, 10.0))]
        self.metrics = MetricResults(values={"path_length": 120.0,
                                             "mean_speed": 3.0},
                                     errors={"primary_errors": "no target"})


def _batch():
    specs = [{"session_name": "a", "mouse": "A", "trial": "1D"}]
    return run_batch(specs, preloaded=[_Res()])


def _tab(qtbot, with_batch=True):
    state = AppState()
    tab = OutputTab(state)
    qtbot.addWidget(tab)
    if with_batch:
        state.batch = _batch()
    return tab


def _tick(widget, name):
    for i in range(widget.count()):
        if widget.item(i).text() == name:
            widget.item(i).setCheckState(Qt.Checked)
            return
    raise AssertionError(f"{name} not offered")


# --- the offered columns ---------------------------------------------------

def test_without_a_batch_the_tab_says_so(qtbot):
    tab = _tab(qtbot, with_batch=False)
    assert "run a batch" in tab.status_label.text().lower()
    assert tab.acts_list.count() == 0


def test_lists_fill_from_the_run(qtbot):
    tab = _tab(qtbot)
    acts = [tab.acts_list.item(i).text() for i in range(tab.acts_list.count())]
    assert acts == ["rest", "walk"]
    metrics = [tab.metrics_list.item(i).text()
               for i in range(tab.metrics_list.count())]
    assert "path_length" in metrics
    assert "primary_errors" in metrics      # the failed one is offered too


def test_act_statistics_are_offered(qtbot):
    tab = _tab(qtbot)
    stats = [tab.stats_list.item(i).text() for i in range(tab.stats_list.count())]
    assert "ActPercent" in stats and "ActDuration" in stats


# --- the column count ------------------------------------------------------

def test_nothing_ticked_means_everything_and_says_so(qtbot):
    tab = _tab(qtbot)
    assert "nothing ticked means everything" in tab.count_label.text()


def test_ticking_an_act_narrows_the_count(qtbot):
    tab = _tab(qtbot)
    before = int(tab.count_label.text().split()[0])
    _tick(tab.acts_list, "rest")
    after = int(tab.count_label.text().split()[0])
    assert after < before


def test_the_count_names_the_total(qtbot):
    tab = _tab(qtbot)
    assert "available" in tab.count_label.text()


# --- previews --------------------------------------------------------------

def test_both_previews_are_filled(qtbot):
    tab = _tab(qtbot)
    assert tab.tidy_preview.rowCount() > 0
    assert tab.wide_preview.rowCount() > 0


def test_the_preview_shows_the_error_text(qtbot):
    tab = _tab(qtbot)
    columns = [tab.tidy_preview.horizontalHeaderItem(c).text()
               for c in range(tab.tidy_preview.columnCount())]
    error_column = columns.index("error")
    texts = [tab.tidy_preview.item(r, error_column).text()
             for r in range(tab.tidy_preview.rowCount())]
    assert any("no target" in t for t in texts)


def test_narrowing_the_acts_keeps_the_named_metrics(qtbot):
    tab = _tab(qtbot)
    _tick(tab.acts_list, "rest")
    columns = [tab.tidy_preview.horizontalHeaderItem(c).text()
               for c in range(tab.tidy_preview.columnCount())]
    kind = columns.index("metric_kind")
    kinds = {tab.tidy_preview.item(r, kind).text()
             for r in range(tab.tidy_preview.rowCount())}
    assert "named" in kinds


# --- export ----------------------------------------------------------------

def test_csv_export_writes_both_files(qtbot, tmp_path):
    tab = _tab(qtbot)
    tab.controller.export(tmp_path / "out.csv", "csv")
    assert (tmp_path / "out_tidy.csv").is_file()
    assert (tmp_path / "out_wide.csv").is_file()
    assert "written" in tab.status_label.text().lower()


def test_export_without_a_batch_reports(qtbot, tmp_path):
    tab = _tab(qtbot, with_batch=False)
    tab.controller.export(tmp_path / "out.csv", "csv")
    assert "nothing to export" in tab.status_label.text().lower()


def test_export_respects_the_ticks(qtbot, tmp_path):
    tab = _tab(qtbot)
    _tick(tab.acts_list, "rest")
    tab.controller.export(tmp_path / "out.csv", "csv")
    text = (tmp_path / "out_tidy.csv").read_text(encoding="utf-8")
    assert "rest" in text
    assert ",walk," not in text


def test_a_bad_format_is_reported_not_raised(qtbot, tmp_path):
    tab = _tab(qtbot)
    tab.controller.export(tmp_path / "out.xyz", "xyz")
    assert "export failed" in tab.status_label.text().lower()


# --- the selection is remembered ------------------------------------------

def test_the_ticks_are_stored_on_the_project(qtbot):
    tab = _tab(qtbot)
    _tick(tab.acts_list, "walk")
    assert tab.state.project.output_selection["acts"] == ["walk"]


def test_stored_ticks_are_restored(qtbot):
    state = AppState()
    state.project.output_selection = {"acts": ["walk"], "act_stats": [],
                                      "named_metrics": []}
    tab = OutputTab(state)
    qtbot.addWidget(tab)
    state.batch = _batch()
    checked = tab.checked_names()
    assert checked["acts"] == ["walk"]
