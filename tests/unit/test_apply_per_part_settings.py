import numpy as np

from sphynx.preprocess.orchestrator import apply_per_part_settings, PartResult
from sphynx.preprocess.settings import per_part_default, PartContext


def _ctx(**kw):
    return PartContext(frame_width=800, frame_height=600, frame_rate=30, **kw)


def test_clean_interp_smooth_pipeline():
    n = 600
    t = np.arange(1, n + 1)
    x = 100 + 0.05 * t**1.5
    y = 200 - 0.02 * t
    lk = np.ones(n) * 0.99
    bad = [49, 50, 51, 199, 200]  # 0-based
    lk[bad] = 0.1
    x[bad] += 50
    y[bad] -= 50
    out = apply_per_part_settings(x, y, lk, per_part_default("nose"), _ctx())
    assert out.status == "Good"
    assert out.x_smooth.size == n and out.y_smooth.size == n
    assert not np.isnan(out.x_smooth).any()
    assert not np.isnan(out.y_smooth).any()
    assert abs(out.x_smooth[49] - x[44]) < 30
    assert abs(out.y_smooth[49] - y[44]) < 30


def test_not_found_when_all_bad():
    n = 200
    rng = np.random.default_rng(0)
    s = per_part_default("nose")
    s.not_found_threshold_pct = 50
    out = apply_per_part_settings(
        rng.standard_normal(n) * 10 + 100, rng.standard_normal(n) * 10 + 100,
        np.zeros(n), s, _ctx())
    assert out.status == "NotFound"
    assert np.isnan(out.x_smooth).all()


def test_all_smoothing_methods_valid():
    n = 300
    x = np.sin(np.arange(1, n + 1) / 20) * 50 + 200
    y = np.cos(np.arange(1, n + 1) / 20) * 50 + 200
    lk = np.ones(n)
    for m in ("sgolay", "movmean", "movmedian", "gaussian", "kalman"):
        s = per_part_default("nose")
        s.smoothing_method = m
        out = apply_per_part_settings(x, y, lk, s, _ctx())
        assert out.x_smooth.size == n, m
        assert not np.isnan(out.x_smooth).any(), m


def test_manual_region_exclusion():
    n = 500
    x = np.linspace(50, 450, n)
    y = np.full(n, 250.0)
    ctx = _ctx(part_name="nose",
               manual_regions=[{"vertices": np.array([[200, 200], [300, 200],
                                                       [300, 300], [200, 300]]),
                                "applies_to": "all"}])
    out = apply_per_part_settings(x, y, np.ones(n), per_part_default("nose"), ctx)
    assert out.percent_bad_combined > 0
    assert out.status == "Good"


def test_manual_region_applies_to_other_part():
    n = 500
    x = np.linspace(50, 450, n)
    y = np.full(n, 250.0)
    ctx = _ctx(part_name="nose",
               manual_regions=[{"vertices": np.array([[200, 200], [300, 200],
                                                       [300, 300], [200, 300]]),
                                "applies_to": "tailbase"}])
    out = apply_per_part_settings(x, y, np.ones(n), per_part_default("nose"), ctx)
    assert out.percent_bad_combined == 0


def test_frame_bounds_clamping_all_oob_not_found():
    n = 100
    s = per_part_default("nose")
    s.likelihood_threshold = 0.5
    out = apply_per_part_settings(np.full(n, 1500.0), np.full(n, 100.0),
                                  np.ones(n), s, _ctx())
    assert out.status == "NotFound"
