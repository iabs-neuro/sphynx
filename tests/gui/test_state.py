import pytest
from sphynx.config import Config
from sphynx_gui.state import AppState


def test_defaults_are_empty(qtbot):
    state = AppState()
    assert state.dlc_path == ""
    assert state.preset_path == ""
    assert state.paradigm == "OF"
    assert state.result is None


def test_setting_a_path_emits_paths_changed(qtbot):
    state = AppState()
    with qtbot.waitSignal(state.paths_changed, timeout=500):
        state.dlc_path = "a.csv"
    assert state.dlc_path == "a.csv"


def test_setting_the_same_path_does_not_emit(qtbot):
    state = AppState()
    state.dlc_path = "a.csv"
    received = []
    state.paths_changed.connect(lambda: received.append(1))
    state.dlc_path = "a.csv"
    assert received == []


def test_paradigm_signal(qtbot):
    state = AppState()
    with qtbot.waitSignal(state.paradigm_changed, timeout=500):
        state.paradigm = "Barnes"
    assert state.paradigm == "Barnes"


def test_result_signal(qtbot):
    state = AppState()
    sentinel = object()
    with qtbot.waitSignal(state.result_changed, timeout=500):
        state.result = sentinel
    assert state.result is sentinel


def test_build_config_carries_paths_and_frames(qtbot):
    state = AppState()
    state.dlc_path = "d.csv"
    state.preset_path = "p.mat"
    state.out_dir = "out"
    state.end_frame = 3000
    config = state.build_config()
    assert isinstance(config, Config)
    assert config.paths.dlc == "d.csv"
    assert config.paths.preset == "p.mat"
    assert config.paths.out_dir == "out"
    assert config.frames.end_frame == 3000
    assert config.io.save_workspace is False


def test_build_config_returns_a_copy_each_time(qtbot):
    state = AppState()
    first = state.build_config()
    first.paths.dlc = "mutated"
    assert state.build_config().paths.dlc == ""


def test_settings_round_trip_through_toml(tmp_path, qtbot):
    state = AppState()
    state.dlc_path = "d.csv"
    state.preset_path = "p.mat"
    state.out_dir = "out"
    state.paradigm = "Barnes"
    state.end_frame = 1500
    state.heatmap_bin_cm = 6.0
    path = tmp_path / "settings.toml"
    state.save_settings(path)

    restored = AppState()
    restored.load_settings(path)
    assert restored.dlc_path == "d.csv"
    assert restored.preset_path == "p.mat"
    assert restored.out_dir == "out"
    assert restored.paradigm == "Barnes"
    assert restored.end_frame == 1500
    assert restored.heatmap_bin_cm == 6.0


def test_loading_a_missing_settings_file_raises(tmp_path, qtbot):
    from sphynx.exceptions import SphynxIOError

    state = AppState()
    with pytest.raises(SphynxIOError):
        state.load_settings(tmp_path / "nope.toml")
