import numpy as np
import pytest

from sphynx.acts.expr import (
    And, Exclude, Leaf, Or, Sequence, eval_expr, from_flat,
)
from sphynx.acts.schema import build_complex_act
from sphynx.exceptions import SphynxValueError

N = 10
FPS = 10.0


def _table():
    a = np.zeros(N, dtype=bool)
    a[2:5] = True                 # frames 2,3,4
    b = np.zeros(N, dtype=bool)
    b[4:7] = True                 # frames 4,5,6
    return {"a": a, "b": b}


def _sink():
    errs = []
    return errs, errs.append


def _ev(expr, table=None, fps=FPS):
    table = _table() if table is None else table
    errs, on_error = _sink()
    out = eval_expr(expr, N, lambda nm: table.get(nm), fps, on_error)
    return out, errs


def test_leaf_resolves():
    out, errs = _ev(Leaf("a"))
    assert out.tolist() == _table()["a"].tolist()
    assert errs == []


def test_unresolvable_leaf_records_error():
    out, errs = _ev(Leaf("ghost"))
    assert not out.any()
    assert any("ghost" in e for e in errs)


def test_or_unions():
    out, _ = _ev(Or([Leaf("a"), Leaf("b")]))
    assert np.flatnonzero(out).tolist() == [2, 3, 4, 5, 6]


def test_and_intersects():
    out, _ = _ev(And([Leaf("a"), Leaf("b")]))
    assert np.flatnonzero(out).tolist() == [4]


def test_exclude_subtracts():
    out, _ = _ev(Exclude(Leaf("a"), Leaf("b")))
    assert np.flatnonzero(out).tolist() == [2, 3]


def test_nested_tree():
    # (a OR b) EXCLUDE a  ==  b minus a
    out, _ = _ev(Exclude(Or([Leaf("a"), Leaf("b")]), Leaf("a")))
    assert np.flatnonzero(out).tolist() == [5, 6]


def test_empty_or_records_error():
    out, errs = _ev(Or([]))
    assert not out.any()
    assert errs


def test_empty_expression_records_error():
    out, errs = _ev(None)
    assert not out.any()
    assert errs


def test_unknown_node_records_error():
    out, errs = _ev(object())
    assert not out.any()
    assert any("unknown expression node" in e for e in errs)


def test_sequence_fires_when_second_follows_within_window():
    # a ends at frame 4; b starts at 4. With a 0.3 s window (3 frames at 10 fps)
    # b at 5 and 6 follow a-frames within the window.
    out, errs = _ev(Sequence([Leaf("a"), Leaf("b")], [0.3]))
    assert out.any()
    assert errs == []


def test_sequence_misses_when_gap_too_long():
    table = {"a": np.zeros(N, dtype=bool), "b": np.zeros(N, dtype=bool)}
    table["a"][0] = True
    table["b"][9] = True
    out, _ = _ev(Sequence([Leaf("a"), Leaf("b")], [0.2]), table=table)
    assert not out.any()


def test_sequence_needs_two_steps():
    out, errs = _ev(Sequence([Leaf("a")], []))
    assert not out.any()
    assert errs


def test_sequence_delay_count_mismatch_raises():
    with pytest.raises(SphynxValueError):
        _ev(Sequence([Leaf("a"), Leaf("b"), Leaf("a")], [0.1, 0.2, 0.3]))


def test_sequence_single_delay_applies_to_every_hop():
    table = {"a": np.zeros(N, dtype=bool), "b": np.zeros(N, dtype=bool),
             "c": np.zeros(N, dtype=bool)}
    table["a"][0] = True
    table["b"][1] = True
    table["c"][2] = True
    out, errs = _ev(Sequence([Leaf("a"), Leaf("b"), Leaf("c")], [0.2]), table=table)
    assert out[2]
    assert errs == []


def test_from_flat_union():
    act = build_complex_act(name="u", components=["a", "b"], operation="union")
    e = from_flat(act)
    assert isinstance(e, Or)
    assert [c.act_ref for c in e.children] == ["a", "b"]


def test_from_flat_intersect():
    act = build_complex_act(name="i", components=["a", "b"], operation="intersect")
    assert isinstance(from_flat(act), And)


def test_from_flat_exclude_multi_subtracts_union():
    act = build_complex_act(name="x", components=["a", "b", "c"], operation="exclude")
    e = from_flat(act)
    assert isinstance(e, Exclude)
    assert e.base.act_ref == "a"
    assert isinstance(e.subtract, Or)
    assert [c.act_ref for c in e.subtract.children] == ["b", "c"]


def test_from_flat_sequence_carries_delay_per_hop():
    act = build_complex_act(name="s", components=["a", "b", "c"],
                            operation="sequence", seq_delay_sec=0.4)
    e = from_flat(act)
    assert isinstance(e, Sequence)
    assert e.delays_sec == [0.4, 0.4]


def test_from_flat_single_component_degenerates_to_leaf():
    act = build_complex_act(name="one", components=["a"], operation="exclude")
    assert isinstance(from_flat(act), Leaf)


def test_from_flat_unknown_operation_is_none():
    act = build_complex_act(name="q", components=["a", "b"], operation="frobnicate")
    assert from_flat(act) is None


def test_from_flat_no_components_is_none():
    act = build_complex_act(name="empty", components=[], operation="union")
    assert from_flat(act) is None


def test_non_finite_sequence_delay_raises():
    # M3b review (I4): NaN/inf delays would surface as a bare ValueError or
    # OverflowError from the window arithmetic.
    import math

    for bad in (float("nan"), math.inf):
        with pytest.raises(SphynxValueError):
            _ev(Sequence([Leaf("a"), Leaf("b")], [bad]))
