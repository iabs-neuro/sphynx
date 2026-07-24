from sphynx.preprocess.settings import per_part_default, PartSettings
from sphynx.config import Config


def test_big_vs_small_window():
    cfg = Config.default()
    s_big = per_part_default("bodycenter", cfg)
    s_small = per_part_default("nose", cfg)
    assert s_big.smooth_window_sec == cfg.preprocess.smooth_window_big_sec
    assert s_small.smooth_window_sec == cfg.preprocess.smooth_window_small_sec


def test_defaults_from_config():
    s = per_part_default("nose")
    assert isinstance(s, PartSettings)
    assert s.likelihood_threshold == 0.95
    assert s.smoothing_method == "sgolay"
    assert s.not_found_threshold_pct == 90


def test_big_part_case_insensitive():
    # 'mouse_center' is in the big-parts list
    s = per_part_default("MOUSE_CENTER")
    assert s.smooth_window_sec == Config.default().preprocess.smooth_window_big_sec
