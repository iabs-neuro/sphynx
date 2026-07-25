"""save_session_plots writes the four overview PNGs headlessly."""

from types import SimpleNamespace

import numpy as np
import pytest

from sphynx.exceptions import SphynxValueError
from sphynx.plot import save_session_plots


def _stub_result():
    n = 400
    rng = np.linspace(0, 1, n)
    x = 300 + 200 * np.sin(2 * np.pi * rng)
    y = 300 + 200 * np.cos(2 * np.pi * rng)
    v = np.abs(np.gradient(x)) + 0.5
    trace = SimpleNamespace(name="bodycenter", x_smooth=x, y_smooth=y, velocity=v)
    options = SimpleNamespace(pxl2sm=22.2, FrameRate=30.0, Width=1340, Height=1172)
    return SimpleNamespace(body_parts_traces=[trace], options=options, n_frames=n)


def test_writes_four_pngs(tmp_path):
    paths = save_session_plots(_stub_result(), tmp_path)
    assert set(paths) == {"trajectory", "heatmap", "speed_histogram", "speed_vs_time"}
    for p in paths.values():
        f = tmp_path / __import__("os").path.basename(p)
        assert f.is_file()
        assert f.stat().st_size > 0


def test_prefix_applied(tmp_path):
    paths = save_session_plots(_stub_result(), tmp_path, prefix="s1_")
    assert paths["trajectory"].endswith("s1_trajectory.png")
    assert (tmp_path / "s1_heatmap.png").is_file()


def test_creates_missing_out_dir(tmp_path):
    target = tmp_path / "nested" / "plots"
    save_session_plots(_stub_result(), target)
    assert target.is_dir()
    assert (target / "trajectory.png").is_file()


def test_invalid_bin_raises(tmp_path):
    with pytest.raises(SphynxValueError):
        save_session_plots(_stub_result(), tmp_path, heatmap_bin_cm=0)


def test_empty_velocity_is_tolerated(tmp_path):
    r = _stub_result()
    r.body_parts_traces[0].velocity = None
    paths = save_session_plots(r, tmp_path)
    assert (tmp_path / "speed_vs_time.png").is_file()
