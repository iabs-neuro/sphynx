"""Open Field bundle. The S1 stub (builtin_acts/metrics string lists) was
replaced in S2 M6 by the declarative Paradigm model; this file now asserts the
OF bundle in its new shape."""

from sphynx.paradigms import Paradigm, open_field


def test_open_field_bundle():
    of = open_field()
    assert isinstance(of, Paradigm)
    assert of.name == "OF"
    assert of.parent is None                    # OF is the root of the chain


def test_open_field_is_declarative_data():
    of = open_field()
    assert isinstance(of.families, list)
    assert isinstance(of.metrics, list)
    assert isinstance(of.validation, list)
    assert isinstance(of.config_defaults, dict)


def test_open_field_carries_speed_defaults():
    of = open_field()
    assert of.config_defaults["velocity_rest"] == 1.0
    assert of.config_defaults["velocity_locomotion"] == 5.0


def test_open_field_requires_calibration():
    # Without pixels-per-cm every distance and speed would be meaningless.
    assert [r.code for r in open_field().validation] == ["needs_calibration"]


def test_open_field_declares_no_objects():
    # An empty arena: object acts and families belong to EOF, not OF.
    assert open_field().families == []
    assert open_field().composites == []
