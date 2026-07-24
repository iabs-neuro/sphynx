import numpy as np
import pytest

from sphynx.preprocess.threshold import auto_threshold
from sphynx.exceptions import SphynxValueError

RNG = np.random.default_rng(0)


def _bimodal():
    return np.clip(
        np.concatenate([0.99 + 0.005 * RNG.standard_normal(800),
                        0.20 + 0.05 * RNG.standard_normal(200)]), 0, 1)


def test_otsu_on_bimodal():
    thr = auto_threshold(_bimodal(), "otsu")
    assert 0.3 < thr < 0.95


def test_knee_on_bimodal():
    thr = auto_threshold(_bimodal(), "knee")
    assert 0.0 < thr < 1.0


def test_quantile_floor_and_above():
    L = np.linspace(0, 1, 1000)
    assert auto_threshold(L, "quantile", 0.05) == pytest.approx(0.4, abs=1e-2)
    assert auto_threshold(L, "quantile", 0.5) == pytest.approx(0.5, abs=1e-2)


def test_quantile_default_floored():
    assert auto_threshold(np.linspace(0, 1, 1000), "quantile") == pytest.approx(0.4, abs=1e-2)


def test_preset_keywords():
    L = RNG.random(100)
    assert auto_threshold(L, "preset", "aggressive") == 0.99
    assert auto_threshold(L, "preset", "moderate") == 0.95
    assert auto_threshold(L, "preset", "lax") == 0.60


def test_preset_default():
    assert auto_threshold(RNG.random(100), "preset") == 0.95


def test_preset_numeric():
    assert auto_threshold(RNG.random(100), "preset", 0.9) == pytest.approx(0.9)


def test_empty_fallback():
    assert auto_threshold([], "otsu") == 0.95
    assert auto_threshold([], "knee") == 0.95


def test_all_same_fallback():
    assert 0 <= auto_threshold(np.ones(500), "otsu") <= 1
    assert 0 <= auto_threshold(np.ones(500), "knee") <= 1


def test_unknown_method_raises():
    with pytest.raises(SphynxValueError):
        auto_threshold(RNG.random(100), "foobar")


def test_always_in_range():
    for _ in range(20):
        L = RNG.random(RNG.integers(50, 5000))
        for m in ("otsu", "knee", "quantile", "preset"):
            p = "moderate" if m == "preset" else None
            assert 0 <= auto_threshold(L, m, p) <= 1
