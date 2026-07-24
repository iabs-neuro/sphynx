import numpy as np

from sphynx.preprocess.arena import arena_exclusion_ring


def _circle_mask(h=100, w=100, cx=50, cy=50, r=30):
    yy, xx = np.mgrid[0:h, 0:w]
    return (xx - cx) ** 2 + (yy - cy) ** 2 <= r**2


def test_ring_around_circle():
    regions = arena_exclusion_ring(_circle_mask(), 5)
    assert len(regions) >= 1
    assert max(np.asarray(r["vertices"]).shape[0] for r in regions) > 20


def test_zero_width_empty():
    assert arena_exclusion_ring(_circle_mask(), 0) == []
