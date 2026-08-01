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
