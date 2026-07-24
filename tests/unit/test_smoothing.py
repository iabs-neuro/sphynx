import numpy as np

from sphynx.util.smoothing import smooth_derived


def test_passthrough_when_window_le_1():
    x = np.array([1.0, 5.0, 2.0])
    assert np.allclose(smooth_derived(x, 1), x)


def test_empty_passthrough():
    assert smooth_derived(np.array([]), 5).size == 0


def test_reduces_noise_toward_mean():
    x = np.array([0.0, 10.0, 0.0, 10.0, 0.0, 10.0, 0.0])
    out = smooth_derived(x, 3)
    # interior values pulled toward the local mean (~5), away from 0/10 extremes
    assert out[3] > 2.0
    assert out[3] < 8.0


def test_ignores_nan_in_window():
    x = np.array([2.0, np.nan, 4.0])
    out = smooth_derived(x, 3)
    assert not np.isnan(out).all()
