"""S4b acceptance: a hand-written library runs on the real demo session."""

from pathlib import Path

import pytest

from sphynx.acts import Act, ActFamily
from sphynx.acts.library_io import ActLibrary
from sphynx.config import Config
from sphynx.paradigms import PARADIGMS, register_builtin_paradigms
from sphynx.pipeline import analyze_session
from sphynx.zones import ZoneSelector

_ROOT = Path(__file__).resolve().parents[2]
_DLC = _ROOT / "Demo/DLC/NOF_H01_1DDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv"
_PRESET = _ROOT / "Demo/Preset_v2/NOF_H01_1D_Preset_v2.mat"

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
    config.frames.end_frame = 3000
    config.verbose = "warn"
    return config


def test_library_family_runs_alongside_the_paradigm(_config):
    library = ActLibrary(families=[ActFamily(
        name="tail_at_object",
        selector=ZoneSelector(zone_class="object_area"),
        template=Act(name="tail_at_object", type="simple", body_part="tailbase",
                     required_parts=["tailbase"]))])
    result = analyze_session(_config, paradigm="EOF", library=library)
    names = [a.name for a in result.acts]
    assert "nose_at_object1" in names          # the paradigm's
    assert "tail_at_object1" in names          # the library's
    assert result.validation.ok is True


def test_overriding_a_paradigm_act_is_reported(_config):
    library = ActLibrary(families=[ActFamily(
        name="nose_at_object",
        selector=ZoneSelector(zone_class="object_area"),
        template=Act(name="nose_at_object", type="simple", body_part="nose",
                     required_parts=["nose"], min_duration_sec=1.0))])
    result = analyze_session(_config, paradigm="EOF", library=library)
    codes = [i.code for i in result.validation.issues]
    assert "act_overridden" in codes
    assert [a.name for a in result.acts].count("nose_at_object1") == 1
