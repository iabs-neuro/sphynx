import numpy as np
import pytest

from sphynx.preprocess.velocity import compute_velocity
from sphynx.exceptions import SphynxValueError


def test_stationary_yields_zero():
    x = np.full(100, 50.0)
    y = np.full(100, 50.0)
    v = compute_velocity(x, y, 30, 5)
    assert np.max(v) == pytest.approx(0.0, abs=1e-9)


def test_uniform_motion():
    n = 200
    ppc = 5
    x = np.arange(1, n + 1) * ppc  # 1 cm/frame
    y = np.full(n, 100.0)
    v = compute_velocity(x, y, 30, ppc)
    assert np.mean(v[20:-20]) == pytest.approx(30.0, abs=1.0)


def test_outlier_clipped():
    n = 200
    ppc = 5
    x = np.arange(1, n + 1) * ppc * 10 / 30
    y = np.full(n, 100.0)
    x[99] += 200 * ppc
    v = compute_velocity(x, y, 30, ppc)
    assert np.max(v) <= 50 + 1e-9


def test_requires_positive_pxl_per_cm():
    with pytest.raises(SphynxValueError):
        compute_velocity([1.0, 2, 3], [1.0, 2, 3], 30, 0)


def test_requires_positive_frame_rate():
    with pytest.raises(SphynxValueError):
        compute_velocity([1.0, 2, 3], [1.0, 2, 3], 0, 5)
