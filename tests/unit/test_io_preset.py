from pathlib import Path

import pytest

from sphynx.io import read_preset, PresetData
from sphynx.exceptions import SphynxIOError

REPO = Path(__file__).resolve().parents[2]


def test_missing_preset_raises(tmp_path):
    with pytest.raises(SphynxIOError):
        read_preset(tmp_path / "nope.mat")


def test_corrupt_preset_raises_sphynx_io_error(tmp_path):
    bad = tmp_path / "corrupt.mat"
    bad.write_text("this is not a valid .mat file")
    with pytest.raises(SphynxIOError):
        read_preset(bad)


def test_loads_demo_preset():
    mat = REPO / "Demo" / "Preset" / "NOF_H01_1D_Preset.mat"
    if not mat.is_file():
        pytest.skip("Demo NOF preset not present")
    out = read_preset(mat)
    assert isinstance(out, PresetData)
    assert out.options is not None
    assert hasattr(out.options, "FrameRate")
    assert hasattr(out.options, "pxl2sm")
    assert out.zones is not None
