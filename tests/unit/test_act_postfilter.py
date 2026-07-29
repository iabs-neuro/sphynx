import numpy as np

from sphynx.acts import Act, ActContext, build_special_act


def _ctx(n=40, frame_rate=10.0):
    return ActContext(
        X=np.zeros((1, n)), Y=np.zeros((1, n)),
        velocity_cm_s=np.zeros((1, n)), body_parts=["bodycenter"],
        zones=[], frame_rate=frame_rate,
    )


def test_new_act_fields_default():
    a = Act()
    assert a.required_parts == []
    assert a.fallback == {}
    assert a.median_window_sec == 0.0
    assert a.freezing_mode == ""


def test_act_fields_are_independent_between_instances():
    a, b = Act(), Act()
    a.required_parts.append("nose")
    a.fallback["nose"] = ["head_center"]
    assert b.required_parts == []
    assert b.fallback == {}


def test_build_special_act():
    a = build_special_act("freeze", "freezing", body_parts=["headcenter"],
                          freezing_mode="HeadAndCenter")
    assert a.type == "special"
    assert a.special_kind == "freezing"
    assert a.freezing_mode == "HeadAndCenter"
    assert a.body_parts == ["headcenter"]


def test_median_filter_applied_to_mask(monkeypatch):
    import sphynx.acts.apply as ap

    n = 40
    ctx = _ctx(n)
    spike = np.zeros(n, dtype=bool)
    spike[20] = True
    monkeypatch.setattr(ap, "_apply_simple", lambda act, ctx, n: spike.copy())
    act = Act(name="t", type="simple", median_window_sec=0.5,
              min_duration_sec=0.0, max_gap_sec=0.0)
    out = ap.apply_act(act, ctx)
    assert not out.any()  # isolated spike smoothed away


def test_median_filter_keeps_sustained_run(monkeypatch):
    import sphynx.acts.apply as ap

    n = 40
    ctx = _ctx(n)
    sig = np.zeros(n, dtype=bool)
    sig[10:25] = True
    monkeypatch.setattr(ap, "_apply_simple", lambda act, ctx, n: sig.copy())
    act = Act(name="t", type="simple", median_window_sec=0.5,
              min_duration_sec=0.0, max_gap_sec=0.0)
    out = ap.apply_act(act, ctx)
    assert out.sum() >= 13  # sustained run survives


def test_zero_median_window_is_noop(monkeypatch):
    import sphynx.acts.apply as ap

    n = 20
    ctx = _ctx(n)
    spike = np.zeros(n, dtype=bool)
    spike[10] = True
    monkeypatch.setattr(ap, "_apply_simple", lambda act, ctx, n: spike.copy())
    act = Act(name="t", type="simple", median_window_sec=0.0,
              min_duration_sec=0.0, max_gap_sec=0.0)
    out = ap.apply_act(act, ctx)
    assert out[10]
