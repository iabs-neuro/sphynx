import math

from sphynx.acts.library import acts_library_defaults
from sphynx.config import Config


def test_default_library_acts():
    acts = acts_library_defaults()
    assert [a.name for a in acts] == ["rest", "walk", "locomotion", "freezing", "rear"]
    cfg = Config.default()
    assert acts[0].speed_max == cfg.acts.rest_threshold_cm_s          # rest
    assert acts[1].speed_min == cfg.acts.rest_threshold_cm_s          # walk
    assert acts[1].speed_max == cfg.acts.loc_threshold_cm_s
    assert acts[2].speed_min == cfg.acts.loc_threshold_cm_s and math.isinf(acts[2].speed_max)
    assert acts[3].type == "special" and acts[3].special_kind == "freezing"
    assert acts[4].type == "special" and acts[4].special_kind == "rears"
    assert acts[4].rear_mode == "TailbasePaws"
