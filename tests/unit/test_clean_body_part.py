import numpy as np
import pytest

from sphynx.preprocess.cleaning import clean_body_part, CleanResult


def test_clean_input_unchanged():
    rng = np.random.default_rng(0)
    x = 1 + rng.random(100) * 100
    y = 1 + rng.random(100) * 100
    out = clean_body_part(x, y, np.ones(100))
    assert isinstance(out, CleanResult)
    assert np.array_equal(out.X, x)
    assert out.status == "Good"
    assert out.percent_bad_combined == 0


def test_nan_input_becomes_nan():
    out = clean_body_part(np.array([10.0, np.nan, 30]), np.array([10.0, 20, 30]), np.ones(3))
    assert np.isnan(out.X[1]) and np.isnan(out.Y[1])


def test_low_likelihood_masked():
    out = clean_body_part(np.array([10.0, 20, 30]), np.array([10.0, 20, 30]),
                          np.array([0.99, 0.5, 0.99]), likelihood_threshold=0.95)
    assert np.isnan(out.X[1])
    assert out.percent_low_likelihood == pytest.approx(round(100 / 3, 2))


def test_out_of_bounds_masked():
    out = clean_body_part(np.array([10.0, 200, 30]), np.array([10.0, 20, 30]),
                          np.ones(3), frame_width=100, frame_height=100)
    assert np.isnan(out.X[1])


def test_status_not_found_when_mostly_bad():
    out = clean_body_part(np.random.default_rng(1).random(100) * 100,
                          np.random.default_rng(2).random(100) * 100, np.zeros(100))
    assert out.status == "NotFound"
