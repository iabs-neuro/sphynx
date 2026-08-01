"""S4c acceptance: a project over the real demo folder runs end to end."""

from pathlib import Path

import pytest

from sphynx.config import Config
from sphynx.paradigms import PARADIGMS, register_builtin_paradigms
from sphynx.project import PresetRule, Project, ProjectSession
from sphynx.project.presets import runnable_sessions
from sphynx.project.run import run_project
from sphynx.project.scan import scan_folder

_ROOT = Path(__file__).resolve().parents[2]
_DLC_DIR = _ROOT / "Demo/DLC"
_PRESET = _ROOT / "Demo/Preset_v2/NOF_H01_1D_Preset_v2.mat"

pytestmark = pytest.mark.skipif(
    not (_DLC_DIR.is_dir() and _PRESET.is_file()),
    reason="Demo data not present",
)


@pytest.fixture(autouse=True)
def _builtins():
    saved = dict(PARADIGMS)
    PARADIGMS.clear()
    register_builtin_paradigms()
    yield
    PARADIGMS.clear()
    PARADIGMS.update(saved)


def _project():
    sessions = [s for s in scan_folder(_DLC_DIR) if s.name.startswith("NOF_H01")]
    return Project(name="demo", sessions=sessions,
                   preset_rules=[PresetRule(str(_PRESET))], paradigm="EOF")


def _config():
    config = Config.default()
    config.io.save_workspace = False
    config.frames.end_frame = 600          # keep the acceptance run quick
    config.verbose = "error"
    return config


def test_scan_finds_the_demo_sessions():
    project = _project()
    assert len(project.sessions) >= 3
    assert all(s.metadata.get("mouse") == "H01" for s in project.sessions)


def test_one_rule_makes_every_session_ready():
    ready, blocked = runnable_sessions(_project())
    assert blocked == []
    assert all(a.preset_path == str(_PRESET) for _s, a in ready)


def test_the_batch_runs_and_accounts_for_every_session():
    project = _project()
    batch = run_project(project, config=_config())
    accounted = len(batch.results) + len(batch.errors)
    assert accounted == len(project.sessions)      # nothing vanishes silently
    assert not batch.tidy.empty


def test_a_broken_path_is_recorded_and_the_rest_still_run():
    project = _project()
    project.sessions.append(ProjectSession(
        name="broken", dlc_path=str(_DLC_DIR / "does_not_exist.csv"),
        metadata={"mouse": "H01", "session": "9D"}))
    batch = run_project(project, config=_config())
    assert "broken" in batch.errors
    assert len(batch.results) >= 3                 # the real sessions completed


def test_the_paradigm_reaches_every_session():
    batch = run_project(_project(), config=_config())
    assert all(r.paradigm == "EOF" for r in batch.results)
