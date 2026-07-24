import math

import numpy as np
import pytest

from sphynx.acts.rear_threshold import auto_rear_threshold_cm


def test_empty_returns_nan():
    assert math.isnan(auto_rear_threshold_cm(np.array([])))
    assert math.isnan(auto_rear_threshold_cm(np.array([np.nan, np.nan])))


def test_within_clamp_range():
    rng = np.random.default_rng(0)
    # main mode ~4 cm with a small left tail near 2 cm
    s = np.concatenate([4.0 + rng.standard_normal(900) * 0.4, 2.0 + rng.standard_normal(100) * 0.2])
    thr = auto_rear_threshold_cm(s)
    assert 1.5 <= thr <= 3.5


def test_clamps_to_floor():
    # A distribution whose robust threshold would go below the 1.5 floor.
    s = np.full(500, 0.5)
    thr = auto_rear_threshold_cm(s)
    assert thr == 1.5


def test_hazen_percentile_method():
    # TDD: verify Hazen method matches MATLAB prctile behavior (not NumPy linear)
    # For 1..100: hazen gives 7.5, linear gives ~7.93 at 7th percentile
    # This test ensures the fixed code uses Hazen, not linear method.
    s = np.arange(1.0, 101.0)
    # With Hazen method (k-0.5)/n, the result should be different from linear
    hazen_pctl = float(np.percentile(s, 7, method="hazen"))
    linear_pctl = float(np.percentile(s, 7, method="linear"))
    assert hazen_pctl != linear_pctl, "Hazen and linear should differ"
    # The function should pick the smaller of percentile and std_thr
    # For this uniform array, std_thr will be large, so percentile wins
    thr = auto_rear_threshold_cm(s, pctl=7, clamp_min_cm=0, clamp_max_cm=100)
    # Result should be closer to hazen (7.5) than linear (7.93)
    assert abs(thr - hazen_pctl) < abs(thr - linear_pctl)
