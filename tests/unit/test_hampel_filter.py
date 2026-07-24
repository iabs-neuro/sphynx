import numpy as np

from sphynx.preprocess.filters import hampel_filter


def test_flags_isolated_spike():
    n = 200
    x = np.sin(np.arange(1, n + 1) / 10) * 50 + 100
    y = np.cos(np.arange(1, n + 1) / 10) * 50 + 100
    x[79] = 9999.0
    xo, _, bad = hampel_filter(x, y, 7, 3)
    assert bad[79]
    assert np.isnan(xo[79])


def test_clean_input_nothing_flagged():
    n = 200
    x = np.sin(np.arange(1, n + 1) / 10) * 50 + 100
    y = np.cos(np.arange(1, n + 1) / 10) * 50 + 100
    xo, yo, bad = hampel_filter(x, y, 7, 3)
    assert bad.sum() == 0
    assert np.array_equal(xo, x)
    assert np.array_equal(yo, y)


def test_nan_input_passthrough():
    n = 50
    x = np.arange(1, n + 1) + 100.0
    y = np.arange(1, n + 1) + 100.0
    x[9] = np.nan
    y[9] = np.nan
    xo, yo, bad = hampel_filter(x, y, 5, 3)
    assert np.isnan(xo[9]) and np.isnan(yo[9])
    assert not bad[9]


def test_too_short_unchanged():
    xo, yo, bad = hampel_filter([1.0, 2.0], [1.0, 2.0])
    assert np.array_equal(xo, [1.0, 2.0])
    assert bad.sum() == 0
