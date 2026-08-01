"""Built-in paradigm hierarchy (S2 M6 Task 3)."""

import numpy as np
import pytest

from sphynx.paradigms import (
    PARADIGMS, barnes_maze, enriched_open_field, novel_object_recognition,
    open_field, register_builtin_paradigms, resolve_paradigm, ty_maze,
    validate_paradigm,
)
from sphynx.zones import Zone, ZoneRoles


@pytest.fixture(autouse=True)
def _builtins():
    saved = dict(PARADIGMS)
    PARADIGMS.clear()
    register_builtin_paradigms()
    yield
    PARADIGMS.clear()
    PARADIGMS.update(saved)


def _m():
    a = np.zeros((6, 6), dtype=bool)
    a[1:3, 1:3] = True
    return a


class _Options:
    pxl2sm = 22.2


def _preset(n_objects=0, n_holes=0, n_targets=0, n_arms=0):
    zs = [Zone("arena", "area", _m(), zone_class="arena")]
    for i in range(n_objects):
        zs.append(Zone(f"obj{i}", "area", _m(), zone_class="object"))
    for i in range(n_holes):
        zs.append(Zone(f"hole{i}", "area", _m(), zone_class="hole"))
    for i in range(n_targets):
        zs.append(Zone(f"target{i}", "area", _m(), zone_class="hole",
                       roles=ZoneRoles(is_target=True)))
    for i in range(n_arms):
        zs.append(Zone(f"arm{i}", "area", _m(), zone_class="arm"))
    return zs


def test_all_builtins_register_and_resolve():
    for name in ("OF", "EOF", "NOR", "Barnes", "TYMaze"):
        assert name in PARADIGMS
        assert resolve_paradigm(name).name == name


def test_of_has_speed_defaults_and_calibration_rule():
    of = resolve_paradigm("OF")
    assert of.config_defaults["velocity_rest"] == 1.0
    assert of.config_defaults["velocity_locomotion"] == 5.0
    assert [r.code for r in of.validation] == ["needs_calibration"]


def test_eof_inherits_of_defaults():
    eof = resolve_paradigm("EOF")
    assert eof.config_defaults["velocity_rest"] == 1.0
    assert [f.name for f in eof.families] == ["nose_at_object_ring", "nose_at_object", "inside_object"]
    assert {r.code for r in eof.validation} == {"needs_calibration", "needs_object"}


def test_nor_narrows_the_eof_object_rule():
    nor = resolve_paradigm("NOR")
    # inherits the EOF families...
    assert [f.name for f in nor.families] == ["nose_at_object_ring", "nose_at_object", "inside_object"]
    # ...and overrides the same-coded rule with an exact count
    rule = next(r for r in nor.validation if r.code == "needs_object")
    assert (rule.min, rule.max) == (2, 2)


def test_barnes_declares_family_and_generic_metrics():
    barnes = resolve_paradigm("Barnes")
    assert "nose_at_hole" in [f.name for f in barnes.families]
    names = [m.name for m in barnes.metrics]
    for expected in ("visit_order", "latency_to_target", "primary_errors",
                     "time_to_completion"):
        assert expected in names
    # every family-scoped ref names a family that the paradigm declares
    declared = {f.name for f in barnes.families}
    for ref in barnes.metrics:
        family = ref.params.get("family")
        assert family is None or family in declared


def test_barnes_family_binds_a_class_not_a_zone_name():
    barnes = resolve_paradigm("Barnes")
    selector = barnes.families[0].selector
    assert selector.zone_class == "hole"
    assert selector.is_target is None          # the whole class, target included


def test_barnes_inherits_of_calibration_rule():
    codes = {r.code for r in resolve_paradigm("Barnes").validation}
    assert codes == {"needs_calibration", "needs_holes", "needs_one_target"}


def test_ty_maze_is_a_scaffold_without_choice_metrics():
    ty = resolve_paradigm("TYMaze")
    assert [f.name for f in ty.families] == ["in_arm"]
    # It inherits OF's generic metrics but declares no choice/decision metrics
    # of its own -- those are deferred by design.
    assert {m.name for m in ty.metrics} == {"path_length", "mean_speed"}
    assert "deferred" in ty.doc.lower()


# --- validation against real presets ---------------------------------------

def test_eof_without_object_is_reported():
    report = validate_paradigm(resolve_paradigm("EOF"), _preset(), _Options())
    assert report.ok is False
    assert [i.code for i in report.errors] == ["needs_object"]


def test_eof_with_one_object_is_ok():
    assert validate_paradigm(resolve_paradigm("EOF"), _preset(n_objects=1),
                             _Options()).ok


def test_nor_needs_exactly_two_objects():
    nor = resolve_paradigm("NOR")
    assert validate_paradigm(nor, _preset(n_objects=2), _Options()).ok
    assert not validate_paradigm(nor, _preset(n_objects=1), _Options()).ok
    assert not validate_paradigm(nor, _preset(n_objects=3), _Options()).ok


def test_barnes_needs_exactly_one_target():
    barnes = resolve_paradigm("Barnes")
    assert validate_paradigm(barnes, _preset(n_holes=5, n_targets=1), _Options()).ok
    no_target = validate_paradigm(barnes, _preset(n_holes=6), _Options())
    assert [i.code for i in no_target.errors] == ["needs_one_target"]
    two = validate_paradigm(barnes, _preset(n_holes=4, n_targets=2), _Options())
    assert [i.code for i in two.errors] == ["needs_one_target"]


def test_missing_calibration_is_reported_for_every_paradigm():
    for factory in (open_field, enriched_open_field, novel_object_recognition,
                    barnes_maze, ty_maze):
        resolved = resolve_paradigm(factory().name)
        report = validate_paradigm(resolved, _preset(n_objects=2, n_holes=4,
                                                     n_targets=1, n_arms=2),
                                   options=None)
        assert "needs_calibration" in [i.code for i in report.errors]


def test_ty_maze_needs_arms():
    ty = resolve_paradigm("TYMaze")
    assert validate_paradigm(ty, _preset(n_arms=3), _Options()).ok
    assert not validate_paradigm(ty, _preset(n_arms=1), _Options()).ok


def test_registering_builtins_twice_raises_without_replace():
    from sphynx.exceptions import SphynxValueError

    with pytest.raises(SphynxValueError):
        register_builtin_paradigms()
    register_builtin_paradigms(replace=True)     # explicit is fine


# --- M6 review regressions ---

def test_validation_survives_a_preset_zone_array():
    # C1: scipy hands back a numpy object array, whose truthiness is ambiguous;
    # `list(zones or [])` crashed even for OF.
    zones = np.array(_preset(n_objects=1), dtype=object)
    assert validate_paradigm(resolve_paradigm("EOF"), zones, _Options()).ok


def test_validation_tolerates_legacy_zones_without_zone_class():
    class _Legacy:
        name = "old"

    report = validate_paradigm(resolve_paradigm("EOF"), [_Legacy()], _Options())
    assert [i.code for i in report.errors] == ["needs_object"]


def test_eof_documents_what_it_deliberately_omits():
    # I7: the ring-exploration act and the discrimination pair are per-preset /
    # per-session decisions; they must be documented, not silently missing.
    doc = enriched_open_field.__doc__.lower()
    assert "ring" in doc
    assert "ratio_index" in doc          # the pair is a per-session choice


# --- M7: the Barnes paradigm declares its metric set ---

def test_barnes_declares_the_entry_family():
    barnes = resolve_paradigm("Barnes")
    assert [f.name for f in barnes.families] == ["nose_at_hole", "inside_hole"]
    # total latency is measured against an entry, not a nose check
    entry = next(f for f in barnes.families if f.name == "inside_hole")
    assert entry.template.body_part == "bodycenter"


def test_barnes_declares_the_m7_metrics():
    barnes = resolve_paradigm("Barnes")
    names = {m.name for m in barnes.metrics}
    for expected in ("total_latency", "total_errors", "target_checks",
                     "non_target_checks", "time_near_target", "target_ordinal",
                     "angular_distance_first", "mean_angular_distance",
                     "path_length", "path_length_to_target", "search_strategy"):
        assert expected in names


def test_every_barnes_metric_ref_is_registered():
    import sphynx.metrics.barnes  # noqa: F401
    from sphynx.metrics.registry import REGISTRY

    for ref in resolve_paradigm("Barnes").metrics:
        assert ref.name in REGISTRY, f"{ref.name} is referenced but not registered"


def test_barnes_metric_refs_carry_their_family():
    barnes = resolve_paradigm("Barnes")
    by_key = {m.key: m for m in barnes.metrics}
    assert by_key["total_latency"].params["family"] == "inside_hole"
    assert by_key["total_errors"].params["family"] == "nose_at_hole"
    assert by_key["path_length"].params == {}          # trajectory-only metric


def test_primary_latency_is_the_generic_metric_under_a_barnes_alias():
    by_key = {m.key: m for m in resolve_paradigm("Barnes").metrics}
    assert by_key["primary_latency"].name == "latency_to_target"
