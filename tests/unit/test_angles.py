import numpy as np
import pytest

from sphynx.angles import wrap


def test_zero_stays_zero():
    assert float(wrap(0.0)) == 0.0


def test_wraps_positive():
    assert float(wrap(3 * np.pi)) == pytest.approx(np.pi, abs=1e-12)
    assert float(wrap(2 * np.pi)) == pytest.approx(0.0, abs=1e-12)


def test_wraps_negative():
    assert float(wrap(-3 * np.pi)) == pytest.approx(np.pi, abs=1e-12)
    assert float(wrap(-2 * np.pi)) == pytest.approx(0.0, abs=1e-12)


def test_in_range_unchanged():
    a = np.array([-np.pi + 0.01, -np.pi / 2, 0, np.pi / 2, np.pi - 0.01])
    assert np.allclose(wrap(a), a, atol=1e-12)


def test_vectorized():
    out = wrap(np.array([3 * np.pi, -3 * np.pi, 0, np.pi / 4]))
    assert np.allclose(out, [np.pi, np.pi, 0, np.pi / 4], atol=1e-12)


def test_pi_stays_pi():
    assert float(wrap(np.pi)) == pytest.approx(np.pi, abs=1e-12)
    assert float(wrap(1000 * np.pi)) == pytest.approx(0.0, abs=1e-9)
