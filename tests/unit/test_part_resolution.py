from sphynx.acts.part_resolution import PartResolution, resolve_act_parts
from sphynx.bodyparts.fallbacks import DEFAULT_FALLBACKS


BP = ["nose", "headcenter", "bodycenter", "tailbase"]


def test_all_parts_present_no_degradation():
    r = resolve_act_parts(["nose", "bodycenter"], BP)
    assert isinstance(r, PartResolution)
    assert r.ok is True
    assert r.degraded is False
    assert r.indices["nose"] == 0
    assert r.indices["bodycenter"] == 2
    assert r.substitutions == {}
    assert r.missing == []


def test_declared_fallback_used_and_marks_degraded():
    bp = ["headcenter", "bodycenter"]           # no nose
    r = resolve_act_parts(["nose"], bp, fallback={"nose": ["headcenter"]})
    assert r.ok is True
    assert r.degraded is True
    assert r.indices["nose"] == 0               # index of the substitute
    assert r.substitutions["nose"] == "headcenter"


def test_declared_fallback_walks_chain_in_order():
    bp = ["bodycenter"]                          # neither nose nor headcenter
    r = resolve_act_parts(
        ["nose"], bp, fallback={"nose": ["headcenter", "bodycenter"]})
    assert r.substitutions["nose"] == "bodycenter"
    assert r.indices["nose"] == 0


def test_missing_without_fallback_is_reported_not_substituted():
    bp = ["bodycenter"]
    r = resolve_act_parts(["lefthindlimb"], bp, use_defaults=False)
    assert r.ok is False
    assert r.degraded is True
    assert r.missing == ["lefthindlimb"]
    assert "lefthindlimb" not in r.indices


def test_no_implicit_substitution_without_declared_chain():
    # M3a review (I5 / approved S2 model): without an act-declared chain a
    # missing part is REPORTED, never stood in for. Every substitution shifts
    # the measurement, so none happens implicitly.
    bp = ["headcenter", "bodycenter"]            # no nose
    r = resolve_act_parts(["nose"], bp)
    assert r.ok is False
    assert r.missing == ["nose"]
    assert r.substitutions == {}


def test_suggestion_registry_is_opt_in_and_alias_tolerant():
    # M3a review (I1): the registry is keyed by canonical names but a request
    # may use any alias; consulted only when explicitly asked.
    import sphynx.acts.part_resolution as pr

    bp = ["headcenter"]
    r = resolve_act_parts(["nose"], bp, use_defaults=True)
    assert r.missing == ["nose"]                 # registry ships empty

    original = dict(pr.DEFAULT_FALLBACKS)
    pr.DEFAULT_FALLBACKS["nose"] = ["head_center"]
    try:
        r = resolve_act_parts(["nose"], bp, use_defaults=True)
        assert r.substitutions["nose"] == "head_center"
        assert r.degraded is True
    finally:
        pr.DEFAULT_FALLBACKS.clear()
        pr.DEFAULT_FALLBACKS.update(original)


def test_geometry_critical_never_proxied_even_if_registered():
    # M3a review: a suggestion must not be able to proxy rear geometry.
    import sphynx.acts.part_resolution as pr

    original = dict(pr.DEFAULT_FALLBACKS)
    pr.DEFAULT_FALLBACKS["left_hind_limb"] = ["tailbase"]
    try:
        r = resolve_act_parts(["lefthindlimb"], ["tailbase"], use_defaults=True)
        assert r.missing == ["lefthindlimb"]
        assert r.substitutions == {}
    finally:
        pr.DEFAULT_FALLBACKS.clear()
        pr.DEFAULT_FALLBACKS.update(original)


def test_explicit_fallback_overrides_defaults():
    bp = ["headcenter", "bodycenter"]
    r = resolve_act_parts(["nose"], bp, fallback={"nose": ["bodycenter"]})
    assert r.substitutions["nose"] == "bodycenter"


def test_use_defaults_false_disables_library():
    bp = ["headcenter"]
    r = resolve_act_parts(["nose"], bp, use_defaults=False)
    assert r.ok is False
    assert r.missing == ["nose"]


def test_geometry_critical_parts_have_no_default_chain():
    # Hind limbs and ears must not be silently proxied -- rear/head-angle geometry.
    for part in ("left_hind_limb", "right_hind_limb", "left_ear", "right_ear"):
        assert part not in DEFAULT_FALLBACKS


def test_empty_required_is_ok():
    r = resolve_act_parts([], BP)
    assert r.ok is True
    assert r.degraded is False
