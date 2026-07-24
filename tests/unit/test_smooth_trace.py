import numpy as np
import pytest

from sphynx.preprocess.smoothing import smooth_trace
from sphynx.exceptions import SphynxValueError


def test_even_window_raises():
    with pytest.raises(SphynxValueError):
        smooth_trace(np.arange(20.0), 4)


def test_too_small_window_raises():
    with pytest.raises(SphynxValueError):
        smooth_trace(np.arange(20.0), 1)


def test_non_integral_window_raises():
    with pytest.raises(SphynxValueError):
        smooth_trace(np.arange(20.0), 3.5)


def test_short_trace_passthrough():
    x = np.array([1.0, 2.0, 3.0])
    assert np.allclose(smooth_trace(x, 11), x)


def test_preserves_linear_trend_at_edges():
    # A pure line must come back (nearly) unchanged incl. the endpoints,
    # thanks to anti-symmetric mirror padding (Bug-3).
    x = np.linspace(0.0, 100.0, 200)
    out = smooth_trace(x, 11)
    assert out[0] == pytest.approx(x[0], abs=1e-6)
    assert out[-1] == pytest.approx(x[-1], abs=1e-6)
    assert np.allclose(out, x, atol=1e-6)


def test_interior_nan_filled():
    x = np.linspace(0.0, 50.0, 100)
    x[40:45] = np.nan
    out = smooth_trace(x, 11)
    assert not np.isnan(out).any()
