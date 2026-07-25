"""S1 acceptance: end-to-end analyze_session on the Demo NOF_H01_1D session.

Skips cleanly if the Demo data is not present (it is large and untracked).
"""

from pathlib import Path

import numpy as np
import pytest

from sphynx.config import Config
from sphynx.pipeline import SessionResult, analyze_session

_ROOT = Path(__file__).resolve().parents[2]
_DLC = _ROOT / "Demo/DLC/NOF_H01_1DDLC_resnet152_MiceUniversal152Oct23shuffle1_1000000.csv"
_PRESET = _ROOT / "Demo/Preset/NOF_H01_1D_Preset.mat"

pytestmark = pytest.mark.skipif(
    not (_DLC.is_file() and _PRESET.is_file()),
    reason="Demo NOF_H01_1D data not present",
)


@pytest.fixture(scope="module")
def result() -> SessionResult:
    cfg = Config.default()
    cfg.paths.dlc = str(_DLC)
    cfg.paths.preset = str(_PRESET)
    cfg.io.save_workspace = False
    cfg.frames.end_frame = 3000  # keep the acceptance test fast
    cfg.verbose = "warn"
    return analyze_session(cfg)


def test_result_shape(result):
    assert isinstance(result, SessionResult)
    assert result.n_frames == 3000
    assert len(result.body_parts_names) >= 5
    # a center is always available (native or synthesised)
    assert result.point.center is not None


def test_builtin_acts_present(result):
    names = [a.name for a in result.acts]
    for expected in ("rest", "walk", "locomotion", "freezing"):
        assert expected in names


def test_act_stats_are_sane(result):
    for a in result.acts:
        s = a.stats
        assert s is not None
        assert 0.0 <= s.percent <= 100.0
        assert s.count >= 0
        assert s.duration_s >= 0.0
        assert s.distance_cm >= 0.0


def test_speed_bucket_mutually_exclusive(result):
    by_name = {a.name: a for a in result.acts}
    stacked = np.vstack([
        by_name["rest"].array, by_name["walk"].array, by_name["locomotion"].array,
    ]).astype(bool)
    # No frame is claimed by more than one speed act.
    assert stacked.sum(axis=0).max() <= 1
    total_pct = sum(by_name[n].stats.percent for n in ("rest", "walk", "locomotion"))
    assert total_pct <= 100.0 + 1e-6
