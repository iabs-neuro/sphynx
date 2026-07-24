import numpy as np
import pytest

from sphynx.acts.builtins import rear
from sphynx.bodyparts import Point
from sphynx.exceptions import SphynxValueError


def _pt():
    return Point(tailbase=0, left_hind_limb=1, right_hind_limb=2, center=0)


def test_tailbase_paws_all_rear():
    n, parts = 100, 5
    bpx = np.zeros((parts, n))
    bpy = np.zeros((parts, n))
    bpx[1, :] = 0.5   # left hind 0.5 from tailbase
    bpx[2, :] = 0.5   # right hind 0.5 from tailbase -> sum 1.0 cm < 2.8
    rm = rear(bpx, bpy, _pt(), "TailbasePaws", pixels_per_cm=1,
              tailbase_paws_threshold_cm=2.8, min_run_frames=5, frame_rate=30)
    assert rm.all()


def test_tailbase_paws_none():
    n, parts = 100, 5
    bpx = np.zeros((parts, n))
    bpy = np.zeros((parts, n))
    bpx[1, :] = 5
    bpx[2, :] = 5   # sum 10 cm > 2.8
    rm = rear(bpx, bpy, _pt(), "TailbasePaws", pixels_per_cm=1,
              tailbase_paws_threshold_cm=2.8, min_run_frames=5, frame_rate=30)
    assert not rm.any()


def test_unknown_mode_raises():
    with pytest.raises(SphynxValueError):
        rear(np.zeros((2, 10)), np.zeros((2, 10)), Point(), "Bogus", 1)


def test_missing_pixels_per_cm_raises():
    with pytest.raises(SphynxValueError):
        rear(np.zeros((3, 10)), np.zeros((3, 10)), _pt(), "TailbasePaws", None)
