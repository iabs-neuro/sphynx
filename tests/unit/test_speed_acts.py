import numpy as np

from sphynx.acts.speed import speed_acts, SpeedActs


def test_stationary_all_rest():
    out = speed_acts(np.zeros(100), 1, 5, 5)
    assert isinstance(out, SpeedActs)
    assert out.rest.all()
    assert not out.walk.any()
    assert not out.locomotion.any()


def test_fast_all_locomotion():
    out = speed_acts(np.full(100, 20.0), 1, 5, 5)
    assert out.locomotion.all()


def test_mid_speed_all_walk():
    out = speed_acts(np.full(100, 3.0), 1, 5, 5)
    assert out.walk.all()


def test_partition_invariant():
    rng = np.random.default_rng(0)
    v = np.abs(rng.standard_normal(200)) * 5
    out = speed_acts(v, 1, 5, 5)
    assert int(out.rest.sum() + out.walk.sum() + out.locomotion.sum()) == 200
