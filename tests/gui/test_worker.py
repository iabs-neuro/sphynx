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
