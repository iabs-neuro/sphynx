"""Complex acts evaluate through the expression tree (S2 M3b Task 2).

One evaluation path: an explicit Act.expr wins, otherwise the flat
components/operation model is migrated on the fly. References resolve as a DAG;
cycles raise; unresolvable references are recorded, never silent.
"""

import numpy as np
import pytest

from sphynx.acts import Act, ActContext, apply_act, build_complex_act
from sphynx.acts.expr import Exclude, Leaf, Or
from sphynx.exceptions import SphynxValueError

N = 10


def _ctx(**kw):
    ctx = ActContext(
        X=np.zeros((1, N)), Y=np.zeros((1, N)), velocity_cm_s=np.zeros((1, N)),
        body_parts=["bodycenter"], zones=[], frame_rate=10.0,
    )
    for k, v in kw.items():
        setattr(ctx, k, v)
    return ctx


def _masks():
    a = np.zeros(N, dtype=bool)
    a[2:5] = True
    b = np.zeros(N, dtype=bool)
    b[4:7] = True
    return {"a": a, "b": b}


def test_explicit_expr_tree_evaluates():
    ctx = _ctx(results_by_name=_masks())
    act = Act(name="tree", type="complex",
              expr=Exclude(Or([Leaf("a"), Leaf("b")]), Leaf("a")),
              min_duration_sec=0.0, max_gap_sec=0.0)
    out = apply_act(act, ctx)
    assert np.flatnonzero(out).tolist() == [5, 6]
    assert ctx.degraded == {}


def test_flat_union_still_works():
    ctx = _ctx(results_by_name=_masks())
    act = build_complex_act(name="u", components=["a", "b"], operation="union",
                            min_duration_sec=0.0, max_gap_sec=0.0)
    out = apply_act(act, ctx)
    assert np.flatnonzero(out).tolist() == [2, 3, 4, 5, 6]


def test_flat_exclude_still_works():
    ctx = _ctx(results_by_name=_masks())
    act = build_complex_act(name="x", components=["a", "b"], operation="exclude",
                            min_duration_sec=0.0, max_gap_sec=0.0)
    out = apply_act(act, ctx)
    assert np.flatnonzero(out).tolist() == [2, 3]


def test_leaf_resolves_recursively_through_all_acts():
    # "a" is not precomputed: it must be found in ctx.all_acts and evaluated.
    inner = Act(name="a", type="simple", body_part="bodycenter",
                speed_min=-1.0, speed_max=1.0,
                min_duration_sec=0.0, max_gap_sec=0.0)
    outer = Act(name="outer", type="complex", expr=Leaf("a"),
                min_duration_sec=0.0, max_gap_sec=0.0)
    ctx = _ctx(all_acts=[inner, outer])
    out = apply_act(outer, ctx)
    assert out.all()                       # inner is true everywhere
    assert "a" in ctx.results_by_name      # memoised for reuse


def test_unresolvable_reference_marks_degraded():
    ctx = _ctx()
    act = Act(name="combo", type="complex", expr=Leaf("ghost"),
              min_duration_sec=0.0, max_gap_sec=0.0)
    out = apply_act(act, ctx)
    assert not out.any()
    assert any("ghost" in r for r in ctx.degraded["combo"])


def test_reference_cycle_raises():
    a = Act(name="a", type="complex", expr=Leaf("b"),
            min_duration_sec=0.0, max_gap_sec=0.0)
    b = Act(name="b", type="complex", expr=Leaf("a"),
            min_duration_sec=0.0, max_gap_sec=0.0)
    ctx = _ctx(all_acts=[a, b])
    with pytest.raises(SphynxValueError):
        apply_act(a, ctx)


def test_self_reference_raises():
    a = Act(name="a", type="complex", expr=Leaf("a"),
            min_duration_sec=0.0, max_gap_sec=0.0)
    ctx = _ctx(all_acts=[a])
    with pytest.raises(SphynxValueError):
        apply_act(a, ctx)


def test_existing_degradation_messages_preserved():
    ctx = _ctx()
    empty = Act(name="e", type="complex", components=[], operation="union",
                min_duration_sec=0.0, max_gap_sec=0.0)
    apply_act(empty, ctx)
    assert any("no components" in r for r in ctx.degraded["e"])

    ctx2 = _ctx(results_by_name=_masks())
    weird = Act(name="w", type="complex", components=["a"], operation="frobnicate",
                min_duration_sec=0.0, max_gap_sec=0.0)
    apply_act(weird, ctx2)
    assert any("unknown complex operation" in r for r in ctx2.degraded["w"])


# --- M3b review regressions (4 Important) ---

def test_degraded_referent_degrades_the_referring_act():
    # I3: a composed act must not come back empty with a clean record.
    inner = Act(name="inner", type="simple", body_part="nose",   # absent part
                min_duration_sec=0.0, max_gap_sec=0.0)
    outer = Act(name="outer", type="complex", expr=Leaf("inner"),
                min_duration_sec=0.0, max_gap_sec=0.0)
    ctx = _ctx(all_acts=[inner, outer])
    out = apply_act(outer, ctx)
    assert not out.any()
    assert "inner" in ctx.degraded
    assert any("inner" in r for r in ctx.degraded["outer"])


def test_wrong_length_reference_is_reported_not_broadcast():
    # I2: a length-1 mask used to broadcast silently over the whole session.
    ctx = _ctx(results_by_name={"scalarish": np.ones(1, dtype=bool)})
    act = Act(name="combo", type="complex", expr=Or([Leaf("scalarish")]),
              min_duration_sec=0.0, max_gap_sec=0.0)
    out = apply_act(act, ctx)
    assert not out.any()
    assert any("expected" in r for r in ctx.degraded["combo"])


def test_exclude_without_subtract_is_reported():
    # I1: a dropped subtract side yields an over-broad act.
    ctx = _ctx(results_by_name=_masks())
    act = Act(name="halfx", type="complex", expr=Exclude(Leaf("a"), None),
              min_duration_sec=0.0, max_gap_sec=0.0)
    out = apply_act(act, ctx)
    assert out.tolist() == _masks()["a"].tolist()      # base passes through
    assert any("subtract" in r for r in ctx.degraded["halfx"])


def test_reason_recorded_once_per_act():
    # Minor: an act referenced twice degrades once.
    ctx = _ctx(results_by_name=_masks())
    act = Act(name="combo", type="complex",
              expr=Or([Leaf("ghost"), Leaf("ghost")]),
              min_duration_sec=0.0, max_gap_sec=0.0)
    apply_act(act, ctx)
    assert len(ctx.degraded["combo"]) == 1


def test_leaf_result_is_not_a_view_of_the_memo():
    ctx = _ctx(results_by_name=_masks())
    act = Act(name="passthru", type="complex", expr=Or([Leaf("a")]),
              min_duration_sec=0.0, max_gap_sec=0.0)
    out = apply_act(act, ctx)
    out[:] = False
    assert ctx.results_by_name["a"].any()   # memo untouched
