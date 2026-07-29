import numpy as np
import pytest

from sphynx.acts import Act, ActFamily, expand_family
from sphynx.exceptions import SphynxValueError
from sphynx.zones import Zone, ZoneRoles, ZoneSelector
from sphynx.zones.geometry import assign_zone_indices


def _m():
    a = np.zeros((8, 8), dtype=bool)
    a[1:3, 1:3] = True
    return a


def _zones():
    zs = [
        Zone("hole_a", "area", _m(), zone_class="hole"),
        Zone("hole_b", "area", _m(), zone_class="hole",
             roles=ZoneRoles(is_target=True)),
        Zone("hole_c", "area", _m(), zone_class="hole"),
        Zone("obj", "area", _m(), zone_class="object"),
    ]
    assign_zone_indices(zs)
    return zs


def _family(**kw):
    template = Act(name="template", type="simple", body_part="nose",
                   min_duration_sec=0.0, max_gap_sec=0.0)
    kw.setdefault("name", "nose_at_hole")
    kw.setdefault("selector", ZoneSelector(zone_class="hole"))
    kw.setdefault("template", template)
    return ActFamily(**kw)


def test_expands_one_act_per_matching_zone():
    acts = expand_family(_family(), _zones())
    assert len(acts) == 3                       # three holes, not the object
    assert [a.name for a in acts] == [
        "nose_at_hole1", "nose_at_hole2", "nose_at_hole3"]


def test_each_act_binds_its_own_zone():
    acts = expand_family(_family(), _zones())
    assert [a.zones for a in acts] == [["hole_a"], ["hole_b"], ["hole_c"]]


def test_provenance_carries_zone_identity_and_roles():
    acts = expand_family(_family(), _zones())
    assert [a.zone_name for a in acts] == ["hole_a", "hole_b", "hole_c"]
    assert [a.zone_index for a in acts] == [1, 2, 3]
    assert [a.is_target for a in acts] == [False, True, False]
    assert all(a.family == "nose_at_hole" for a in acts)


def test_template_fields_are_inherited():
    acts = expand_family(_family(), _zones())
    assert all(a.body_part == "nose" for a in acts)
    assert all(a.type == "simple" for a in acts)


def test_expansion_deep_copies_mutable_template_fields():
    template = Act(name="t", type="simple", body_part="nose",
                   required_parts=["nose"], fallback={"nose": ["headcenter"]})
    acts = expand_family(_family(template=template), _zones())
    acts[0].required_parts.append("tailbase")
    acts[0].fallback["nose"].append("bodycenter")
    assert acts[1].required_parts == ["nose"]
    assert acts[1].fallback["nose"] == ["headcenter"]
    assert template.required_parts == ["nose"]


def test_family_count_follows_the_geometry_not_a_constant():
    # The point of the milestone: no NumObjects hardcode.
    zs = _zones()[:2] + [Zone("hole_d", "area", _m(), zone_class="hole")]
    assign_zone_indices(zs)
    assert len(expand_family(_family(), zs)) == 3
    assert len(expand_family(_family(), _zones())) == 3


def test_role_selector_expands_to_the_target_only():
    fam = _family(name="nose_at_target",
                  selector=ZoneSelector(zone_class="hole", is_target=True))
    acts = expand_family(fam, _zones())
    assert len(acts) == 1
    assert acts[0].zone_name == "hole_b"
    assert acts[0].is_target is True


def test_custom_name_pattern():
    fam = _family(name_pattern="{family}_{zone}")
    acts = expand_family(fam, _zones())
    assert acts[0].name == "nose_at_hole_hole_a"


def test_empty_selection_raises():
    fam = _family(selector=ZoneSelector(zone_class="wall"))
    with pytest.raises(SphynxValueError):
        expand_family(fam, _zones())


def test_missing_zone_index_falls_back_to_position():
    zs = [Zone("h1", "area", _m(), zone_class="hole"),
          Zone("h2", "area", _m(), zone_class="hole")]      # indices never assigned
    acts = expand_family(_family(), zs)
    assert [a.zone_index for a in acts] == [1, 2]


# --- M4 review regressions (1 Critical, 6 Important) ---

def test_name_collision_raises():
    # C1: two members rendering the same act name would make results (keyed by
    # name) drop one mask and read the other twice under two zone labels.
    zs = [Zone("hole_x", "area", _m(), zone_class="hole"),
          Zone("obj_x", "area", _m(), zone_class="object")]
    assign_zone_indices(zs)                      # per-class -> both get index 1
    fam = _family(selector=ZoneSelector())       # spans both classes
    with pytest.raises(SphynxValueError):
        expand_family(fam, zs)


def test_name_pattern_with_zone_avoids_collision():
    zs = [Zone("hole_x", "area", _m(), zone_class="hole"),
          Zone("obj_x", "area", _m(), zone_class="object")]
    assign_zone_indices(zs)
    fam = _family(selector=ZoneSelector(), name_pattern="{family}_{zone}")
    acts = expand_family(fam, zs)
    assert [a.name for a in acts] == ["nose_at_hole_hole_x", "nose_at_hole_obj_x"]


def test_unnamed_family_raises():
    with pytest.raises(SphynxValueError):
        expand_family(_family(name=""), _zones())


def test_duplicate_zone_names_raise():
    zs = [Zone("dup", "area", _m(), zone_class="hole"),
          Zone("dup", "area", _m(), zone_class="hole")]
    assign_zone_indices(zs)
    with pytest.raises(SphynxValueError):
        expand_family(_family(), zs)


def test_complex_template_raises():
    # I4: a complex/expr template ignores its zone binding, so every member
    # would be identical under a different label.
    from sphynx.acts.expr import Leaf

    tmpl = Act(name="t", type="complex", expr=Leaf("other"))
    with pytest.raises(SphynxValueError):
        expand_family(_family(template=tmpl), _zones())
