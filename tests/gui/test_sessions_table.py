"""The sessions table shows where every preset came from (S4c)."""

from sphynx.project import PresetRule, Project, ProjectSession
from sphynx_gui.sessions_table import COLUMNS, SessionsTable


def _project(**kw):
    sessions = kw.pop("sessions", None)
    if sessions is None:
        sessions = [
            ProjectSession(name="NOF_H01_1D", dlc_path="a.csv",
                           metadata={"mouse": "H01", "day": "1D"}),
            ProjectSession(name="NOF_H01_3D", dlc_path="b.csv",
                           metadata={"mouse": "H01", "day": "3D"}),
        ]
    return Project(sessions=sessions, **kw)


def _table(qtbot, project):
    table = SessionsTable()
    qtbot.addWidget(table)
    table.show_project(project)
    return table


def test_a_row_per_session_with_metadata(qtbot):
    table = _table(qtbot, _project())
    assert table.rowCount() == 2
    assert table.item(0, 0).text() == "NOF_H01_1D"
    assert table.item(0, COLUMNS.index("Mouse")).text() == "H01"
    assert table.item(1, COLUMNS.index("Day")).text() == "3D"


def test_a_general_rule_covers_every_session(qtbot):
    table = _table(qtbot, _project(preset_rules=[PresetRule("all.mat")]))
    assert [r["preset"] for r in table.rows] == ["all.mat", "all.mat"]
    assert [r["source"] for r in table.rows] == ["rule: all sessions"] * 2


def test_a_specific_rule_refines_the_general_one(qtbot):
    project = _project(preset_rules=[PresetRule("all.mat"),
                                     PresetRule("day3.mat", {"day": "3D"})])
    table = _table(qtbot, project)
    assert [r["preset"] for r in table.rows] == ["all.mat", "day3.mat"]
    assert table.rows[1]["source"] == "rule: day=3D"


def test_the_from_column_shows_the_source(qtbot):
    project = _project(preset_rules=[PresetRule("all.mat")])
    table = _table(qtbot, project)
    assert table.item(0, COLUMNS.index("From")).text() == "rule: all sessions"


def test_a_manual_path_is_marked_manual(qtbot):
    sessions = [ProjectSession(name="s", dlc_path="a.csv", preset_path="mine.mat",
                               metadata={"mouse": "H01"})]
    table = _table(qtbot, _project(sessions=sessions,
                                   preset_rules=[PresetRule("all.mat")]))
    assert table.rows[0]["preset"] == "mine.mat"
    assert table.rows[0]["source"] == "manual"


def test_a_session_without_a_preset_is_not_ready(qtbot, tmp_path):
    real = tmp_path / "NOF_H01_1D.csv"
    real.write_text("x", encoding="utf-8")
    sessions = [ProjectSession(name="NOF_H01_1D", dlc_path=str(real),
                               metadata={"mouse": "H01", "day": "1D"})]
    table = _table(qtbot, _project(sessions=sessions))
    assert table.rows[0]["source"] == "unassigned"
    assert table.rows[0]["status"] == "no preset assigned"


def test_a_session_without_a_dlc_file_is_not_ready(qtbot):
    sessions = [ProjectSession(name="s", metadata={"mouse": "H01"})]
    table = _table(qtbot, _project(sessions=sessions,
                                   preset_rules=[PresetRule("all.mat")]))
    assert table.rows[0]["status"] == "no DLC file"


def test_an_unparsed_name_is_flagged(qtbot, tmp_path):
    real = tmp_path / "whatever.csv"
    real.write_text("x", encoding="utf-8")
    sessions = [ProjectSession(name="whatever", dlc_path=str(real))]
    table = _table(qtbot, _project(sessions=sessions,
                                   preset_rules=[PresetRule("all.mat")]))
    assert table.rows[0]["status"] == "name not parsed"


def test_ready_when_everything_is_present(qtbot, tmp_path):
    real = tmp_path / "NOF_H01_1D.csv"
    real.write_text("x", encoding="utf-8")
    sessions = [ProjectSession(name="NOF_H01_1D", dlc_path=str(real),
                               metadata={"mouse": "H01", "day": "1D"})]
    table = _table(qtbot, _project(sessions=sessions,
                                   preset_rules=[PresetRule("all.mat")]))
    assert table.rows[0]["status"] == "ready"


def test_a_stale_path_is_not_ready(qtbot):
    # S4c review (I1): status checked only that the string was non-empty, so a
    # file that had moved still read "ready" and failed at run time.
    sessions = [ProjectSession(name="s", dlc_path="gone.csv",
                               metadata={"mouse": "H01", "day": "1D"})]
    table = _table(qtbot, _project(sessions=sessions,
                                   preset_rules=[PresetRule("all.mat")]))
    assert table.rows[0]["status"] == "DLC file missing"


def test_editing_metadata_writes_back(qtbot):
    project = _project(preset_rules=[PresetRule("all.mat")])
    table = _table(qtbot, project)
    table.item(0, COLUMNS.index("Group")).setText("control")
    table.apply_edits(project)
    assert project.sessions[0].metadata["group"] == "control"


def test_clearing_a_cell_removes_the_field(qtbot):
    project = _project(preset_rules=[PresetRule("all.mat")])
    table = _table(qtbot, project)
    table.item(0, COLUMNS.index("Mouse")).setText("")
    table.apply_edits(project)
    assert "mouse" not in project.sessions[0].metadata


def test_the_preset_column_is_not_editable(qtbot):
    from PySide6.QtCore import Qt

    table = _table(qtbot, _project(preset_rules=[PresetRule("all.mat")]))
    item = table.item(0, COLUMNS.index("Preset"))
    assert not item.flags() & Qt.ItemIsEditable


def test_selected_names_reads_the_highlighted_rows(qtbot):
    table = _table(qtbot, _project(preset_rules=[PresetRule("all.mat")]))
    table.selectRow(1)
    assert table.selected_names() == ["NOF_H01_3D"]
