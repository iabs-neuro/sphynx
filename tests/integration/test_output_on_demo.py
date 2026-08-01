"""S4c2 acceptance: a real project exports both tables, named metrics included."""

from pathlib import Path

import pandas as pd
import pytest

from sphynx.config import Config
from sphynx.paradigms import PARADIGMS, register_builtin_paradigms
from sphynx.pipeline.output import OutputSelection, export_tables, filter_tidy
from sphynx.project import PresetRule, Project
from sphynx.project.run import run_project
from sphynx.project.scan import scan_folder

_ROOT = Path(__file__).resolve().parents[2]
_DLC_DIR = _ROOT / "Demo/DLC"
_PRESET = _ROOT / "Demo/Preset_v2/NOF_H01_1D_Preset_v2.mat"

pytestmark = pytest.mark.skipif(
    not (_DLC_DIR.is_dir() and _PRESET.is_file()),
    reason="Demo data not present",
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
def _batch():
    # Module-scoped, so it is set up before the per-test fixture and may find
    # the registry already populated by another module.
    register_builtin_paradigms(replace=True)
    sessions = [s for s in scan_folder(_DLC_DIR)
                if s.name.startswith("NOF_H01")][:2]
    project = Project(name="demo", sessions=sessions,
                      preset_rules=[PresetRule(str(_PRESET))], paradigm="EOF")
    config = Config.default()
    config.io.save_workspace = False
    config.frames.end_frame = 600
    config.verbose = "error"
    return run_project(project, config=config)


def test_the_tidy_table_carries_both_kinds(_batch):
    kinds = set(_batch.tidy["metric_kind"])
    assert kinds == {"act_stat", "named"}


def test_the_paradigm_metrics_are_exportable(_batch):
    named = _batch.tidy[_batch.tidy["metric_kind"] == "named"]
    assert {"path_length", "mean_speed"} <= set(named["metric"])
    lengths = named[named["metric"] == "path_length"]["value"]
    assert (lengths.astype(float) > 0).all()


def test_the_wide_table_has_a_row_per_mouse(_batch):
    assert len(_batch.wide) == 1            # the demo sessions share one mouse
    assert "mouse" in _batch.wide.columns


def test_csv_export_writes_readable_files(_batch, tmp_path):
    written = export_tables(_batch.tidy, _batch.wide, tmp_path / "demo.csv")
    assert len(written) == 2
    tidy_back = pd.read_csv(tmp_path / "demo_tidy.csv")
    assert "metric_kind" in tidy_back.columns
    assert "path_length" in set(tidy_back["metric"])


def test_selecting_one_act_shrinks_the_export(_batch, tmp_path):
    kept = filter_tidy(_batch.tidy, OutputSelection(acts=["rest"]))
    stats = kept[kept["metric_kind"] == "act_stat"]
    assert set(stats["act_name"]) == {"rest"}
    assert not kept[kept["metric_kind"] == "named"].empty
