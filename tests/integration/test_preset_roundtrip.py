"""A preset built in Python analyses a real session (S4d).

The slice's whole point: draw on a frame of the demo video, save, and have the
engine read that file back and score object investigation on it.
"""

from pathlib import Path

import numpy as np
import pytest

from sphynx.config import Config
from sphynx.io.preset import read_preset
from sphynx.io.video import read_frame
from sphynx.paradigms import register_builtin_paradigms, resolve_paradigm, validate_paradigm
from sphynx.pipeline.analyze import analyze_session
from sphynx_gui.preset_tab import PresetTab
from sphynx_gui.state import AppState

VIDEO = Path("Demo/Video/NOF_H01_1D.mp4")
DLC = Path("Demo/DLC/NOF_H01_1DDLC_resnet152_MiceUniversal152Oct23shuffle1_"
           "1000000.csv")
LEGACY = Path("Demo/Preset/NOF_H01_1D_Preset.mat")

pytestmark = pytest.mark.skipif(
    not (VIDEO.is_file() and DLC.is_file() and LEGACY.is_file()),
    reason="demo video, DLC csv or legacy preset absent")


@pytest.fixture(autouse=True)
def _paradigms():
    register_builtin_paradigms(replace=True)


def _reference_calibration():
    """The demo session's own calibration, so the built preset is in the same
    units as the tracking it will be run against."""
    options = read_preset(LEGACY).options
    return float(options.pxl2sm), float(options.FrameRate)


def _built_tab(qtbot):
    pixels_per_cm, frame_rate = _reference_calibration()
    frame = read_frame(VIDEO, 0)
    height, width = frame.shape[0], frame.shape[1]

    state = AppState()
    state.paradigm = "EOF"
    tab = PresetTab(state)
    qtbot.addWidget(tab)
    tab.controller.use_frame(frame)
    tab.pixels_per_cm_box.setValue(pixels_per_cm)
    tab.frame_rate_box.setValue(frame_rate)

    # An arena filling most of the frame, and two objects inside it.
    tab.canvas.add_shape("arena", "rectangle",
                         [(0.08 * width, 0.08 * height),
                          (0.92 * width, 0.92 * height)])
    tab.set_shape_role("arena", "arena", False)
    tab.canvas.add_shape("object1", "ellipse",
                         [(0.30 * width, 0.35 * height),
                          (0.42 * width, 0.55 * height)])
    tab.set_shape_role("object1", "object", False)
    tab.canvas.add_shape("object2", "ellipse",
                         [(0.58 * width, 0.35 * height),
                          (0.70 * width, 0.55 * height)])
    tab.set_shape_role("object2", "object", False)
    tab.controller.build_zones()
    assert tab.controller.zones, tab.status_label.text()
    return tab


def test_a_preset_built_here_reads_validates_and_analyses(qtbot, tmp_path):
    tab = _built_tab(qtbot)
    target = tmp_path / "NOF_H01_1D_Preset.mat"
    tab.controller.save(target)
    assert target.is_file(), tab.status_label.text()

    preset = read_preset(target)
    classes = [str(z.zone_class) for z in np.atleast_1d(preset.zones)]
    assert classes.count("object_area") == 2

    report = validate_paradigm(resolve_paradigm("EOF"), preset.zones,
                               preset.options)
    assert [i for i in report.issues if i.level == "error"] == []

    config = Config.default()
    config.paths.dlc = str(DLC)
    config.paths.preset = str(target)
    config.io.save_workspace = False
    result = analyze_session(config, paradigm="EOF")

    names = {act.name for act in result.acts}
    assert "nose_at_object1" in names
    assert "nose_at_object2" in names


def test_the_built_preset_scores_time_at_the_objects(qtbot, tmp_path):
    tab = _built_tab(qtbot)
    target = tmp_path / "built.mat"
    tab.controller.save(target)

    config = Config.default()
    config.paths.dlc = str(DLC)
    config.paths.preset = str(target)
    config.io.save_workspace = False
    result = analyze_session(config, paradigm="EOF")

    by_name = {act.name: act for act in result.acts}
    # The objects are drawn where the demo session has none, so the time at
    # them is not asserted to be large -- only that the acts were really
    # scored frame by frame rather than coming back as empty placeholders.
    for name in ("nose_at_object1", "nose_at_object2"):
        array = np.asarray(by_name[name].array)
        assert array.size == result.n_frames
        assert by_name[name].stats is not None
