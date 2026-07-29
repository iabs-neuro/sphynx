import numpy as np

from sphynx.zones import Zone, ZoneRoles


def _mask():
    m = np.zeros((10, 10), dtype=bool)
    m[2:5, 2:5] = True
    return m


def test_zone_roles_defaults():
    r = ZoneRoles()
    assert r.is_target is False
    assert r.tags == []


def test_zone_roles_independent_tag_lists():
    a = ZoneRoles()
    a.tags.append("x")
    b = ZoneRoles()
    assert b.tags == []  # no shared mutable default


def test_legacy_positional_construction_still_works():
    z = Zone("arena", "area", _mask())
    assert z.name == "arena"
    assert z.type == "area"
    assert z.zone_class == "unknown"
    assert z.roles.is_target is False
    assert z.index is None
    assert z.angle is None


def test_full_construction():
    z = Zone("target", "area", _mask(), zone_class="hole",
             roles=ZoneRoles(is_target=True, tags=["primary"]), index=3, angle=1.5)
    assert z.zone_class == "hole"
    assert z.roles.is_target is True
    assert z.roles.tags == ["primary"]
    assert z.index == 3
    assert z.angle == 1.5
