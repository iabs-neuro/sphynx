"""Project schema version 2: folders, video paths, and reading version 1 (S4f)."""

import json
from pathlib import Path

import pytest

from sphynx.exceptions import SphynxValueError
from sphynx.project import Project, ProjectSession, load_project, save_project
from sphynx.project.io import SCHEMA_VERSION, load_project_detailed
from sphynx.project.model import folder


def _v1_file(path, **extra):
    data = {
        "schema_version": 1,
        "name": "old",
        "sessions": [{"name": "s1", "dlc_path": "D:/data/s1.csv",
                      "preset_path": "D:/presets/p.mat", "metadata": {}}],
        "preset_rules": [],
        "paradigm": "EOF",
        "library_path": "",
        "out_dir": "D:/out",
        "name_pattern": "^(?P<exp>[^_]+)_(?P<mouse>[^_]+)_(?P<day>.+)$",
        "output_selection": {},
    }
    data.update(extra)
    path.write_text(json.dumps(data), encoding="utf-8")
    return path


# --- version 2 -------------------------------------------------------------
def test_the_new_fields_survive_a_round_trip(tmp_path):
    project = Project(
        name="exp", root=str(tmp_path), temp_dir=str(tmp_path / "scratch"),
        preprocess_path=str(tmp_path / "preprocess.json"),
        sessions=[ProjectSession(name="s1", dlc_path="tracking/s1.csv",
                                 video_path="raw_videos/s1.mp4")])
    target = tmp_path / "project.json"
    save_project(project, target)
    back = load_project(target)
    assert back.temp_dir == str(tmp_path / "scratch")
    assert back.preprocess_path == str(tmp_path / "preprocess.json")
    assert back.sessions[0].video_path == "raw_videos/s1.mp4"


def test_the_root_comes_from_where_the_file_is_not_from_the_field(tmp_path):
    # A project that was moved carries a stale root. Honouring it would
    # resolve every relative path against a folder that is no longer there.
    moved = tmp_path / "moved"
    moved.mkdir()
    save_project(Project(name="exp", root="D:/somewhere/else"),
                 moved / "project.json")
    assert load_project(moved / "project.json").root == str(moved.resolve())


def test_an_unknown_field_is_still_refused(tmp_path):
    target = tmp_path / "project.json"
    target.write_text(json.dumps({"schema_version": SCHEMA_VERSION,
                                  "surprise": 1}), encoding="utf-8")
    with pytest.raises(SphynxValueError, match="surprise"):
        load_project(target)


def test_a_future_version_names_what_this_build_reads(tmp_path):
    target = tmp_path / "project.json"
    target.write_text(json.dumps({"schema_version": 3}), encoding="utf-8")
    with pytest.raises(SphynxValueError, match="version 3"):
        load_project(target)


# --- version 1 -------------------------------------------------------------
def test_a_version_1_file_is_read_and_flagged_as_upgraded(tmp_path):
    loaded = load_project_detailed(_v1_file(tmp_path / "project.json"))
    assert loaded.upgraded_from == 1
    assert loaded.project.paradigm == "EOF"
    assert loaded.project.root == str(tmp_path.resolve())


def test_version_1_paths_stay_absolute_which_makes_them_external(tmp_path):
    # They were absolute paths to files outside any project folder, and that
    # is exactly what "external" now means. Nothing is guessed.
    loaded = load_project_detailed(_v1_file(tmp_path / "project.json"))
    assert loaded.project.sessions[0].dlc_path == "D:/data/s1.csv"


def test_reading_a_version_1_file_does_not_rewrite_it(tmp_path):
    target = _v1_file(tmp_path / "project.json")
    before = target.read_text(encoding="utf-8")
    load_project_detailed(target)
    assert target.read_text(encoding="utf-8") == before


def test_a_version_1_file_with_a_version_2_field_is_refused(tmp_path):
    # Claiming version 1 while carrying version 2 content means the file was
    # hand-edited; guessing which half to believe would be worse than saying so.
    target = _v1_file(tmp_path / "project.json", temp_dir="D:/tmp")
    with pytest.raises(SphynxValueError, match="temp_dir"):
        load_project(target)


def test_a_version_2_file_is_not_flagged_as_upgraded(tmp_path):
    save_project(Project(name="new"), tmp_path / "project.json")
    assert load_project_detailed(tmp_path / "project.json").upgraded_from is None


# --- folders ---------------------------------------------------------------
def test_a_folder_defaults_to_a_subfolder_of_the_root(tmp_path):
    project = Project(root=str(tmp_path))
    assert folder(project, "temp") == str(tmp_path / "temp")
    assert folder(project, "raw_videos") == str(tmp_path / "raw_videos")


def test_an_override_wins_over_the_default(tmp_path):
    project = Project(root=str(tmp_path), temp_dir="D:/scratch")
    assert folder(project, "temp") == str(Path("D:/scratch"))


def test_a_project_with_no_root_has_no_folders(tmp_path):
    # Without a project the tabs behave as they did before, so "no folder" is
    # a state to report, not a failure to raise.
    assert folder(Project(), "behavior") == ""


def test_an_unknown_folder_names_the_known_ones():
    with pytest.raises(SphynxValueError, match="raw_videos"):
        folder(Project(), "somewhere")
