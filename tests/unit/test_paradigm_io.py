"""Paradigm JSON save/load -- a user ("New") paradigm is the same data as a
built-in and must round-trip with no code (S2 M6 Task 3)."""

import json

import pytest

from sphynx.acts import Act, ActFamily
from sphynx.exceptions import SphynxIOError, SphynxValueError
from sphynx.paradigms import (
    CompositeSpec, MetricRef, Paradigm, ValidationRule, barnes_maze,
    load_paradigm, paradigm_from_dict, paradigm_to_dict, save_paradigm,
)
from sphynx.zones import ZoneSelector


def _user_paradigm():
    return Paradigm(
        name="MyMaze", parent="OF", doc="user-defined",
        composites=[CompositeSpec("all_pits", ZoneSelector(zone_class="pit"))],
        families=[ActFamily(
            name="nose_at_pit",
            selector=ZoneSelector(zone_class="pit", is_target=False),
            template=Act(name="nose_at_pit", type="simple", body_part="nose",
                         required_parts=["nose"], fallback={"nose": ["headcenter"]},
                         min_duration_sec=0.3),
            name_pattern="{family}_{zone}",
        )],
        metrics=[MetricRef("visit_order", {"family": "nose_at_pit"})],
        config_defaults={"velocity_rest": 1.5},
        validation=[ValidationRule(code="needs_pits", kind="zone_count",
                                   zone_class="pit", min=3, message="need pits")],
    )


def test_dict_round_trip_preserves_everything():
    original = _user_paradigm()
    back = paradigm_from_dict(paradigm_to_dict(original))

    assert back.name == "MyMaze"
    assert back.parent == "OF"
    assert back.doc == "user-defined"
    assert back.composites[0].name == "all_pits"
    assert back.composites[0].selector.zone_class == "pit"
    fam = back.families[0]
    assert fam.name == "nose_at_pit"
    assert fam.name_pattern == "{family}_{zone}"
    assert fam.selector.is_target is False
    assert fam.template.body_part == "nose"
    assert fam.template.required_parts == ["nose"]
    assert fam.template.fallback == {"nose": ["headcenter"]}
    assert fam.template.min_duration_sec == 0.3
    assert back.metrics[0].name == "visit_order"
    assert back.metrics[0].params == {"family": "nose_at_pit"}
    assert back.config_defaults == {"velocity_rest": 1.5}
    assert back.validation[0].code == "needs_pits"
    assert back.validation[0].min == 3


def test_file_round_trip(tmp_path):
    path = tmp_path / "nested" / "my_maze.json"
    written = save_paradigm(_user_paradigm(), path)
    assert path.is_file()
    back = load_paradigm(written)
    assert back.name == "MyMaze"
    assert back.families[0].template.fallback == {"nose": ["headcenter"]}


def test_saved_file_is_readable_json(tmp_path):
    path = tmp_path / "p.json"
    save_paradigm(_user_paradigm(), path)
    data = json.loads(path.read_text(encoding="utf-8"))
    assert data["name"] == "MyMaze"
    assert data["schema_version"] == 1


def test_builtin_round_trips_too(tmp_path):
    path = tmp_path / "barnes.json"
    save_paradigm(barnes_maze(), path)
    back = load_paradigm(path)
    assert back.name == "Barnes"
    assert [m.name for m in back.metrics] == [
        "visit_order", "latency_to_target", "primary_errors", "time_to_completion"]
    assert back.families[0].selector.zone_class == "hole"


def test_missing_file_raises():
    with pytest.raises(SphynxIOError):
        load_paradigm("no_such_paradigm_file.json")


def test_malformed_json_raises(tmp_path):
    path = tmp_path / "bad.json"
    path.write_text("{not json", encoding="utf-8")
    with pytest.raises(SphynxIOError):
        load_paradigm(path)


def test_unnamed_paradigm_data_raises():
    with pytest.raises(SphynxValueError):
        paradigm_from_dict({"schema_version": 1, "parent": "OF"})


def test_unknown_schema_version_raises():
    data = paradigm_to_dict(_user_paradigm())
    data["schema_version"] = 99
    with pytest.raises(SphynxValueError):
        paradigm_from_dict(data)


def test_unknown_field_is_rejected_loudly():
    # A typo in a hand-edited file must not be silently ignored.
    data = paradigm_to_dict(_user_paradigm())
    data["validation"][0]["levl"] = "warning"
    with pytest.raises(SphynxValueError):
        paradigm_from_dict(data)


def test_non_object_data_raises():
    with pytest.raises(SphynxValueError):
        paradigm_from_dict(["not", "a", "paradigm"])
