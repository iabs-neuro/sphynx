import numpy as np

from sphynx.zones import Zone
from sphynx.zones.geometry import assign_zone_angles, assign_zone_indices


def _block(r0, r1, c0, c1, shape=(30, 30)):
    m = np.zeros(shape, dtype=bool)
    m[r0:r1, c0:c1] = True
    return m


def test_assign_angles_sets_each():
    center = (15.0, 15.0)
    east = Zone("e", "area", _block(14, 17, 24, 27), zone_class="hole")   # x>center
    north = Zone("n", "area", _block(3, 6, 14, 17), zone_class="hole")    # y<center
    zones = [east, north]
    assign_zone_angles(zones, center)
    assert abs(east.angle) < 0.4          # near 0 (east)
    assert north.angle < 0                # negative (north, y up)


def test_assign_indices_per_class():
    zones = [
        Zone("h1", "area", _block(0, 3, 0, 3), zone_class="hole"),
        Zone("o1", "area", _block(0, 3, 5, 8), zone_class="object"),
        Zone("h2", "area", _block(0, 3, 10, 13), zone_class="hole"),
    ]
    assign_zone_indices(zones)
    assert zones[0].index == 1  # first hole
    assert zones[1].index == 1  # first object
    assert zones[2].index == 2  # second hole


def test_assign_angles_skips_empty():
    center = (15.0, 15.0)
    empty = Zone("empty", "area", _block(0, 0, 0, 0), zone_class="hole")
    normal = Zone("n", "area", _block(3, 6, 14, 17), zone_class="hole")
    zones = [empty, normal]
    assign_zone_angles(zones, center)
    assert empty.angle is None  # left untouched
    assert normal.angle is not None  # assigned
