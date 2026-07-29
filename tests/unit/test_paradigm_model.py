import pytest

from sphynx.acts import Act, ActFamily
from sphynx.exceptions import SphynxValueError
from sphynx.paradigms.model import CompositeSpec, MetricRef, Paradigm
from sphynx.paradigms.registry import (
    PARADIGMS, get_paradigm, register_paradigm, resolve_paradigm,
)
from sphynx.zones import ZoneSelector


@pytest.fixture(autouse=True)
def _isolate():
    saved = dict(PARADIGMS)
    PARADIGMS.clear()
    yield
    PARADIGMS.clear()
    PARADIGMS.update(saved)


def _fam(name, zone_class):
    return ActFamily(name=name, selector=ZoneSelector(zone_class=zone_class),
                     template=Act(name="t", type="simple", body_part="nose"))


def test_register_and_get():
    p = Paradigm(name="Base")
    register_paradigm(p)
    assert get_paradigm("Base") is p


def test_unknown_paradigm_raises():
    with pytest.raises(SphynxValueError):
        get_paradigm("Nope")


def test_duplicate_registration_raises():
    register_paradigm(Paradigm(name="Dup"))
    with pytest.raises(SphynxValueError):
        register_paradigm(Paradigm(name="Dup"))


def test_duplicate_allowed_when_explicit():
    register_paradigm(Paradigm(name="Dup", doc="first"))
    register_paradigm(Paradigm(name="Dup", doc="second"), replace=True)
    assert get_paradigm("Dup").doc == "second"


def test_child_inherits_parent_content():
    register_paradigm(Paradigm(
        name="Base", metrics=[MetricRef("distance")],
        config_defaults={"velocity_rest": 1.0}, families=[_fam("f1", "object")]))
    register_paradigm(Paradigm(name="Child", parent="Base",
                               metrics=[MetricRef("ratio_index")]))
    r = resolve_paradigm("Child")
    assert r.name == "Child"
    assert r.parent is None                       # flattened
    assert [m.name for m in r.metrics] == ["distance", "ratio_index"]
    assert r.config_defaults == {"velocity_rest": 1.0}
    assert [f.name for f in r.families] == ["f1"]


def test_child_overrides_same_named_entries():
    register_paradigm(Paradigm(
        name="Base", metrics=[MetricRef("m", {"family": "parent_fam"})],
        config_defaults={"velocity_rest": 1.0, "keep": 2.0}))
    register_paradigm(Paradigm(
        name="Child", parent="Base",
        metrics=[MetricRef("m", {"family": "child_fam"})],
        config_defaults={"velocity_rest": 9.0}))
    r = resolve_paradigm("Child")
    assert len(r.metrics) == 1
    assert r.metrics[0].params == {"family": "child_fam"}
    assert r.config_defaults == {"velocity_rest": 9.0, "keep": 2.0}


def test_three_level_chain():
    register_paradigm(Paradigm(name="A", metrics=[MetricRef("a")]))
    register_paradigm(Paradigm(name="B", parent="A", metrics=[MetricRef("b")]))
    register_paradigm(Paradigm(name="C", parent="B", metrics=[MetricRef("c")]))
    r = resolve_paradigm("C")
    assert [m.name for m in r.metrics] == ["a", "b", "c"]


def test_composites_merge_by_name():
    register_paradigm(Paradigm(name="A", composites=[
        CompositeSpec("all_holes", ZoneSelector(zone_class="hole"))]))
    register_paradigm(Paradigm(name="B", parent="A", composites=[
        CompositeSpec("all_holes", ZoneSelector(zone_class="hole", is_target=False)),
        CompositeSpec("objects", ZoneSelector(zone_class="object"))]))
    r = resolve_paradigm("B")
    assert [c.name for c in r.composites] == ["all_holes", "objects"]
    assert r.composites[0].selector.is_target is False    # child won


def test_unknown_parent_raises():
    register_paradigm(Paradigm(name="Orphan", parent="Ghost"))
    with pytest.raises(SphynxValueError):
        resolve_paradigm("Orphan")


def test_parent_cycle_raises():
    register_paradigm(Paradigm(name="X", parent="Y"))
    register_paradigm(Paradigm(name="Y", parent="X"))
    with pytest.raises(SphynxValueError):
        resolve_paradigm("X")


def test_resolve_accepts_a_paradigm_object():
    register_paradigm(Paradigm(name="Base", metrics=[MetricRef("distance")]))
    r = resolve_paradigm(Paradigm(name="Ad hoc", parent="Base"))
    assert [m.name for m in r.metrics] == ["distance"]


def test_resolving_does_not_mutate_the_registered_paradigms():
    register_paradigm(Paradigm(name="Base", metrics=[MetricRef("a")]))
    register_paradigm(Paradigm(name="Child", parent="Base",
                               metrics=[MetricRef("b")]))
    resolve_paradigm("Child")
    assert [m.name for m in get_paradigm("Base").metrics] == ["a"]
    assert [m.name for m in get_paradigm("Child").metrics] == ["b"]
