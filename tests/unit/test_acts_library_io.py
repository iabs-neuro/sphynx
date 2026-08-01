import json

import pytest

from sphynx.acts import Act, ActFamily
from sphynx.acts.library_io import (
    ActLibrary, library_from_dict, library_to_dict, load_library, save_library,
)
from sphynx.exceptions import SphynxIOError, SphynxValueError
from sphynx.zones import ZoneSelector


def _library():
    return ActLibrary(
        acts=[Act(name="nose_in_centre", type="simple", body_part="nose",
                  required_parts=["nose"], zones=["Center"], speed_min=0.0,
                  min_duration_sec=0.4, max_gap_sec=0.2, median_window_sec=0.3)],
        families=[ActFamily(
            name="nose_at_object",
            selector=ZoneSelector(zone_class="object_area"),
            template=Act(name="nose_at_object", type="simple", body_part="nose",
                         required_parts=["nose"]),
            name_pattern="{family}{index}")],
    )


def test_dict_round_trip_preserves_acts_and_families():
    back = library_from_dict(library_to_dict(_library()))
    assert [a.name for a in back.acts] == ["nose_in_centre"]
    act = back.acts[0]
    assert act.body_part == "nose"
    assert act.zones == ["Center"]
    assert act.min_duration_sec == 0.4
    assert act.median_window_sec == 0.3
    family = back.families[0]
    assert family.selector.zone_class == "object_area"
    assert family.name_pattern == "{family}{index}"
    assert family.template.body_part == "nose"


def test_file_round_trip(tmp_path):
    path = tmp_path / "nested" / "acts.json"
    save_library(_library(), path)
    assert path.is_file()
    back = load_library(path)
    assert [a.name for a in back.acts] == ["nose_in_centre"]


def test_saved_file_is_portable_json(tmp_path):
    # Act defaults carry inf and NaN, which bare json writes in a form other
    # readers reject.
    path = tmp_path / "acts.json"
    save_library(_library(), path)
    raw = path.read_text(encoding="utf-8")
    assert "Infinity" not in raw and "NaN" not in raw
    assert json.loads(raw)["schema_version"] == 1
    import math
    assert math.isinf(load_library(path).acts[0].speed_max)


def test_unknown_top_level_field_raises():
    data = library_to_dict(_library())
    data["actz"] = data.pop("acts")
    with pytest.raises(SphynxValueError):
        library_from_dict(data)


def test_unknown_act_field_raises():
    data = library_to_dict(_library())
    data["acts"][0]["speed_mim"] = 1.0
    with pytest.raises(SphynxValueError):
        library_from_dict(data)


def test_missing_schema_version_raises():
    data = library_to_dict(_library())
    del data["schema_version"]
    with pytest.raises(SphynxValueError):
        library_from_dict(data)


def test_unknown_schema_version_raises():
    data = library_to_dict(_library())
    data["schema_version"] = 99
    with pytest.raises(SphynxValueError):
        library_from_dict(data)


def test_expression_tree_cannot_be_saved():
    from sphynx.acts.expr import Leaf

    library = ActLibrary(acts=[Act(name="c", type="complex", expr=Leaf("other"))])
    with pytest.raises(SphynxValueError):
        library_to_dict(library)


def test_missing_file_raises():
    with pytest.raises(SphynxIOError):
        load_library("no_such_library.json")


def test_malformed_json_raises(tmp_path):
    path = tmp_path / "bad.json"
    path.write_text("{not json", encoding="utf-8")
    with pytest.raises(SphynxIOError):
        load_library(path)


def test_empty_library_round_trips():
    back = library_from_dict(library_to_dict(ActLibrary()))
    assert back.acts == []
    assert back.families == []
