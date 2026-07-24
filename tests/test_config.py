from sphynx.config import Config


def test_default_values_match_matlab_defaults():
    c = Config.default()
    assert c.frames.start_frame == 1
    assert c.frames.end_frame == 0
    assert c.frames.auto_start is False
    assert c.preprocess.likelihood_threshold == 0.95
    assert c.preprocess.max_velocity_cm_s == 50.0
    assert c.preprocess.interpolation_method == "pchip"
    assert c.preprocess.per_part.smoothing_method == "sgolay"
    assert c.acts.rest_threshold_cm_s == 1.0
    assert c.acts.loc_threshold_cm_s == 5.0
    assert c.acts.min_run_seconds == 0.25
    assert c.acts.freezing_mode == "HeadAndCenter"
    assert c.acts.rear_mode == "TailbasePaws"
    assert c.acts.rear_threshold_tailbase_paws_cm == 2.8
    assert c.acts.rear_auto_threshold is True
    assert c.io.save_workspace is True
    assert c.viz.headless is True
    assert c.verbose == "info"


def test_toml_round_trip(tmp_path):
    c = Config.default()
    c.acts.min_run_seconds = 0.4
    c.preprocess.per_part.smoothing_poly_order = 2
    p = tmp_path / "cfg.toml"
    c.to_toml(p)
    c2 = Config.from_toml(p)
    assert c2 == c


def test_partial_override_keeps_defaults(tmp_path):
    p = tmp_path / "cfg.toml"
    p.write_text("[acts]\nrest_threshold_cm_s = 2.0\n")
    c = Config.from_toml(p)
    assert c.acts.rest_threshold_cm_s == 2.0        # overridden
    assert c.acts.loc_threshold_cm_s == 5.0         # default kept
    assert c.preprocess.likelihood_threshold == 0.95  # untouched block kept
