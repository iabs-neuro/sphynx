import numpy as np

from sphynx.acts.refine import refine_act_array


def _b(lst):
    return np.array(lst, dtype=bool)


def test_zero_params_unchanged():
    x = _b([1, 1, 0, 1, 0, 0, 1, 1, 1, 0, 1])
    assert np.array_equal(refine_act_array(x, 0, 0), x)


def test_drops_runs_shorter_than_min():
    x = _b([1, 0, 1, 1, 0, 1, 1, 1, 0, 0, 1])
    assert np.array_equal(refine_act_array(x, 3, 0), _b([0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0]))


def test_keeps_run_of_exactly_min_length():
    x = _b([0, 1, 1, 1, 0])
    assert np.array_equal(refine_act_array(x, 3, 0), x)


def test_bridges_short_gap():
    x = _b([0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0])
    assert np.array_equal(refine_act_array(x, 0, 3),
                          _b([0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0]))


def test_leading_zeros_not_bridged():
    x = _b([0, 0, 0, 0, 1, 1, 1, 0])
    assert np.array_equal(refine_act_array(x, 0, 100), x)


def test_run_touching_last_frame_kept():
    x = _b([0, 0, 1, 1, 1])
    assert np.array_equal(refine_act_array(x, 3, 0), x)


def test_empty_returns_empty():
    out = refine_act_array(np.array([], dtype=bool), 5, 5)
    assert out.size == 0 and out.dtype == bool


def test_bridge_before_drop_consolidates():
    x = _b([1, 1, 0, 0, 1, 1, 1, 1, 1, 0])
    assert np.array_equal(refine_act_array(x, 4, 4), _b([1, 1, 1, 1, 1, 1, 1, 1, 1, 0]))
