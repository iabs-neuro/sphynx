import numpy as np
import pytest

from sphynx.acts.builtins import freezing
from sphynx.bodyparts import Point
from sphynx.exceptions import SphynxValueError


def test_head_and_center_freeze_band():
    n = 100
    bpv = np.full((2, n), 5.0)
    bpv[:, 10:40] = 0.5   # both parts slow -> freeze
    p = Point(head_center=0, center=1)
    fm = freezing(bpv, p, "HeadAndCenter", 1, 5)
    assert int(fm.sum()) == 30


def test_degrades_to_all_body_parts():
    n = 50
    bpv = np.full((3, n), 0.1)  # sum 0.3 < 1*3
    fm = freezing(bpv, Point(), "HeadAndCenter", 1, 3)  # no head/center -> AllBodyParts
    assert fm.all()


def test_unknown_mode_raises():
    with pytest.raises(SphynxValueError):
        freezing(np.zeros((2, 10)), Point(), "Bogus", 1, 5)
