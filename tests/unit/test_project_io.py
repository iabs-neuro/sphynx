import pytest

from sphynx.exceptions import SphynxIOError, SphynxValueError
from sphynx.project import (
    PresetRule, Project, ProjectSession, load_project, project_from_dict,
    project_to_dict, save_project,
)


def _project():
    return Project(
        name="NOF pilot",
        sessions=[
            ProjectSession(name="NOF_H01_1D", dlc_path="a.csv",
                           metadata={"mouse": "H01", "day": "1D"}),
            ProjectSession(name="NOF_H01_2D", dlc_path="b.csv",
                           preset_path="manual.mat",
                           metadata={"mouse": "H01", "day": "2D"}),
        ],
        preset_rules=[PresetRule("all.mat"), PresetRule("day3.mat", {"day": "3D"})],
        paradigm="EOF", library_path="acts.json", out_dir="out",
    )


def test_dict_round_trip():
    back = project_from_dict(project_to_dict(_project()))
    assert back.name == "NOF pilot"
    assert [s.name for s in back.sessions] == ["NOF_H01_1D", "NOF_H01_2D"]
    assert back.sessions[1].preset_path == "manual.mat"
    assert back.sessions[0].metadata == {"mouse": "H01", "day": "1D"}
    assert [r.preset_path for r in back.preset_rules] == ["all.mat", "day3.mat"]
    assert back.preset_rules[1].match == {"day": "3D"}
    assert back.paradigm == "EOF"
    assert back.library_path == "acts.json"
    assert back.out_dir == "out"


def test_file_round_trip(tmp_path):
    path = tmp_path / "nested" / "project.json"
    save_project(_project(), path)
    assert path.is_file()
    assert load_project(path).name == "NOF pilot"


def test_unknown_top_level_field_raises():
    data = project_to_dict(_project())
    data["sesions"] = data.pop("sessions")
    with pytest.raises(SphynxValueError):
        project_from_dict(data)


def test_unknown_session_field_raises():
    data = project_to_dict(_project())
    data["sessions"][0]["dlc_pth"] = "typo.csv"
    with pytest.raises(SphynxValueError):
        project_from_dict(data)


def test_missing_schema_version_raises():
    data = project_to_dict(_project())
    del data["schema_version"]
    with pytest.raises(SphynxValueError):
        project_from_dict(data)


def test_unknown_schema_version_raises():
    data = project_to_dict(_project())
    data["schema_version"] = 99
    with pytest.raises(SphynxValueError):
        project_from_dict(data)


def test_missing_file_raises():
    with pytest.raises(SphynxIOError):
        load_project("no_such_project.json")


def test_empty_project_round_trips():
    back = project_from_dict(project_to_dict(Project()))
    assert back.sessions == []
    assert back.preset_rules == []
    assert back.paradigm == "OF"


def test_output_selection_round_trips():
    project = Project(output_selection={"acts": ["rest"],
                                        "act_stats": ["ActPercent"],
                                        "named_metrics": ["path_length"]})
    back = project_from_dict(project_to_dict(project))
    assert back.output_selection["acts"] == ["rest"]
    assert back.output_selection["named_metrics"] == ["path_length"]


def test_output_selection_defaults_to_empty():
    assert Project().output_selection == {}
    assert project_from_dict(project_to_dict(Project())).output_selection == {}
