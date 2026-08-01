"""Legacy preset upgrade: names -> zone roles."""

import numpy as np
import pytest

from sphynx.exceptions import SphynxIOError
from sphynx.io.preset_upgrade import (
    classify_legacy_zone, upgrade_preset_file, upgrade_zone_structs,
)


class _Zone:
    def __init__(self, name, mask=None, type_="area"):
        self.name = name
        self.type = type_
        self.maskfilled = np.zeros((6, 6), dtype=bool) if mask is None else mask


# --- the naming convention -------------------------------------------------

def test_object_real_is_the_object_itself():
    got = classify_legacy_zone("Object1Real")
    assert got.zone_class == "object"
    assert got.index == 1
    assert got.is_target is False


def test_object_out_is_the_ring_around_it():
    got = classify_legacy_zone("Object1Out")
    assert got.zone_class == "object_ring"
    assert got.index == 1


def test_realout_is_the_investigation_area():
    # Object plus the ring around it: the zone an investigation act is scored
    # in. It is its own class, so a family binds it alone and nothing is
    # counted twice.
    got = classify_legacy_zone("Object1RealOut")
    assert got.zone_class == "object_area"
    assert got.index == 1


def test_the_three_object_classes_are_distinct():
    assert classify_legacy_zone("Object1Real").zone_class == "object"
    assert classify_legacy_zone("Object1Out").zone_class == "object_ring"
    assert classify_legacy_zone("Object1RealOut").zone_class == "object_area"


def test_aggregates_are_not_given_a_class():
    for name in ("ObjectAllReal", "ArenaWallsAllReal", "ArenaCornersAllOut",
                 "WallsAndCornersReal", "objectall_real"):
        assert classify_legacy_zone(name).zone_class == "legacy_aggregate"


def test_arena_walls_and_corners():
    assert classify_legacy_zone("ArenaReal").zone_class == "arena"
    assert classify_legacy_zone("ArenaWallReal2").zone_class == "wall"
    assert classify_legacy_zone("ArenaWallReal2").index == 2
    assert classify_legacy_zone("ArenaCornerReal3").zone_class == "corner"
    assert classify_legacy_zone("Center").zone_class == "center"


def test_snake_case_names_are_understood_too():
    # Barnes presets use object1_real where NOF presets use Object1Real.
    assert classify_legacy_zone("object1_real").zone_class == "object"
    assert classify_legacy_zone("object1_out").zone_class == "object_ring"
    assert classify_legacy_zone("arena_realout").zone_class == "arena_area"


# --- experiment-dependent meaning ------------------------------------------

def test_barnes_objects_are_holes():
    # The preset states its ExperimentType; this is read, not guessed.
    got = classify_legacy_zone("object7_real", experiment_type="Barnes")
    assert got.zone_class == "hole"
    assert got.index == 7


def test_non_barnes_objects_stay_objects():
    assert classify_legacy_zone("Object2Real", "Novelty OF").zone_class == "object"


def test_target_is_marked_from_the_preset_name():
    got = classify_legacy_zone("target_real", experiment_type="Barnes")
    assert got.zone_class == "hole"
    assert got.is_target is True


def test_target_ring_keeps_the_target_flag():
    got = classify_legacy_zone("target_out", experiment_type="Barnes")
    assert got.zone_class == "hole_ring"
    assert got.is_target is True


def test_target_area_keeps_the_target_flag():
    got = classify_legacy_zone("target_realout", experiment_type="Barnes")
    assert got.zone_class == "hole_area"
    assert got.is_target is True


def test_unknown_name_is_left_unclassified_with_a_reason():
    got = classify_legacy_zone("SomethingNobodyNamed")
    assert got.zone_class == "unknown"
    assert "no legacy convention" in got.reason


# --- annotating loaded zones -----------------------------------------------

def test_upgrade_sets_the_fields_the_engine_reads():
    zones = [_Zone("Object1Real"), _Zone("ArenaReal")]
    report = upgrade_zone_structs(zones, "Novelty OF")
    assert zones[0].zone_class == "object"
    assert zones[0].roles.is_target is False
    assert zones[0].roles.tags == []
    assert zones[0].index == 1
    assert np.isnan(zones[0].angle)          # assigned once the centre is known
    assert len(report.classified) == 2


def test_non_mask_zones_are_skipped_and_reported():
    corner_point = _Zone("ArenaCorner1", mask=np.array([10.0, 20.0]), type_="point")
    report = upgrade_zone_structs([corner_point, _Zone("ArenaReal")], "")
    assert [name for name, _ in report.skipped] == ["ArenaCorner1"]
    assert len(report.zones) == 1


def test_counts_summarise_the_result():
    zones = [_Zone("Object1Real"), _Zone("Object2Real"), _Zone("ArenaReal")]
    counts = upgrade_zone_structs(zones, "Novelty OF").counts()
    assert counts["object"] == 2
    assert counts["arena"] == 1


def test_missing_source_file_raises(tmp_path):
    with pytest.raises(SphynxIOError):
        upgrade_preset_file(tmp_path / "nope.mat", tmp_path / "out.mat")
