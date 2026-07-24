import numpy as np

from sphynx.preprocess.kalman import kalman_filter_2d


def test_smoothes_noisy_track():
    n = 500
    rng = np.random.default_rng(123)
    tx = np.arange(1, n + 1) * 0.5
    ty = np.sin(np.arange(1, n + 1) / 30) * 50 + 100
    ox = tx + rng.standard_normal(n) * 5
    oy = ty + rng.standard_normal(n) * 5
    xs, ys = kalman_filter_2d(ox, oy, np.ones(n), 1e-2, 1)
    assert np.sqrt(np.mean((xs - tx) ** 2)) < np.sqrt(np.mean((ox - tx) ** 2))
    assert np.sqrt(np.mean((ys - ty) ** 2)) < np.sqrt(np.mean((oy - ty) ** 2))


def test_low_likelihood_discounted():
    n = 200
    tx = np.arange(1, n + 1) * 0.5
    ox = tx.copy()
    oy = np.full(n, 100.0)
    lk = np.ones(n)
    ox[99:102] = 1000.0
    lk[99:102] = 0.05
    xs, _ = kalman_filter_2d(ox, oy, lk, 1e-2, 1)
    assert abs(xs[100] - tx[100]) < 50


def test_shape():
    n = 50
    rng = np.random.default_rng(1)
    xs, ys = kalman_filter_2d(rng.standard_normal(n) * 10 + 100,
                              rng.standard_normal(n) * 10 + 100)
    assert xs.size == n and ys.size == n


def test_too_short_unchanged():
    xs, ys = kalman_filter_2d([1.0, 2.0], [3.0, 4.0])
    assert np.array_equal(xs, [1.0, 2.0])
    assert np.array_equal(ys, [3.0, 4.0])
