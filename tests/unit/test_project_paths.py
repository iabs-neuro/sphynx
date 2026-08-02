"""Project paths and the folder layout (S4f).

A path under the project root is stored relative so the whole folder can move
to another machine; anything else is stored absolute and is therefore visibly
external. The stored string is the only signal -- a separate flag could drift
away from the path it describes.
"""

import os
from pathlib import Path

import pytest

from sphynx.exceptions import SphynxIOError, SphynxValueError
from sphynx.project.paths import (
    LAYOUT, create_layout, import_file, is_external, resolve_path, store_path,
)


@pytest.fixture
def root(tmp_path):
    project = tmp_path / "MyExperiment"
    project.mkdir()
    return project


# --- storing and resolving -------------------------------------------------
def test_a_path_under_the_root_is_stored_relative(root):
    inside = root / "tracking" / "session.csv"
    stored = store_path(inside, root)
    assert not os.path.isabs(stored)
    assert ".." not in stored
    assert Path(stored).as_posix() == "tracking/session.csv"


def test_a_path_outside_the_root_is_stored_absolute(root, tmp_path):
    outside = tmp_path / "elsewhere" / "session.csv"
    stored = store_path(outside, root)
    assert os.path.isabs(stored)


def test_a_sibling_folder_is_outside_even_though_it_shares_a_parent(root, tmp_path):
    # MyExperiment_backup starts with the same characters as MyExperiment, so
    # a prefix test on strings would call it inside.
    sibling = tmp_path / "MyExperiment_backup" / "session.csv"
    assert is_external(store_path(sibling, root))


@pytest.mark.parametrize("relative", [True, False])
def test_storing_then_resolving_returns_the_original(root, tmp_path, relative):
    original = (root / "presets" / "a.mat") if relative else (
        tmp_path / "elsewhere" / "a.mat")
    resolved = resolve_path(store_path(original, root), root)
    assert Path(resolved) == original


def test_is_external_agrees_with_what_was_stored(root, tmp_path):
    assert not is_external(store_path(root / "temp" / "x.mat", root))
    assert is_external(store_path(tmp_path / "away" / "x.mat", root))


def test_an_empty_path_stays_empty(root):
    # An unset path is unset, not the project root.
    assert store_path("", root) == ""
    assert resolve_path("", root) == ""
    assert not is_external("")


# --- the layout ------------------------------------------------------------
def test_creating_the_layout_makes_every_folder(root):
    made = create_layout(root)
    assert set(made) == set(LAYOUT)
    assert all(state == "created" for state in made.values())
    for name in LAYOUT:
        assert (root / name).is_dir()


def test_the_layout_is_exactly_the_five_named_folders():
    assert LAYOUT == ("raw_videos", "tracking", "presets", "behavior", "temp")


def test_creating_the_layout_twice_keeps_what_is_there(root):
    create_layout(root)
    kept = root / "tracking" / "session.csv"
    kept.write_text("data", encoding="utf-8")
    again = create_layout(root)
    assert all(state == "existed" for state in again.values())
    assert kept.read_text(encoding="utf-8") == "data"


def test_a_file_where_a_folder_should_be_is_reported_by_name(root):
    (root / "presets").write_text("not a folder", encoding="utf-8")
    with pytest.raises(SphynxIOError, match="presets"):
        create_layout(root)


def test_the_layout_creates_the_root_itself_if_it_is_missing(tmp_path):
    root = tmp_path / "brand" / "new"
    create_layout(root)
    assert (root / "temp").is_dir()


# --- importing files -------------------------------------------------------
def _source(tmp_path, name="session.csv", text="x,y\n1,2\n"):
    source = tmp_path / "outside"
    source.mkdir(exist_ok=True)
    target = source / name
    target.write_text(text, encoding="utf-8")
    return target


def test_copying_puts_the_file_in_the_subfolder_and_stores_it_relative(root, tmp_path):
    create_layout(root)
    source = _source(tmp_path)
    stored = import_file(source, root, "tracking", copy=True)
    assert not is_external(stored)
    assert (root / "tracking" / "session.csv").is_file()
    assert source.is_file(), "the original must stay where it was"


def test_linking_copies_nothing_and_stores_an_absolute_path(root, tmp_path):
    create_layout(root)
    source = _source(tmp_path)
    stored = import_file(source, root, "tracking", copy=False)
    assert is_external(stored)
    assert not (root / "tracking" / "session.csv").exists()
    assert Path(resolve_path(stored, root)) == source


def test_a_missing_source_is_reported(root, tmp_path):
    create_layout(root)
    with pytest.raises(SphynxIOError, match="not found"):
        import_file(tmp_path / "nope.csv", root, "tracking", copy=True)


def test_an_unknown_subfolder_names_the_known_ones(root, tmp_path):
    create_layout(root)
    with pytest.raises(SphynxValueError, match="raw_videos"):
        import_file(_source(tmp_path), root, "somewhere", copy=True)


def test_copying_over_a_different_file_of_the_same_name_is_refused(root, tmp_path):
    # Overwriting would destroy data the user put there, and the two files
    # only share a name by coincidence.
    create_layout(root)
    (root / "tracking" / "session.csv").write_text("mine", encoding="utf-8")
    with pytest.raises(SphynxIOError, match="already"):
        import_file(_source(tmp_path), root, "tracking", copy=True)


def test_copying_the_identical_file_again_is_accepted(root, tmp_path):
    create_layout(root)
    source = _source(tmp_path)
    first = import_file(source, root, "tracking", copy=True)
    assert import_file(source, root, "tracking", copy=True) == first


def test_a_file_already_inside_the_project_is_not_copied_onto_itself(root):
    create_layout(root)
    inside = root / "tracking" / "session.csv"
    inside.write_text("data", encoding="utf-8")
    stored = import_file(inside, root, "tracking", copy=True)
    assert Path(stored).as_posix() == "tracking/session.csv"
    assert inside.read_text(encoding="utf-8") == "data"


def test_a_file_inside_the_project_but_in_another_subfolder_is_copied(root):
    create_layout(root)
    stray = root / "raw_videos" / "session.csv"
    stray.write_text("data", encoding="utf-8")
    stored = import_file(stray, root, "tracking", copy=True)
    assert Path(stored).as_posix() == "tracking/session.csv"
    assert stray.is_file()
