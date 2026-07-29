import pytest

from sphynx.exceptions import SphynxValueError
from sphynx.paradigms.model import Paradigm
from sphynx.paradigms.validate import (
    ValidationReport, ValidationRule, validate_paradigm,
)
from sphynx.zones import Zone, ZoneRoles

import numpy as np


def _m():
    a = np.zeros((6, 6), dtype=bool)
    a[1:3, 1:3] = True
    return a


def _zones(n_objects=0, n_targets=0, n_holes=0):
    zs = [Zone("arena", "area", _m(), zone_class="arena")]
    for i in range(n_objects):
        zs.append(Zone(f"obj{i}", "area", _m(), zone_class="object"))
    for i in range(n_holes):
        zs.append(Zone(f"hole{i}", "area", _m(), zone_class="hole"))
    for i in range(n_targets):
        zs.append(Zone(f"target{i}", "area", _m(), zone_class="hole",
                       roles=ZoneRoles(is_target=True)))
    return zs


class _Options:
    def __init__(self, pxl2sm=22.2):
        self.pxl2sm = pxl2sm


def _paradigm(*rules):
    return Paradigm(name="Test", validation=list(rules))


OBJECT_MIN1 = ValidationRule(code="needs_object", kind="zone_count",
                             zone_class="object", min=1,
                             message="this paradigm needs at least one object")
OBJECT_EXACT2 = ValidationRule(code="needs_two_objects", kind="zone_count",
                               zone_class="object", min=2, max=2)
ONE_TARGET = ValidationRule(code="needs_one_target", kind="target_count",
                            min=1, max=1)
CALIBRATED = ValidationRule(code="needs_calibration", kind="calibration")


def test_clean_setup_is_ok():
    report = validate_paradigm(_paradigm(OBJECT_MIN1), _zones(n_objects=1),
                               _Options())
    assert isinstance(report, ValidationReport)
    assert report.ok is True
    assert report.issues == []


def test_missing_object_is_reported_not_raised():
    report = validate_paradigm(_paradigm(OBJECT_MIN1), _zones(n_objects=0))
    assert report.ok is False
    assert [i.code for i in report.errors] == ["needs_object"]
    assert "at least one object" in report.errors[0].message


def test_exact_count_rule_flags_too_many():
    report = validate_paradigm(_paradigm(OBJECT_EXACT2), _zones(n_objects=3))
    assert report.ok is False
    assert report.errors[0].code == "needs_two_objects"


def test_exact_count_rule_accepts_the_right_number():
    assert validate_paradigm(_paradigm(OBJECT_EXACT2), _zones(n_objects=2)).ok


def test_target_rule_requires_exactly_one():
    assert validate_paradigm(_paradigm(ONE_TARGET), _zones(n_targets=1)).ok
    assert not validate_paradigm(_paradigm(ONE_TARGET), _zones(n_targets=0)).ok
    assert not validate_paradigm(_paradigm(ONE_TARGET), _zones(n_targets=2)).ok


def test_calibration_rule():
    assert validate_paradigm(_paradigm(CALIBRATED), _zones(), _Options()).ok
    assert not validate_paradigm(_paradigm(CALIBRATED), _zones(), None).ok
    assert not validate_paradigm(_paradigm(CALIBRATED), _zones(),
                                 _Options(pxl2sm=0)).ok


def test_warning_level_does_not_fail_the_report():
    rule = ValidationRule(code="soft", kind="zone_count", zone_class="object",
                          min=1, level="warning")
    report = validate_paradigm(_paradigm(rule), _zones(n_objects=0))
    assert report.ok is True
    assert [i.code for i in report.warnings] == ["soft"]


def test_several_rules_all_reported():
    report = validate_paradigm(_paradigm(OBJECT_MIN1, ONE_TARGET, CALIBRATED),
                               _zones(), None)
    assert len(report.errors) == 3


def test_report_names_the_paradigm():
    report = validate_paradigm(_paradigm(OBJECT_MIN1), _zones())
    assert report.paradigm == "Test"


def test_unknown_rule_kind_raises():
    bad = ValidationRule(code="weird", kind="teleportation")
    with pytest.raises(SphynxValueError):
        validate_paradigm(_paradigm(bad), _zones())


def test_default_message_is_informative_when_none_given():
    rule = ValidationRule(code="c", kind="zone_count", zone_class="object", min=2)
    report = validate_paradigm(_paradigm(rule), _zones(n_objects=1))
    msg = report.errors[0].message
    assert "object" in msg and "2" in msg and "1" in msg


def test_paradigm_without_rules_is_ok():
    assert validate_paradigm(Paradigm(name="Free"), _zones()).ok
