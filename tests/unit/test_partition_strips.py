import numpy as np
import pytest

from sphynx.zones import partition_strips, Zone
from sphynx.exceptions import SphynxValueError


def test_three_horizontal_strips():
    zones = partition_strips(np.ones((30, 60), bool), 3, "horizontal")
    assert len(zones) == 3
    assert zones[0].name == "strip1"
    for z in zones:
        assert 30 * 60 / 3 - 60 < z.maskfilled.sum() < 30 * 60 / 3 + 60


def test_two_vertical_strips():
    zones = partition_strips(np.ones((20, 40), bool), 2, "vertical")
    assert len(zones) == 2
    assert zones[0].maskfilled[9, 4]      # left half
    assert not zones[0].maskfilled[9, 34]
    assert zones[1].maskfilled[9, 34]     # right half
    assert not zones[1].maskfilled[9, 4]


def test_rejects_zero_strips():
    with pytest.raises(SphynxValueError):
        partition_strips(np.ones((10, 10), bool), 0, "horizontal")


def test_rejects_unknown_direction():
    with pytest.raises(SphynxValueError):
        partition_strips(np.ones((10, 10), bool), 3, "diagonal")


def test_strips_partition_arena():
    m = np.zeros((20, 30), bool)
    m[4:15, 4:25] = True
    zones = partition_strips(m, 4, "horizontal")
    summed = np.zeros((20, 30), bool)
    for z in zones:
        assert not (summed & z.maskfilled).any()
        summed |= z.maskfilled
    assert np.array_equal(summed, m)
