import pytest

from sphynx.exceptions import SphynxIOError
from sphynx.project import DEFAULT_PATTERN, ProjectSession
from sphynx.project.scan import parse_session_name, scan_folder, session_is_parsed


def _make(root, *names):
    for name in names:
        (root / name).write_text("x", encoding="utf-8")
    return root


def test_parses_the_default_pattern():
    got = parse_session_name("NOF_H01_1D", DEFAULT_PATTERN)
    assert got == {"exp": "NOF", "mouse": "H01", "session": "1D"}


def test_unparsed_name_returns_empty():
    assert parse_session_name("whatever", DEFAULT_PATTERN) == {}


def test_scan_finds_csv_files(tmp_path):
    _make(tmp_path, "NOF_H01_1D.csv", "NOF_H01_2D.csv")
    sessions = scan_folder(tmp_path)
    assert [s.name for s in sessions] == ["NOF_H01_1D", "NOF_H01_2D"]
    assert all(s.dlc_path for s in sessions)


def test_scan_is_recursive(tmp_path):
    nested = tmp_path / "day1"
    nested.mkdir()
    _make(nested, "NOF_H01_1D.csv")
    assert [s.name for s in scan_folder(tmp_path)] == ["NOF_H01_1D"]


def test_metadata_comes_from_the_name(tmp_path):
    _make(tmp_path, "NOF_H01_1D.csv")
    session = scan_folder(tmp_path)[0]
    assert session.metadata["mouse"] == "H01"
    assert session.metadata["session"] == "1D"
    assert session_is_parsed(session) is True


def test_unparsed_name_is_marked_not_guessed(tmp_path):
    _make(tmp_path, "randomfile.csv")
    session = scan_folder(tmp_path)[0]
    assert session.metadata == {}
    assert session_is_parsed(session) is False


def test_rescan_keeps_edited_sessions(tmp_path):
    _make(tmp_path, "NOF_H01_1D.csv")
    edited = ProjectSession(name="NOF_H01_1D", dlc_path="old.csv",
                            preset_path="chosen.mat",
                            metadata={"mouse": "H01", "group": "control"})
    sessions = scan_folder(tmp_path, existing=[edited])
    assert len(sessions) == 1
    assert sessions[0].preset_path == "chosen.mat"
    assert sessions[0].metadata["group"] == "control"


def test_rescan_adds_new_files(tmp_path):
    _make(tmp_path, "NOF_H01_1D.csv", "NOF_H01_2D.csv")
    existing = [ProjectSession(name="NOF_H01_1D", dlc_path="old.csv")]
    sessions = scan_folder(tmp_path, existing=existing)
    assert [s.name for s in sessions] == ["NOF_H01_1D", "NOF_H01_2D"]


def test_missing_folder_raises(tmp_path):
    with pytest.raises(SphynxIOError):
        scan_folder(tmp_path / "nope")


def test_bad_pattern_raises(tmp_path):
    _make(tmp_path, "NOF_H01_1D.csv")
    with pytest.raises(SphynxIOError):
        scan_folder(tmp_path, pattern="([unclosed")
