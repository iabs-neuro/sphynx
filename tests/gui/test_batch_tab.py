"""Batch tab: scan, assign presets, run, report (S4c)."""

import numpy as np
import pandas as pd
import pytest

import sphynx.pipeline.batch as batch_module
from sphynx.acts.stats import act_stats
from sphynx.paradigms import PARADIGMS, register_builtin_paradigms
from sphynx.pipeline.analyze import SessionAct
from sphynx.pipeline.batch import BatchResult
from sphynx.project import PresetRule, Project, ProjectSession, save_project
from sphynx_gui.batch_tab import BatchTab
from sphynx_gui.state import AppState


@pytest.fixture(autouse=True)
def _builtins():
    saved = dict(PARADIGMS)
    PARADIGMS.clear()
    register_builtin_paradigms()
    yield
    PARADIGMS.clear()
    PARADIGMS.update(saved)


class _Res:
    def __init__(self):
        mask = np.ones(10)
        self.acts = [SessionAct("rest", mask, "builtin", act_stats(mask, 10.0))]
        self.validation = None
        self.degraded = {}
        self.metrics = None


def _tab(qtbot, project=None):
    state = AppState()
    if project is not None:
        state.project = project
    tab = BatchTab(state)
    qtbot.addWidget(tab)
    return tab


def _folder(tmp_path, *names):
    for name in names:
        (tmp_path / name).write_text("x", encoding="utf-8")
    return tmp_path


# --- project handling ------------------------------------------------------

def test_scan_fills_the_project_and_the_table(qtbot, tmp_path):
    _folder(tmp_path, "NOF_H01_1D.csv", "NOF_H01_2D.csv")
    tab = _tab(qtbot)
    tab.controller.scan(tmp_path)
    assert [s.name for s in tab.state.project.sessions] == [
        "NOF_H01_1D", "NOF_H01_2D"]
    assert tab.table.rowCount() == 2


def test_scan_of_a_missing_folder_reports(qtbot, tmp_path):
    tab = _tab(qtbot)
    tab.controller.scan(tmp_path / "nope")
    assert "scan failed" in tab.status_label.text().lower()


def test_status_counts_ready_and_blocked(qtbot, tmp_path):
    _folder(tmp_path, "NOF_H01_1D.csv")
    tab = _tab(qtbot)
    tab.controller.scan(tmp_path)
    assert "0 session(s) ready" in tab.status_label.text()
    assert "1 blocked" in tab.status_label.text()


def test_a_rule_for_all_sessions_makes_them_ready(qtbot, tmp_path):
    _folder(tmp_path, "NOF_H01_1D.csv")
    tab = _tab(qtbot)
    tab.controller.scan(tmp_path)
    tab.controller.add_preset_rule("all.mat", {})
    assert "1 session(s) ready" in tab.status_label.text()
    assert tab.table.rows[0]["source"] == "rule: all sessions"


def test_assigning_a_preset_to_selected_rows(qtbot, tmp_path):
    _folder(tmp_path, "NOF_H01_1D.csv", "NOF_H01_2D.csv")
    tab = _tab(qtbot)
    tab.controller.scan(tmp_path)
    tab.table.selectRow(1)
    tab.controller.assign_preset_to_selected("chosen.mat")
    assert tab.state.project.sessions[1].preset_path == "chosen.mat"
    assert tab.state.project.sessions[0].preset_path == ""
    assert tab.table.rows[1]["source"] == "manual"


def test_assigning_with_no_selection_reports(qtbot, tmp_path):
    _folder(tmp_path, "NOF_H01_1D.csv")
    tab = _tab(qtbot)
    tab.controller.scan(tmp_path)
    tab.table.clearSelection()
    tab.controller.assign_preset_to_selected("chosen.mat")
    assert "select the rows" in tab.status_label.text().lower()


def test_save_and_open_round_trip(qtbot, tmp_path):
    project = Project(
        sessions=[ProjectSession(name="a", dlc_path="a.csv",
                                 metadata={"mouse": "A"})],
        preset_rules=[PresetRule("all.mat")])
    tab = _tab(qtbot, project)
    path = tmp_path / "project.json"
    tab.controller.save_project(path)

    other = _tab(qtbot)
    other.controller.open_project(path)
    assert [s.name for s in other.state.project.sessions] == ["a"]


def test_opening_a_missing_project_reports(qtbot, tmp_path):
    tab = _tab(qtbot)
    tab.controller.open_project(tmp_path / "nope.json")
    assert "could not open" in tab.status_label.text().lower()


def test_opening_a_project_adopts_its_paradigm(qtbot, tmp_path):
    path = tmp_path / "p.json"
    save_project(Project(paradigm="Barnes"), path)
    tab = _tab(qtbot)
    tab.controller.open_project(path)
    assert tab.state.paradigm == "Barnes"


# --- running ---------------------------------------------------------------

def test_run_with_nothing_ready_reports_the_reason(qtbot, tmp_path):
    _folder(tmp_path, "NOF_H01_1D.csv")
    tab = _tab(qtbot)
    tab.controller.scan(tmp_path)
    tab.controller.run()
    assert "nothing to run" in tab.status_label.text().lower()
    assert "no preset" in tab.status_label.text().lower()


def test_finished_batch_fills_the_results_table(qtbot):
    tab = _tab(qtbot)
    tidy = pd.DataFrame({"session_name": ["a", "a"], "value": [1.0, 2.0]})
    batch = BatchResult(results=[_Res()], tidy=tidy, wide=pd.DataFrame(),
                        session_names=["a"])
    tab.controller.on_finished(batch)
    assert tab.results_table.rowCount() == 1
    assert tab.results_table.item(0, 0).text() == "a"
    assert tab.results_table.item(0, 1).text() == "done"


def test_failed_sessions_are_listed_in_the_warnings(qtbot):
    tab = _tab(qtbot)
    batch = BatchResult(results=[], tidy=pd.DataFrame(), wide=pd.DataFrame(),
                        errors={"b": "DLC csv not found: b.csv"})
    tab.controller.on_finished(batch)
    assert any("b.csv" in text for _s, _l, text in tab.warnings.rows)
    assert "1 failed" in tab.status_label.text()


def test_a_failed_session_still_gets_a_row(qtbot):
    tab = _tab(qtbot)
    batch = BatchResult(results=[], tidy=pd.DataFrame(), wide=pd.DataFrame(),
                        errors={"b": "boom"})
    tab.controller.on_finished(batch)
    assert tab.results_table.rowCount() == 1
    assert "error" in tab.results_table.item(0, 1).text()


def test_cancel_sets_the_stop_flag(qtbot):
    from sphynx_gui.batch_controller import BatchWorker

    tab = _tab(qtbot)
    tab.controller._worker = BatchWorker(Project())
    tab.controller.cancel()
    assert tab.controller._worker._stop is True


def test_a_second_run_while_busy_is_refused(qtbot):
    tab = _tab(qtbot)

    class _Thread:
        def isRunning(self):
            return True

    tab.controller._thread = _Thread()
    tab.controller.run()
    assert "already running" in tab.status_label.text().lower()


def test_worker_runs_the_project_and_reports_progress(qtbot, monkeypatch):
    from sphynx_gui.batch_controller import BatchWorker

    monkeypatch.setattr(batch_module, "analyze_session",
                        lambda config, paradigm=None, library=None: _Res())
    project = Project(
        sessions=[ProjectSession(name=n, dlc_path=f"{n}.csv",
                                 metadata={"mouse": n}) for n in ("a", "b")],
        preset_rules=[PresetRule("all.mat")])
    worker = BatchWorker(project)
    seen = []
    worker.progress.connect(lambda i, n, name: seen.append(name))
    with qtbot.waitSignal(worker.finished, timeout=2000) as blocker:
        worker.run()
    assert seen == ["a", "b"]
    assert len(blocker.args[0].results) == 2


def test_worker_reports_a_bug_instead_of_dying(qtbot, monkeypatch):
    from sphynx_gui.batch_controller import BatchWorker
    import sphynx_gui.batch_controller as controller_module

    def boom(*_args, **_kwargs):
        raise ZeroDivisionError("bad maths")

    monkeypatch.setattr(controller_module, "run_project", boom)
    worker = BatchWorker(Project())
    with qtbot.waitSignal(worker.failed, timeout=2000) as blocker:
        worker.run()
    assert "ZeroDivisionError" in blocker.args[0]


# --- S4c review regressions ---

def test_a_session_with_no_acts_still_gets_its_own_row(qtbot):
    # C2: names were derived from the tidy table, so a session contributing no
    # tidy rows vanished and every later row showed the previous result.
    class _Empty:
        acts = []
        validation = None
        degraded = {}
        metrics = None

    tab = _tab(qtbot)
    batch = BatchResult(results=[_Empty(), _Res()], tidy=pd.DataFrame(),
                        wide=pd.DataFrame(), session_names=["quiet", "loud"])
    tab.controller.on_finished(batch)
    assert [tab.results_table.item(r, 0).text() for r in range(2)] ==         ["quiet", "loud"]
    assert tab.results_table.item(0, 2).text() == "0"
    assert tab.results_table.item(1, 2).text() == "1"


def test_a_failure_keeps_the_sessions_that_finished(qtbot):
    # I4: on_failed used to clear the table, discarding completed work.
    tab = _tab(qtbot)
    tidy = pd.DataFrame({"session_name": ["a"], "value": [1.0]})
    tab.controller.on_finished(BatchResult(results=[_Res()], tidy=tidy,
                                           wide=pd.DataFrame(),
                                           session_names=["a"]))
    tab.controller.on_failed("something broke")
    assert tab.results_table.rowCount() == 1
    assert "something broke" in tab.status_label.text()


def test_the_batch_runs_the_paradigm_shown_in_the_app(qtbot, tmp_path):
    # I5: the batch used the project's saved paradigm while Analyze used the
    # dropdown, so the two silently diverged.
    real = tmp_path / "NOF_H01_1D.csv"
    real.write_text("x", encoding="utf-8")
    project = Project(
        sessions=[ProjectSession(name="NOF_H01_1D", dlc_path=str(real),
                                 metadata={"mouse": "H01"})],
        preset_rules=[PresetRule("all.mat")], paradigm="OF")
    tab = _tab(qtbot, project)
    tab.state.paradigm = "Barnes"

    class _Thread:
        def isRunning(self):
            return False

    tab.controller._thread = _Thread()
    tab.controller.run()
    assert tab.state.project.paradigm == "Barnes"
    tab.controller.shutdown()
