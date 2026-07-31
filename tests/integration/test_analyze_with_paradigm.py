"""S4a acceptance: the paradigm path runs on the real demo session."""

from pathlib import Path

import pytest

from sphynx.config import Config
from sphynx.paradigms import PARADIGMS, register_builtin_paradigms
from sphynx.pipeline import analyze_session

_ROOT = Path(__file__).resolve().parents[2]
_DLC = _ROOT / "Demo/DLC/NOF_H01_1DDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv"
_PRESET = _ROOT / "Demo/Preset/NOF_H01_1D_Preset.mat"

pytestmark = pytest.mark.skipif(
    not (_DLC.is_file() and _PRESET.is_file()),
    reason="Demo NOF_H01_1D data not present",
)


@pytest.fixture(autouse=True)
def _builtins():
    saved = dict(PARADIGMS)
    PARADIGMS.clear()
    register_builtin_paradigms()
    yield
    PARADIGMS.clear()
    PARADIGMS.update(saved)


@pytest.fixture(scope="module")
def _config():
    config = Config.default()
    config.paths.dlc = str(_DLC)
    config.paths.preset = str(_PRESET)
    config.io.save_workspace = False
    config.frames.end_frame = 2000
    config.verbose = "warn"
    return config


def test_open_field_validates_clean(_config):
    result = analyze_session(_config, paradigm="OF")
    assert result.paradigm == "OF"
    assert result.validation is not None
    assert result.validation.ok is True          # the preset carries pxl2sm


def test_builtin_acts_still_computed_with_a_paradigm(_config):
    result = analyze_session(_config, paradigm="OF")
    names = [a.name for a in result.acts]
    for expected in ("rest", "walk", "locomotion", "freezing"):
        assert expected in names


def test_nor_reports_missing_objects_instead_of_lying(_config):
    result = analyze_session(_config, paradigm="NOR")
    assert result.validation.ok is False
    assert "needs_object" in [i.code for i in result.validation.errors]


def test_without_a_paradigm_nothing_changes(_config):
    result = analyze_session(_config)
    assert result.paradigm == ""
    assert result.validation is None
    assert result.metrics is None
