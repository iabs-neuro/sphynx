import math

import numpy as np
import pytest

from sphynx.acts.stats import act_stats, ActStats


def test_empty_act_has_zeros_and_nans():
    s = act_stats(np.zeros(100, bool), 30)
    assert isinstance(s, ActStats)
    assert s.count == 0
    assert s.percent == 0
    assert s.duration_s == 0
    assert math.isnan(s.first_start_s)
    assert math.isnan(s.last_end_s)


def test_full_act_stats():
    mask = np.zeros(100, bool)
    mask[9:30] = True   # MATLAB mask(10:30): 21 frames
    mask[59:80] = True  # MATLAB mask(60:80): 21 frames
    s = act_stats(mask, 30)
    assert s.count == 2
    assert round(s.percent) == 42
    assert s.mean_time == pytest.approx(0.7, abs=0.05)


def test_mean_velocity_is_actual_mean():
    n, fps = 100, 30
    mask = np.zeros(n, bool)
    mask[10:60] = True
    vel = np.zeros(n)
    vel[10:60] = np.linspace(10, 20, 50)
    s = act_stats(mask, fps, velocity=vel)
    assert s.mean_velocity == pytest.approx(np.mean(np.linspace(10, 20, 50)), abs=0.05)
    assert s.velocity == s.mean_velocity


def test_distance_is_sum_over_fps():
    n, fps = 60, 30
    mask = np.zeros(n, bool)
    mask[0:30] = True
    s = act_stats(mask, fps, velocity=np.full(n, 6.0))
    assert s.distance_cm == pytest.approx(6.0, abs=0.05)


def test_episode_boundaries():
    n, fps = 100, 30
    mask = np.zeros(n, bool)
    mask[30:40] = True   # MATLAB mask(31:40)
    mask[80:90] = True   # MATLAB mask(81:90)
    s = act_stats(mask, fps, velocity=np.ones(n))
    assert s.count == 2
    assert s.first_start_s == pytest.approx(30 / fps, abs=0.01)
    assert s.first_end_s == pytest.approx(39 / fps, abs=0.01)
    assert s.last_start_s == pytest.approx(80 / fps, abs=0.01)
    assert s.last_end_s == pytest.approx(89 / fps, abs=0.01)


def test_first_and_rest_duration_split():
    n, fps = 100, 10
    mask = np.zeros(n, bool)
    mask[10:20] = True   # 10 frames -> 1.0 s
    mask[30:50] = True   # 20 frames -> 2.0 s
    mask[70:80] = True   # 10 frames -> 1.0 s
    s = act_stats(mask, fps)
    assert s.count == 3
    assert s.duration_s == pytest.approx(4.0, abs=0.05)
    assert s.first_duration_s == pytest.approx(1.0, abs=0.05)
    assert s.rest_duration_s == pytest.approx(3.0, abs=0.05)


def test_single_episode_rest_zero():
    n, fps = 50, 10
    mask = np.zeros(n, bool)
    mask[4:14] = True
    s = act_stats(mask, fps)
    assert s.count == 1
    assert s.first_duration_s == pytest.approx(1.0, abs=0.05)
    assert s.rest_duration_s == 0


def test_max_min_velocity():
    n = 50
    mask = np.zeros(n, bool)
    mask[10:30] = True
    vel = np.zeros(n)
    vel[10:30] = [3, 7, 9, 5, 6, 8, 12, 4, 10, 7, 5, 6, 9, 8, 7, 6, 5, 4, 3, 11]
    s = act_stats(mask, 30, velocity=vel)
    assert s.max_velocity == 12
    assert s.min_velocity == 3
