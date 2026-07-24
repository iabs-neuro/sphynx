import numpy as np

from sphynx.acts.apply import apply_act, eval_acts_library
from sphynx.acts.schema import Act, ActContext, build_simple_act, build_complex_act
from sphynx.zones import Zone


def _ctx():
    n = 100
    bp = ["nose", "bodycenter", "tailbase", "lefthindlimb", "righthindlimb", "headcenter"]
    h = len(bp)
    x = np.tile(np.arange(1, n + 1) * 5.0, (h, 1))
    y = np.full((h, n), 100.0)
    v = np.zeros((h, n))
    v[:, 0:30] = 0.5    # rest
    v[:, 30:60] = 3     # walk
    v[:, 60:90] = 8     # loc
    v[:, 90:100] = 0.3  # rest tail
    zones = [Zone("arena", "area", np.ones((200, 600), bool))]
    return ActContext(x, y, v, bp, zones, 30, 5)


def test_simple_speed_act():
    a = build_simple_act(name="rest", body_part="bodycenter", speed_min=0, speed_max=1)
    b = apply_act(a, _ctx())
    assert int(b.sum()) == 40   # frames 0:30 + 90:100


def test_complex_union():
    a1 = build_simple_act(name="a1", body_part="bodycenter", speed_min=0, speed_max=1)
    a2 = build_simple_act(name="a2", body_part="bodycenter", speed_min=7, speed_max=float("inf"))
    c = build_complex_act(name="either", components=["a1", "a2"], operation="union")
    res = eval_acts_library([a1, a2, c], _ctx())
    assert "either" in res
    assert int(res["either"].sum()) == 40 + 30


def test_complex_exclude():
    a1 = build_simple_act(name="low", body_part="bodycenter", speed_min=0, speed_max=5)
    a2 = build_simple_act(name="rest_only", body_part="bodycenter", speed_min=0, speed_max=1)
    c = build_complex_act(name="walking", components=["low", "rest_only"], operation="exclude")
    res = eval_acts_library([a1, a2, c], _ctx())
    assert int(res["walking"].sum()) == 30   # only the walk band


def test_freezing_special():
    a = Act(name="freeze", type="special", special_kind="freezing",
            body_parts=["headcenter", "bodycenter"], speed_max=1)
    b = apply_act(a, _ctx())
    assert int(b.sum()) == 40
