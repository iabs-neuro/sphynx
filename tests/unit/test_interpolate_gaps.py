import numpy as np

from sphynx.preprocess.interpolation import interpolate_gaps


def test_no_gaps_unchanged():
    x = np.arange(1.0, 11.0)
    assert np.array_equal(interpolate_gaps(x), x)


def test_fills_interior_gap():
    out = interpolate_gaps(np.array([1.0, 2.0, np.nan, 4.0, 5.0]))
    assert abs(out[2] - 3.0) < 0.5
    assert not np.isnan(out).any()


def test_fills_leading_and_trailing():
    out = interpolate_gaps(np.array([np.nan, np.nan, 3.0, 4.0, 5.0, np.nan, np.nan]))
    assert not np.isnan(out).any()


def test_all_nan_returns_all_nan():
    assert np.isnan(interpolate_gaps(np.full(5, np.nan))).all()


def test_linear_method():
    out = interpolate_gaps(np.array([10.0, np.nan, np.nan, 40.0]), method="linear")
    assert np.allclose(out, [10, 20, 30, 40], atol=1e-9)
