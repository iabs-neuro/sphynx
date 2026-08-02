"""Project tab: create, open, configure, add data (S4f)."""

import json
from pathlib import Path

import pytest

from sphynx.project import load_project
from sphynx.project.paths import LAYOUT, is_external
from sphynx_gui.project_tab import COPY_CHOICES, ProjectTab
from sphynx_gui.state import AppState


def _tab(qtbot):
    tab = ProjectTab(AppState())
    qtbot.addWidget(tab)
    return tab


def _dlc(tmp_path, name="NOF_H01_1D.csv"):
    outside = tmp_path / "outside"
    outside.mkdir(exist_ok=True)
    target = outside / name
    target.write_text("scorer,x,y\n", encoding="utf-8")
    return target


# --- creating --------------------------------------------------------------
def test_a_new_project_gets_every_folder_and_a_file(qtbot, tmp_path):
    tab = _tab(qtbot)
    root = tmp_path / "MyExperiment"
    tab.controller.new_project(root)
    assert (root / "project.json").is_file()
    for name in LAYOUT:
        assert (root / name).is_dir(), name
    assert tab.state.project.root == str(root.resolve())


def test_a_new_project_is_named_after_its_folder(qtbot, tmp_path):
    tab = _tab(qtbot)
    tab.controller.new_project(tmp_path / "Barnes2026")
    assert tab.state.project.name == "Barnes2026"


def test_a_new_project_is_saved_so_it_starts_clean(qtbot, tmp_path):
    tab = _tab(qtbot)
    tab.controller.new_project(tmp_path / "clean")
    assert not tab.state.project_dirty


def test_creating_over_an_existing_project_is_refused(qtbot, tmp_path):
    # Overwriting would throw away sessions and rules with no way back.
    tab = _tab(qtbot)
    root = tmp_path / "existing"
    tab.controller.new_project(root)
    tab.state.project.name = "do not lose me"
    tab.controller.save()
    tab.controller.new_project(root)
    assert "already exists" in tab.status_label.text().lower()
    assert load_project(root / "project.json").name == "do not lose me"


# --- opening ---------------------------------------------------------------
def test_a_folder_can_be_opened_instead_of_the_file(qtbot, tmp_path):
    tab = _tab(qtbot)
    root = tmp_path / "byfolder"
    tab.controller.new_project(root)
    other = _tab(qtbot)
    other.controller.open_project(root)
    assert other.state.project.root == str(root.resolve())


def test_a_folder_with_no_project_is_reported(qtbot, tmp_path):
    tab = _tab(qtbot)
    empty = tmp_path / "empty"
    empty.mkdir()
    tab.controller.open_project(empty)
    assert "no project.json" in tab.status_label.text().lower()
    assert tab.state.project.root == ""


def test_missing_folders_are_recreated_and_named(qtbot, tmp_path):
    tab = _tab(qtbot)
    root = tmp_path / "partial"
    tab.controller.new_project(root)
    (root / "temp").rmdir()
    other = _tab(qtbot)
    other.controller.open_project(root)
    assert (root / "temp").is_dir()
    assert "temp" in other.status_label.text()


def test_an_old_project_opens_unsaved_and_says_so(qtbot, tmp_path):
    root = tmp_path / "old"
    root.mkdir()
    (root / "project.json").write_text(json.dumps({
        "schema_version": 1, "name": "old", "sessions": [],
        "preset_rules": [], "paradigm": "EOF", "library_path": "",
        "out_dir": "", "name_pattern": ".*", "output_selection": {}}),
        encoding="utf-8")
    tab = _tab(qtbot)
    tab.controller.open_project(root)
    assert tab.state.project_dirty
    assert "older version" in tab.status_label.text().lower()
    assert tab.state.paradigm == "EOF"


def test_opening_an_old_project_leaves_the_file_alone(qtbot, tmp_path):
    root = tmp_path / "old"
    root.mkdir()
    target = root / "project.json"
    target.write_text(json.dumps({
        "schema_version": 1, "name": "old", "sessions": [],
        "preset_rules": [], "paradigm": "OF", "library_path": "",
        "out_dir": "", "name_pattern": ".*", "output_selection": {}}),
        encoding="utf-8")
    before = target.read_text(encoding="utf-8")
    _tab(qtbot).controller.open_project(root)
    assert target.read_text(encoding="utf-8") == before


# --- settings --------------------------------------------------------------
def test_changing_the_paradigm_marks_the_project_unsaved(qtbot, tmp_path):
    tab = _tab(qtbot)
    tab.controller.new_project(tmp_path / "p")
    tab.controller.set_paradigm("EOF")
    assert tab.state.project.paradigm == "EOF"
    assert tab.state.project_dirty
    assert tab.dirty_label.text() != ""


def test_saving_clears_the_unsaved_mark(qtbot, tmp_path):
    tab = _tab(qtbot)
    tab.controller.new_project(tmp_path / "p")
    tab.controller.set_paradigm("EOF")
    tab.controller.save()
    assert not tab.state.project_dirty
    assert load_project(tmp_path / "p" / "project.json").paradigm == "EOF"


def test_saving_without_a_folder_is_reported(qtbot):
    tab = _tab(qtbot)
    tab.controller.save()
    assert "save as" in tab.status_label.text().lower()


def test_an_empty_library_can_be_created_in_the_root(qtbot, tmp_path):
    tab = _tab(qtbot)
    root = tmp_path / "p"
    tab.controller.new_project(root)
    tab.controller.create_library()
    assert (root / "acts_library.json").is_file()
    assert tab.state.project.library_path == str(root / "acts_library.json")


# --- adding data -----------------------------------------------------------
def test_copying_a_tracking_file_puts_it_in_the_project(qtbot, tmp_path):
    tab = _tab(qtbot)
    root = tmp_path / "p"
    tab.controller.new_project(root)
    source = _dlc(tmp_path)
    tab.controller.add_files([source], "tracking", copy=True)

    assert (root / "tracking" / source.name).is_file()
    assert source.is_file(), "the original stays where it was"
    session = tab.state.project.sessions[0]
    assert not is_external(session.dlc_path)
    assert Path(session.dlc_path).as_posix() == f"tracking/{source.name}"


def test_linking_a_tracking_file_leaves_it_outside_and_says_so(qtbot, tmp_path):
    tab = _tab(qtbot)
    root = tmp_path / "p"
    tab.controller.new_project(root)
    source = _dlc(tmp_path)
    tab.controller.add_files([source], "tracking", copy=False)

    assert not (root / "tracking" / source.name).exists()
    assert is_external(tab.state.project.sessions[0].dlc_path)
    assert "outside the project" in tab.status_label.text()


def test_adding_the_same_tracking_file_twice_adds_one_session(qtbot, tmp_path):
    tab = _tab(qtbot)
    tab.controller.new_project(tmp_path / "p")
    source = _dlc(tmp_path)
    tab.controller.add_files([source], "tracking", copy=True)
    tab.controller.add_files([source], "tracking", copy=True)
    assert len(tab.state.project.sessions) == 1


def test_adding_data_marks_the_project_unsaved(qtbot, tmp_path):
    tab = _tab(qtbot)
    tab.controller.new_project(tmp_path / "p")
    tab.controller.add_files([_dlc(tmp_path)], "tracking", copy=True)
    assert tab.state.project_dirty


def test_a_video_is_attached_to_the_session_it_belongs_to(qtbot, tmp_path):
    tab = _tab(qtbot)
    root = tmp_path / "p"
    tab.controller.new_project(root)
    tab.controller.add_files(
        [_dlc(tmp_path, "NOF_H01_1DDLC_resnet50_x.csv")], "tracking", copy=True)

    video = tmp_path / "outside" / "NOF_H01_1D.mp4"
    video.write_bytes(b"not really a video")
    tab.controller.add_files([video], "raw_videos", copy=True)
    assert tab.state.project.sessions[0].video_path.endswith("NOF_H01_1D.mp4")


def test_adding_files_without_a_project_is_reported(qtbot, tmp_path):
    tab = _tab(qtbot)
    tab.controller.add_files([_dlc(tmp_path)], "tracking", copy=True)
    assert "create or open a project" in tab.status_label.text().lower()


def test_a_missing_source_is_counted_not_raised(qtbot, tmp_path):
    tab = _tab(qtbot)
    tab.controller.new_project(tmp_path / "p")
    tab.controller.add_files([tmp_path / "nope.csv"], "tracking", copy=True)
    assert "failed" in tab.status_label.text().lower()
    assert tab.state.project.sessions == []


# --- what the tab shows ----------------------------------------------------
def test_the_folder_table_lists_all_five(qtbot, tmp_path):
    tab = _tab(qtbot)
    tab.controller.new_project(tmp_path / "p")
    assert tab.folders_table.rowCount() == len(LAYOUT)
    names = [tab.folders_table.item(r, 0).text()
             for r in range(tab.folders_table.rowCount())]
    assert names == list(LAYOUT)
    states = {tab.folders_table.item(r, 2).text()
              for r in range(tab.folders_table.rowCount())}
    assert states == {"ok"}


def test_without_a_project_the_warnings_say_so(qtbot):
    tab = _tab(qtbot)
    rows = tab.controller.report()
    assert any("No project" in text for _, _, text in rows)


def test_an_external_path_is_reported_as_not_travelling(qtbot, tmp_path):
    tab = _tab(qtbot)
    tab.controller.new_project(tmp_path / "p")
    tab.controller.add_files([_dlc(tmp_path)], "tracking", copy=False)
    rows = tab.controller.report()
    assert any("outside the project folder" in text for _, _, text in rows)


def test_a_file_that_is_gone_is_reported_as_an_error(qtbot, tmp_path):
    tab = _tab(qtbot)
    root = tmp_path / "p"
    tab.controller.new_project(root)
    source = _dlc(tmp_path)
    tab.controller.add_files([source], "tracking", copy=True)
    (root / "tracking" / source.name).unlink()
    rows = tab.controller.report()
    assert any(level == "error" and "not there" in text
               for _, level, text in rows)


def test_the_copy_choice_is_readable_from_the_widget(qtbot):
    tab = _tab(qtbot)
    tab.copy_box.setCurrentText(COPY_CHOICES[0])
    assert tab.copy_selected()
    tab.copy_box.setCurrentText(COPY_CHOICES[1])
    assert not tab.copy_selected()


# --- save as ---------------------------------------------------------------
def test_save_as_keeps_the_files_reachable(qtbot, tmp_path):
    # Paths stored against the old root must be resolved before the move, or
    # every session would silently point into a folder that has none of them.
    tab = _tab(qtbot)
    old = tmp_path / "old"
    tab.controller.new_project(old)
    source = _dlc(tmp_path)
    tab.controller.add_files([source], "tracking", copy=True)

    new = tmp_path / "new"
    tab.controller.save_as(new)
    assert (new / "project.json").is_file()
    session = load_project(new / "project.json").sessions[0]
    assert Path(session.dlc_path).is_file()
