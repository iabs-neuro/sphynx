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
