"""sphynx.pipeline.cli argument wiring (no real analysis run)."""

import pytest

from sphynx.pipeline.cli import build_config, main


def test_build_config_from_args():
    args = type("A", (), {
        "config": "", "dlc": "d.csv", "preset": "p.mat",
        "out_dir": "", "end_frame": 500,
    })()
    cfg = build_config(args)
    assert cfg.paths.dlc == "d.csv"
    assert cfg.paths.preset == "p.mat"
    assert cfg.frames.end_frame == 500
    assert cfg.io.save_workspace is False


def test_main_requires_dlc_and_preset():
    with pytest.raises(SystemExit):
        main(["--dlc", "only.csv"])
