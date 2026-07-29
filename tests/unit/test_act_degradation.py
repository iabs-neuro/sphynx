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
