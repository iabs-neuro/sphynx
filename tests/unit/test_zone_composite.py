import numpy as np
import pytest

from sphynx.exceptions import SphynxGeometryError, SphynxValueError
from sphynx.zones import Zone, ZoneRoles, ZoneSelector
from sphynx.zones.select import (
    class_composite, make_composite, neutral_composite, target_zone, union_mask,
)


def _m(r0, r1, c0, c1, shape=(8, 12)):
    a = np.zeros(shape, dtype=bool)
    a[r0:r1, c0:c1] = True
    return a


def _zones():
    return [
        Zone("h1", "area", _m(1, 3, 1, 3), zone_class="hole",
             roles=ZoneRoles(is_target=True)),
        Zone("h2", "area", _m(1, 3, 5, 7), zone_class="hole"),
        Zone("h3", "area", _m(1, 3, 9, 11), zone_class="hole"),
        Zone("obj", "area", _m(5, 7, 5, 7), zone_class="object"),
    ]


def test_union_mask_ors():
    zs = _zones()[:2]
    u = union_mask(zs)
    assert u.sum() == zs[0].maskfilled.sum() + zs[1].maskfilled.sum()


def test_union_mask_empty_raises():
    with pytest.raises(SphynxGeometryError):
        union_mask([])


def test_union_mask_shape_mismatch_raises():
    a = Zone("a", "area", np.zeros((8, 12), dtype=bool))
    b = Zone("b", "area", np.zeros((8, 10), dtype=bool))
    with pytest.raises(SphynxGeometryError):
        union_mask([a, b])


def test_make_composite_all_holes():
    c = make_composite("all_holes", _zones(), ZoneSelector(zone_class="hole"))
    assert c.zone_class == "composite"
    assert c.members == ["h1", "h2", "h3"]
    assert c.maskfilled.sum() == 3 * _m(1, 3, 1, 3).sum()


def test_make_composite_empty_selection_raises():
    with pytest.raises(SphynxValueError):
        make_composite("none", _zones(), ZoneSelector(zone_class="wall"))


def test_target_zone_unique():
    t = target_zone(_zones())
    assert t.name == "h1"


def test_target_zone_missing_raises():
    zs = [z for z in _zones() if z.name != "h1"]
    with pytest.raises(SphynxValueError):
        target_zone(zs)


def test_neutral_composite_excludes_target():
    c = neutral_composite("neutral", _zones())
    assert c.members == ["h2", "h3"]


def test_class_composite():
    c = class_composite("holes", _zones(), "hole")
    assert c.members == ["h1", "h2", "h3"]
