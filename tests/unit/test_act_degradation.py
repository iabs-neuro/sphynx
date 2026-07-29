"""No silent act degradation (S2 M3a, R31#4 defect class).

Every unresolved body part / zone / component must warn and land in
ctx.degraded instead of quietly yielding an all-false act.
"""

import numpy as np

from sphynx.acts import Act, ActContext, apply_act, build_special_act
from sphynx.zones import Zone


def _ctx(body_parts, zones=None, n=20, frame_rate=10.0):
    p = len(body_parts)
    return ActContext(
        X=np.full((p, n), 5.0), Y=np.full((p, n), 5.0),
        velocity_cm_s=np.zeros((p, n)), body_parts=list(body_parts),
        zones=list(zones or []), frame_rate=frame_rate,
    )


def _zone(name="z", shape=(10, 10)):
    m = np.zeros(shape, dtype=bool)
    m[3:8, 3:8] = True
    return Zone(name, "area", m)


def test_clean_act_leaves_degraded_empty():
    ctx = _ctx(["bodycenter"])
    act = Act(name="ok", type="simple", body_part="bodycenter",
              speed_min=-1.0, speed_max=1.0, min_duration_sec=0.0, max_gap_sec=0.0)
    out = apply_act(act, ctx)
    assert out.all()
    assert ctx.degraded == {}


def test_unresolved_body_part_marks_degraded():
    # R31#4 regression: a missing part must not silently produce an all-false act.
    ctx = _ctx(["tailbase"])
    act = Act(name="sniff", type="simple", body_part="nose",
              min_duration_sec=0.0, max_gap_sec=0.0)
    out = apply_act(act, ctx)
    assert not out.any()
    assert "sniff" in ctx.degraded
    assert any("nose" in r for r in ctx.degraded["sniff"])


def test_declared_fallback_records_substitution_and_computes():
    ctx = _ctx(["bodycenter"])
    act = Act(name="sniff", type="simple", body_part="nose",
              fallback={"nose": ["bodycenter"]},
              speed_min=-1.0, speed_max=1.0, min_duration_sec=0.0, max_gap_sec=0.0)
    out = apply_act(act, ctx)
    assert out.all()                       # computed from the substitute
    assert "sniff" in ctx.degraded         # but the substitution is recorded
    assert any("bodycenter" in r for r in ctx.degraded["sniff"])


def test_unknown_zone_marks_degraded():
    ctx = _ctx(["bodycenter"], zones=[_zone("real")])
    act = Act(name="inzone", type="simple", body_part="bodycenter",
              zones=["ghost"], speed_min=-1.0, speed_max=1.0,
              min_duration_sec=0.0, max_gap_sec=0.0)
    apply_act(act, ctx)
    assert "inzone" in ctx.degraded
    assert any("ghost" in r for r in ctx.degraded["inzone"])


def test_unknown_complex_component_marks_degraded():
    ctx = _ctx(["bodycenter"])
    act = Act(name="combo", type="complex", components=["ghost"],
              operation="union", min_duration_sec=0.0, max_gap_sec=0.0)
    apply_act(act, ctx)
    assert "combo" in ctx.degraded
    assert any("ghost" in r for r in ctx.degraded["combo"])


def test_freezing_missing_parts_marks_degraded():
    ctx = _ctx(["tailbase"])
    act = build_special_act("freeze", "freezing", body_parts=["nose"],
                            min_duration_sec=0.0, max_gap_sec=0.0)
    out = apply_act(act, ctx)
    assert not out.any()
    assert "freeze" in ctx.degraded


def test_rears_missing_parts_marks_degraded():
    ctx = _ctx(["bodycenter"])
    act = build_special_act("rear", "rears", rear_mode="TailbasePaws",
                            min_duration_sec=0.0, max_gap_sec=0.0)
    out = apply_act(act, ctx)
    assert not out.any()
    assert "rear" in ctx.degraded


def test_all_in_zone_unknown_zone_marks_degraded():
    ctx = _ctx(["bodycenter"], zones=[_zone("real")])
    act = build_special_act("allin", "allinzone", zones=["ghost"],
                            body_parts=["bodycenter"],
                            min_duration_sec=0.0, max_gap_sec=0.0)
    apply_act(act, ctx)
    assert "allin" in ctx.degraded


# --- M3a review regressions (2 Critical, 5 Important) ---

def test_rear_nan_threshold_marks_degraded():
    # C1: `x < NaN` is False everywhere -- an all-false act that looks real.
    ctx = _ctx(["tailbase", "lefthindlimb", "righthindlimb"])
    act = build_special_act("rear", "rears", rear_mode="TailbasePaws",
                            rear_auto_threshold=False,
                            min_duration_sec=0.0, max_gap_sec=0.0)
    out = apply_act(act, ctx)
    assert not out.any()
    assert "rear" in ctx.degraded
    assert any("threshold" in r for r in ctx.degraded["rear"])


def test_unknown_rear_mode_does_not_drift_into_another_branch():
    # C2 (worst case): a typo used to land in AllBodyParts and could return
    # an all-true act with nothing recorded.
    ctx = _ctx(["bodycenter"])
    act = build_special_act("rear", "rears", rear_mode="TailBasePaws typo",
                            threshold_pxl=1000.0,
                            min_duration_sec=0.0, max_gap_sec=0.0)
    out = apply_act(act, ctx)
    assert not out.any()
    assert any("unknown rear mode" in r for r in ctx.degraded["rear"])


def test_unknown_act_type_marks_degraded():
    ctx = _ctx(["bodycenter"])
    act = Act(name="weird", type="nonsense", min_duration_sec=0.0, max_gap_sec=0.0)
    apply_act(act, ctx)
    assert any("unknown act type" in r for r in ctx.degraded["weird"])


def test_unknown_special_kind_marks_degraded():
    ctx = _ctx(["bodycenter"])
    act = build_special_act("odd", "teleporting", min_duration_sec=0.0, max_gap_sec=0.0)
    apply_act(act, ctx)
    assert any("unknown special kind" in r for r in ctx.degraded["odd"])


def test_unknown_complex_operation_marks_degraded():
    ctx = _ctx(["bodycenter"])
    ctx.results_by_name = {"a": np.ones(20, dtype=bool)}
    act = Act(name="combo", type="complex", components=["a"], operation="frobnicate",
              min_duration_sec=0.0, max_gap_sec=0.0)
    apply_act(act, ctx)
    assert any("unknown complex operation" in r for r in ctx.degraded["combo"])


def test_empty_components_marks_degraded():
    ctx = _ctx(["bodycenter"])
    act = Act(name="combo", type="complex", components=[], operation="union",
              min_duration_sec=0.0, max_gap_sec=0.0)
    apply_act(act, ctx)
    assert any("no components" in r for r in ctx.degraded["combo"])


def test_freezing_without_finite_threshold_marks_degraded():
    # I3: speed_max left at +inf would qualify every frame as freezing.
    ctx = _ctx(["headcenter", "bodycenter"])
    act = build_special_act("freeze", "freezing", min_duration_sec=0.0, max_gap_sec=0.0)
    out = apply_act(act, ctx)
    assert not out.any()
    assert any("speed_max" in r for r in ctx.degraded["freeze"])


def test_freezing_mode_is_honoured():
    # I2: a declared mode must drive the maths, not be ignored.
    ctx = _ctx(["nose", "bodycenter"])
    ctx.velocity_cm_s = np.vstack([np.full(20, 1.5), np.full(20, 0.4)])
    strict = build_special_act("fz_head", "freezing", freezing_mode="HeadAndCenter",
                               speed_max=1.0, min_duration_sec=0.0, max_gap_sec=0.0)
    apply_act(strict, ctx)
    assert "fz_head" in ctx.degraded          # needs headcenter, absent here

    ctx2 = _ctx(["nose", "bodycenter"])
    ctx2.velocity_cm_s = np.vstack([np.full(20, 1.5), np.full(20, 0.4)])
    lenient = build_special_act("fz_nose", "freezing", freezing_mode="NoseAndCenter",
                                speed_max=1.0, min_duration_sec=0.0, max_gap_sec=0.0)
    out = apply_act(lenient, ctx2)
    assert out.all()          # nose 1.5 < 2*1.0 and center 0.4 < 1.0
    assert "fz_nose" not in ctx2.degraded


def test_unknown_freezing_mode_marks_degraded():
    ctx = _ctx(["headcenter", "bodycenter"])
    act = build_special_act("fz", "freezing", freezing_mode="Telepathy",
                            speed_max=1.0, min_duration_sec=0.0, max_gap_sec=0.0)
    out = apply_act(act, ctx)
    assert not out.any()
    assert any("unknown freezing mode" in r for r in ctx.degraded["fz"])


def test_required_parts_are_enforced():
    # I4: required_parts was inert -- nothing read it.
    ctx = _ctx(["bodycenter"])
    act = Act(name="needs", type="simple", body_part="bodycenter",
              required_parts=["nose"], speed_min=-1.0, speed_max=1.0,
              min_duration_sec=0.0, max_gap_sec=0.0)
    out = apply_act(act, ctx)
    assert not out.any()
    assert any("required part" in r for r in ctx.degraded["needs"])
