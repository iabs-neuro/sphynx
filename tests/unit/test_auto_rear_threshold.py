import math

import numpy as np

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
