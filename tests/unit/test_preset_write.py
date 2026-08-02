from pathlib import Path

import numpy as np
import pytest

from sphynx.exceptions import SphynxIOError
from sphynx.io.preset import read_preset
from sphynx.io.preset_write import options_struct, save_preset
from sphynx.zones.strips import Zone, ZoneRoles

H = W = 60


def _mask(r0, r1, c0, c1):
    mask = np.zeros((H, W), dtype=bool)
    mask[r0:r1, c0:c1] = True
    return mask


def _zones():
    return [
        Zone("arena", "area", _mask(5, 55, 5, 55), zone_class="arena", index=1),
        Zone("object1_real", "area", _mask(10, 16, 10, 16), zone_class="object",
             index=1),
        Zone("object1_realout", "area", _mask(8, 18, 8, 18),
             zone_class="object_area", index=1),
        Zone("target_real", "area", _mask(40, 46, 40, 46), zone_class="hole",
             roles=ZoneRoles(is_target=True), index=1),
    ]


def _options():
    return options_struct(frame_rate=30.0, pixels_per_cm=22.2, width=W,
                          height=H, experiment_type="Novelty OF")


def test_the_file_is_written(tmp_path):
    path = tmp_path / "nested" / "preset.mat"
    written = save_preset(_zones(), _options(), path)
    assert Path(written).is_file()


def test_the_engine_can_read_it_back(tmp_path):
    path = tmp_path / "preset.mat"
    save_preset(_zones(), _options(), path)
    preset = read_preset(path)
    names = [str(z.name) for z in np.atleast_1d(preset.zones)]
    assert "arena" in names and "object1_real" in names


def test_zone_classes_survive(tmp_path):
    path = tmp_path / "preset.mat"
    save_preset(_zones(), _options(), path)
    zones = {str(z.name): z for z in np.atleast_1d(read_preset(path).zones)}
    assert zones["object1_real"].zone_class == "object"
    assert zones["object1_realout"].zone_class == "object_area"


def test_the_target_flag_survives(tmp_path):
    path = tmp_path / "preset.mat"
    save_preset(_zones(), _options(), path)
    zones = {str(z.name): z for z in np.atleast_1d(read_preset(path).zones)}
    assert bool(zones["target_real"].roles.is_target) is True
    assert bool(zones["arena"].roles.is_target) is False


def test_masks_survive(tmp_path):
    path = tmp_path / "preset.mat"
    save_preset(_zones(), _options(), path)
    zones = {str(z.name): z for z in np.atleast_1d(read_preset(path).zones)}
    assert zones["arena"].maskfilled.shape == (H, W)
    assert zones["arena"].maskfilled.sum() == _mask(5, 55, 5, 55).sum()


def test_the_options_the_engine_reads_survive(tmp_path):
    path = tmp_path / "preset.mat"
    save_preset(_zones(), _options(), path)
    options = read_preset(path).options
    assert float(options.FrameRate) == 30.0
    assert float(options.pxl2sm) == 22.2
    assert int(options.Width) == W
    assert int(options.Height) == H
    assert float(options.x_kcorr) == 1.0


def test_the_index_and_angle_survive(tmp_path):
    # S4d review F3: read_preset used to hardcode index=None, angle=None and
    # throw away what save_preset had just written.
    path = tmp_path / "preset.mat"
    zones = [
        Zone("hole1_real", "area", _mask(10, 16, 10, 16), zone_class="hole",
             index=3, angle=0.0),
        Zone("hole2_real", "area", _mask(20, 26, 20, 26), zone_class="hole",
             index=4, angle=1.25),
    ]
    save_preset(zones, _options(), path)
    back = {str(z.name): z for z in np.atleast_1d(read_preset(path).zones)}
    assert int(back["hole1_real"].index) == 3
    assert int(back["hole2_real"].index) == 4
    # 0.0 is a legitimate angle (the hole at 3 o'clock); it must not read as
    # "not set".
    assert back["hole1_real"].angle == 0.0
    assert back["hole1_real"].angle is not None
    assert back["hole2_real"].angle == pytest.approx(1.25)


def test_an_unset_index_and_angle_come_back_as_none(tmp_path):
    path = tmp_path / "preset.mat"
    save_preset([Zone("arena", "area", _mask(5, 55, 5, 55), zone_class="arena")],
                _options(), path)
    arena = np.atleast_1d(read_preset(path).zones)[0]
    assert arena.index is None          # NaN in the file means "not set"
    assert arena.angle is None


def test_saving_no_zones_raises(tmp_path):
    with pytest.raises(SphynxIOError):
        save_preset([], _options(), tmp_path / "empty.mat")


def test_a_written_preset_passes_paradigm_validation(tmp_path):
    from sphynx.paradigms import (
        PARADIGMS, register_builtin_paradigms, resolve_paradigm,
        validate_paradigm,
    )

    PARADIGMS.clear()
    register_builtin_paradigms()
    path = tmp_path / "preset.mat"
    save_preset(_zones(), _options(), path)
    preset = read_preset(path)
    report = validate_paradigm(resolve_paradigm("EOF"), list(preset.zones),
                               preset.options)
    assert report.ok is True          # an object and a calibration are present
    PARADIGMS.clear()
