"""A project holds real data, runs, moves, and re-opens (S4f).

The point of the slice in one test: build a project from the demo session,
batch it, check that a single tuning run stays out of the results, then rename
the whole folder and open it again.
"""

import shutil
from pathlib import Path

import pytest

from sphynx.config import Config
from sphynx.paradigms import register_builtin_paradigms
from sphynx.pipeline.analyze import analyze_session
from sphynx.project import PresetRule, load_project, save_project
from sphynx.project.model import folder
from sphynx.project.paths import is_external
from sphynx.project.run import batch_out_dir, project_specs, run_project
from sphynx_gui.project_tab import ProjectTab
from sphynx_gui.state import AppState

DLC = Path("Demo/DLC/NOF_H01_1DDLC_resnet152_MiceUniversal152Oct23shuffle1_"
           "1000000.csv")
PRESET = Path("Demo/Preset_v2/NOF_H01_1D_Preset_v2.mat")

pytestmark = pytest.mark.skipif(
    not (DLC.is_file() and PRESET.is_file()),
    reason="demo DLC csv or v2 preset absent")


@pytest.fixture(autouse=True)
def _paradigms():
    register_builtin_paradigms(replace=True)


def _project(qtbot, root):
    """A project holding the demo session, everything copied inside."""
    tab = ProjectTab(AppState())
    qtbot.addWidget(tab)
    tab.controller.new_project(root)
    tab.controller.set_paradigm("EOF")
    tab.controller.add_files([DLC], "tracking", copy=True)

    project = tab.state.project
    shutil.copy2(PRESET, Path(folder(project, "presets")) / PRESET.name)
    project.preset_rules = [PresetRule(preset_path=f"presets/{PRESET.name}")]
    tab.state.project = project
    tab.controller.save()
    return tab


def test_a_project_built_here_runs_a_batch(qtbot, tmp_path):
    tab = _project(qtbot, tmp_path / "MyExperiment")
    project = tab.state.project

    specs, blocked = project_specs(project)
    assert blocked == [], blocked
    assert len(specs) == 1
    # The engine only ever sees absolute paths, whatever the project stored.
    assert Path(specs[0]["dlc_path"]).is_file()
    assert Path(specs[0]["preset_path"]).is_file()

    config = Config.default()
    result = run_project(project, config=config)
    assert result.errors == {}, result.errors
    assert len(result.results) == 1
    assert not result.tidy.empty


def test_a_batch_and_a_tuning_run_are_aimed_at_different_folders(qtbot, tmp_path):
    # NOTE: nothing writes per-session files yet -- config.io.save_workspace
    # and config.paths.out_dir are carried through the engine and never acted
    # on, because analyzeSession.m step 12 (sphynx.io.saveSession) is not
    # ported. So this checks where the two runs are AIMED, which is the part
    # S4f owns; the writer is tracked in the MATLAB->Python inventory.
    tab = _project(qtbot, tmp_path / "MyExperiment")
    project = tab.state.project

    assert batch_out_dir(project) == folder(project, "behavior")
    assert tab.state.project_folder("temp") == folder(project, "temp")
    assert folder(project, "temp") != folder(project, "behavior")


def test_a_single_run_of_a_project_session_still_analyses(qtbot, tmp_path):
    tab = _project(qtbot, tmp_path / "MyExperiment")
    project = tab.state.project

    config = Config.default()
    config.paths.dlc = str(Path(project.root) / project.sessions[0].dlc_path)
    config.paths.preset = str(Path(project.root) / "presets" / PRESET.name)
    config.paths.out_dir = folder(project, "temp")
    config.io.save_workspace = False
    result = analyze_session(config, paradigm="EOF")
    assert result.n_frames > 0
    assert result.acts


def test_everything_the_project_names_is_inside_it(qtbot, tmp_path):
    tab = _project(qtbot, tmp_path / "MyExperiment")
    back = load_project(Path(tab.state.project.root) / "project.json")
    stored = ([s.dlc_path for s in back.sessions]
              + [r.preset_path for r in back.preset_rules])
    assert stored, "nothing was stored to check"
    assert not any(is_external(p) for p in stored), stored


def test_a_project_survives_having_its_folder_renamed(qtbot, tmp_path):
    tab = _project(qtbot, tmp_path / "MyExperiment")
    moved = tmp_path / "MyExperiment_2026"
    Path(tab.state.project.root).rename(moved)

    other = ProjectTab(AppState())
    qtbot.addWidget(other)
    other.controller.open_project(moved)
    assert other.state.project.root == str(moved.resolve())
    assert other.state.paradigm == "EOF"

    specs, blocked = project_specs(other.state.project)
    assert blocked == [], blocked
    assert Path(specs[0]["dlc_path"]).is_file(), \
        "the renamed project no longer finds its own tracking file"
    assert Path(specs[0]["preset_path"]).is_file()


def test_a_linked_file_is_reported_as_not_travelling(qtbot, tmp_path):
    # The other half of the promise: what will NOT survive the move is named.
    tab = ProjectTab(AppState())
    qtbot.addWidget(tab)
    tab.controller.new_project(tmp_path / "Linked")
    tab.controller.add_files([DLC], "tracking", copy=False)
    tab.controller.save()

    rows = tab.controller.report()
    assert any("outside the project folder" in text for _, _, text in rows)
    stored = tab.state.project.sessions[0].dlc_path
    assert is_external(stored)
    assert Path(stored).is_file(), "a linked file still resolves where it lives"
