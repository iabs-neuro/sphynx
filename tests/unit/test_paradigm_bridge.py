import math

import numpy as np
import pytest

from sphynx.acts import Act, ActFamily
from sphynx.config import Config
from sphynx.paradigms import (
    PARADIGMS, MetricRef, Paradigm, register_builtin_paradigms,
    register_paradigm,
)
from sphynx.paradigms.validate import ValidationRule
from sphynx.pipeline.analyze import SessionAct, SessionResult
from sphynx.pipeline.paradigm_bridge import apply_paradigm
from sphynx.bodyparts.identify import Point
from sphynx.zones import Zone, ZoneRoles, ZoneSelector

N = 60
FPS = 10.0


@pytest.fixture(autouse=True)
def _builtins():
    saved = dict(PARADIGMS)
    PARADIGMS.clear()
    register_builtin_paradigms()
    yield
    PARADIGMS.clear()
    PARADIGMS.update(saved)


class _Options:
    FrameRate = FPS
    pxl2sm = 10.0
    Width = 100
    Height = 100


class _Trace:
    def __init__(self, name, x, y, v):
        self.name = name
        self.x_smooth = x
        self.y_smooth = y
        self.velocity = v


def _hole(name, cx, cy, is_target=False):
    mask = np.zeros((100, 100), dtype=bool)
    mask[cy - 3:cy + 3, cx - 3:cx + 3] = True
    return Zone(name, "area", mask, zone_class="hole",
                roles=ZoneRoles(is_target=is_target), angle=0.0, index=None)


def _result(zones):
    # the animal sits inside hole_a for frames 10..19, elsewhere otherwise
    x = np.full(N, 90.0)
    y = np.full(N, 90.0)
    x[10:20] = 20.0
    y[10:20] = 20.0
    traces = [_Trace("nose", x, y, np.zeros(N)),
              _Trace("bodycenter", x, y, np.zeros(N))]
    point = Point(nose=0, center=1)
    return SessionResult(
        body_parts_names=["nose", "bodycenter"], body_parts_traces=traces,
        point=point, acts=[SessionAct("rest", np.ones(N), "builtin")],
        options=_Options(), zones=zones, arena_and_objects=None,
        n_frames=N, config=Config.default(),
    )


def _zones():
    zs = [_hole("hole_a", 20, 20, is_target=True), _hole("hole_b", 80, 20)]
    for i, z in enumerate(zs, start=1):
        z.index = i
    return zs


def test_validation_report_is_attached():
    result = _result(_zones())
    apply_paradigm(result, "OF")
    assert result.validation is not None
    assert result.validation.paradigm == "OF"
    assert result.validation.ok is True          # pxl2sm is set


def test_missing_calibration_is_reported():
    result = _result(_zones())
    result.options = type("O", (), {"FrameRate": FPS, "Width": 100, "Height": 100})()
    apply_paradigm(result, "OF")
    assert result.validation.ok is False
    assert "needs_calibration" in [i.code for i in result.validation.errors]


def test_family_acts_are_computed_and_appended():
    result = _result(_zones())
    apply_paradigm(result, "Barnes")
    names = [a.name for a in result.acts]
    assert "rest" in names                       # existing acts survive
    assert "nose_at_hole1" in names
    assert "nose_at_hole2" in names
    family_act = next(a for a in result.acts if a.name == "nose_at_hole1")
    assert family_act.category == "family"
    assert family_act.stats is not None
    assert family_act.array.sum() > 0            # the animal visited hole_a


def test_event_streams_are_built():
    result = _result(_zones())
    apply_paradigm(result, "Barnes")
    assert "nose_at_hole" in result.event_streams
    stream = result.event_streams["nose_at_hole"]
    assert [e.label for e in stream.events] == ["hole_a"]


def test_metrics_are_computed():
    result = _result(_zones())
    apply_paradigm(result, "Barnes")
    assert result.metrics is not None
    assert result.metrics.values["primary_latency"] == pytest.approx(1.0)
    assert result.metrics.values["target_ordinal"] == 0.0


def test_metric_failures_are_recorded_not_hidden():
    zones = [_hole("hole_a", 20, 20), _hole("hole_b", 80, 20)]   # no target
    for i, z in enumerate(zones, start=1):
        z.index = i
    result = _result(zones)
    apply_paradigm(result, "Barnes")
    assert result.metrics.errors            # target metrics could not run
    assert "needs_one_target" in [i.code for i in result.validation.errors]


def test_unbuildable_composite_is_reported_as_a_validation_issue():
    # EOF wants an "all_objects" composite; this preset has only holes.
    result = _result(_zones())
    apply_paradigm(result, "EOF")
    codes = [i.code for i in result.validation.issues]
    assert "composite_failed" in codes


def test_unbuildable_family_is_reported_as_a_validation_issue():
    result = _result(_zones())
    apply_paradigm(result, "EOF")
    codes = [i.code for i in result.validation.issues]
    assert "family_failed" in codes


def test_degradation_is_carried_onto_the_result():
    zones = _zones()
    result = _result(zones)
    result.body_parts_names = ["bodycenter"]     # no nose at all
    result.body_parts_traces = result.body_parts_traces[1:]
    result.point = Point(center=0)
    apply_paradigm(result, "Barnes")
    assert result.degraded                       # nose-based family acts degraded


def test_paradigm_config_defaults_do_not_override_the_preset():
    register_paradigm(Paradigm(name="Loud", parent="OF",
                               config_defaults={"velocity_rest": 99.0}))
    result = _result(_zones())
    apply_paradigm(result, "Loud")
    # the bridge records defaults for the caller but never rewrites Options
    assert result.paradigm_defaults["velocity_rest"] == 99.0
    assert result.options.pxl2sm == 10.0


def test_unknown_paradigm_raises():
    from sphynx.exceptions import SphynxValueError

    with pytest.raises(SphynxValueError):
        apply_paradigm(_result(_zones()), "NoSuchParadigm")


# --- S4a review regressions ---

def test_apply_paradigm_twice_does_not_duplicate_acts():
    # I3: the second application used to append every family act again.
    result = _result(_zones())
    apply_paradigm(result, "Barnes")
    first = [a.name for a in result.acts]
    apply_paradigm(result, "Barnes")
    assert [a.name for a in result.acts] == first


def test_zone_angles_are_assigned_so_angular_metrics_can_run():
    # I6: nothing in the pipeline called assign_zone_angles, so three Barnes
    # metrics could never compute.
    zones = _zones()
    assert all(z.angle == 0.0 for z in zones)      # the fixture starts flat
    result = _result(zones)
    apply_paradigm(result, "Barnes")
    angles = {z.name: z.angle for z in result.validation and zones}
    assert len({round(a, 6) for a in angles.values()}) > 1   # a real ring now
    assert "angular_distance_first" in result.metrics.values


def test_lineage_failure_is_reported_not_silent():
    # I2: a custom registry made lineage() raise, and every inherited metric
    # vanished from both values and errors with no trace.
    from sphynx.paradigms import Paradigm as _P
    from sphynx.paradigms.builtins import barnes_maze, open_field

    private = {"OF": open_field(), "Barnes": barnes_maze()}
    result = _result(_zones())
    apply_paradigm(result, "Barnes", registry=private)
    codes = [i.code for i in result.validation.issues]
    assert "lineage_failed" not in codes           # it resolves now
    assert result.metrics.values or result.metrics.errors


def test_paradigm_defaults_sit_between_the_preset_and_the_config(tmp_path):
    # I7: paradigm_defaults were recorded and never read.
    from sphynx.pipeline.analyze import _paradigm_defaults

    register_paradigm(Paradigm(name="Slow", parent="OF",
                               config_defaults={"velocity_rest": 3.0}))
    assert _paradigm_defaults("Slow")["velocity_rest"] == 3.0
    assert _paradigm_defaults("OF")["velocity_rest"] == 1.0
    assert _paradigm_defaults(None) == {}
