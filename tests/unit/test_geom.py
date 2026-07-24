import numpy as np

from sphynx.geom import hypot_kcorr


def test_plain_hypot_when_kcorr_one():
    assert hypot_kcorr(3.0, 4.0) == 5.0


def test_stretches_x():
    # dx=1 stretched by 2 -> effective 2; with dy=0 -> 2
    assert hypot_kcorr(1.0, 0.0, 2.0) == 2.0


def test_vectorized():
    d = hypot_kcorr(np.array([3.0, 0.0]), np.array([4.0, 5.0]))
    assert np.allclose(d, [5.0, 5.0])
