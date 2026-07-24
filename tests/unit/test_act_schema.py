import math

from sphynx.acts.schema import Act, build_simple_act, build_complex_act, ActContext


def test_empty_act_defaults():
    a = Act()
    assert a.type == "simple"
    assert a.zone_op == "OR"
    assert a.speed_min == 0 and math.isinf(a.speed_max)
    assert a.min_duration_sec == 0.25 and a.max_gap_sec == 0.25
    assert a.rear_auto_threshold is True


def test_build_simple_act():
    a = build_simple_act(name="rest", body_part="bodycenter", speed_min=0, speed_max=1)
    assert a.type == "simple"
    assert a.name == "rest"
    assert a.body_part == "bodycenter"
    assert a.speed_max == 1
    assert a.zones == []


def test_build_simple_act_string_zone_becomes_list():
    a = build_simple_act(name="c", zones="center", zone_op="and")
    assert a.zones == ["center"]
    assert a.zone_op == "AND"


def test_build_complex_act():
    a = build_complex_act(name="either", components=["a1", "a2"], operation="Union")
    assert a.type == "complex"
    assert a.components == ["a1", "a2"]
    assert a.operation == "union"


def test_act_context_defaults():
    import numpy as np
    ctx = ActContext(X=np.zeros((2, 3)), Y=np.zeros((2, 3)),
                     velocity_cm_s=np.zeros((2, 3)), body_parts=["a", "b"],
                     zones=[], frame_rate=30)
    assert ctx.pixels_per_cm == 1.0
    assert ctx.x_kcorr == 1.0
    assert ctx.all_acts == [] and ctx.results_by_name == {}
