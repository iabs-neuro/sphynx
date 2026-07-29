import numpy as np

from sphynx.zones import Zone, ZoneRoles, ZoneSelector, select


def _m():
    a = np.zeros((8, 8), dtype=bool)
    a[1:3, 1:3] = True
    return a


def _zones():
    return [
        Zone("h1", "area", _m(), zone_class="hole",
             roles=ZoneRoles(is_target=True, tags=["primary"])),
        Zone("h2", "area", _m(), zone_class="hole", roles=ZoneRoles(is_target=False)),
        Zone("h3", "area", _m(), zone_class="hole", roles=ZoneRoles(is_target=False)),
        Zone("obj", "area", _m(), zone_class="object"),
    ]


def test_select_by_class():
    got = select(_zones(), ZoneSelector(zone_class="hole"))
    assert [z.name for z in got] == ["h1", "h2", "h3"]


def test_select_target_hole():
    got = select(_zones(), ZoneSelector(zone_class="hole", is_target=True))
    assert [z.name for z in got] == ["h1"]


def test_select_neutral_holes():
    got = select(_zones(), ZoneSelector(zone_class="hole", is_target=False))
    assert [z.name for z in got] == ["h2", "h3"]


def test_select_by_tag():
    got = select(_zones(), ZoneSelector(tags_any=["primary"]))
    assert [z.name for z in got] == ["h1"]


def test_selector_dontcare_matches_all():
    got = select(_zones(), ZoneSelector())
    assert len(got) == 4


def test_select_by_index():
    # M2 review (Important): index is a selection dimension.
    zs = _zones()
    zs[0].index = 1
    zs[1].index = 2
    zs[2].index = 3
    got = select(zs, ZoneSelector(zone_class="hole", index=2))
    assert [z.name for z in got] == ["h2"]


def test_empty_tags_any_is_dontcare():
    # M2 review (Minor): empty tag lists are don't-care on both sides.
    assert len(select(_zones(), ZoneSelector(tags_any=[]))) == 4
    assert len(select(_zones(), ZoneSelector(tags_all=[]))) == 4


def test_str_tags_raises():
    # M2 review (Minor): a bare string must not silently decompose to chars.
    import pytest

    from sphynx.exceptions import SphynxValueError

    with pytest.raises(SphynxValueError):
        select(_zones(), ZoneSelector(tags_any="primary"))


def test_zone_members_defaults_empty():
    assert Zone("x", "area", _m()).members == []
