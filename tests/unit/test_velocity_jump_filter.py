import numpy as np

from sphynx.preprocess.filters import velocity_jump_filter


def test_flags_obvious_jump():
    n = 200
    x = np.arange(1.0, n + 1)
    y = np.full(n, 100.0)
    x[49] = 5000.0  # teleport at (0-based) frame 49
    xo, yo, bad = velocity_jump_filter(x, y, 30, 5, 50)
    assert bad[49]  # out
    assert bad[50]  # back
    assert np.isnan(xo[49])
    assert bad.sum() == 2


def test_no_jumps_intact():
    n = 100
    x = np.arange(1.0, n + 1)
    y = np.full(n, 100.0)
    xo, yo, bad = velocity_jump_filter(x, y, 30, 5, 50)
    assert not bad.any()
    assert np.array_equal(xo, x)


def test_nan_safe():
    n = 50
    x = np.arange(1.0, n + 1)
    y = np.full(n, 100.0)
    x[19] = np.nan
    _, _, bad = velocity_jump_filter(x, y, 30, 5, 50)
    assert not bad.any()


def test_too_short_unchanged():
    xo, yo, bad = velocity_jump_filter([10.0, 11.0], [10.0, 11.0], 30, 5, 50)
    assert np.array_equal(xo, [10.0, 11.0])
    assert not bad.any()


def test_flags_index_after_jump():
    n = 100
    x = np.arange(1.0, n + 1)
    y = np.full(n, 100.0)
    x[59] = 9000.0
    _, _, bad = velocity_jump_filter(x, y, 30, 5, 50)
    assert bad[59]
    assert not bad[58]
