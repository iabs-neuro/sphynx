import numpy as np

from sphynx.acts.refine import refine_act, Run


def test_noop_when_runs_long_enough():
    x = np.array([0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0])
    out, runs = refine_act(x, 2, 2)
    assert np.array_equal(out, x.astype(bool))
    assert len(runs) == 2


def test_drops_short_one_run():
    x = np.array([0, 0, 1, 0, 0, 1, 1, 1, 1, 0])
    out, runs = refine_act(x, 2, 0)
    assert np.array_equal(out, np.array([0, 0, 0, 0, 0, 1, 1, 1, 1, 0], bool))
    assert len(runs) == 1


def test_closes_short_gap():
    out, _ = refine_act(np.array([1, 1, 1, 0, 1, 1, 1]), 1, 2)
    assert np.array_equal(out, np.ones(7, bool))


def test_does_not_close_leading_zeros():
    out, _ = refine_act(np.array([0, 1, 1, 1]), 1, 2)
    assert np.array_equal(out, np.array([0, 1, 1, 1], bool))


def test_run_frame_indices_zero_based():
    _, runs = refine_act(np.array([0, 1, 1, 0, 0, 1, 1, 1]), 1, 0)
    assert (runs[0].frame_in, runs[0].frame_out, runs[0].duration) == (1, 2, 2)
    assert (runs[1].frame_in, runs[1].frame_out, runs[1].duration) == (5, 7, 3)


def test_empty_input():
    out, runs = refine_act(np.array([], dtype=bool), 1, 1)
    assert out.size == 0
    assert runs == []
