import math

import numpy as np
import pytest

from sphynx.acts import Act, EventStream, family_event_stream
from sphynx.acts.stats import act_stats
from sphynx.exceptions import SphynxMetricError
from sphynx.metrics import MetricContext, compute_metric
import sphynx.metrics.builtins  # noqa: F401  (registers the built-ins)

FPS = 10.0


class _Zone:
    def __init__(self, name, is_target=False):
        self.name = name
        self.roles = type("R", (), {"is_target": is_target})()
        self.angle = None


def _member(name, zone, index, is_target=False):
    return Act(name=name, type="simple", family="holes",
               zone_name=zone, zone_index=index, is_target=is_target)


def _acts():
    return [_member("h1", "hole_a", 1),
            _member("h2", "hole_b", 2, is_target=True),
            _member("h3", "hole_c", 3)]


def _results():
    r = {n: np.zeros(30, dtype=bool) for n in ("h1", "h2", "h3")}
    r["h3"][2:4] = True        # hole_c first, at frame 2
    r["h2"][10:12] = True      # target hole_b at frame 10
    r["h1"][20:22] = True      # hole_a last
    return r


def _ctx(results=None, acts=None, zones=None):
    acts = _acts() if acts is None else acts
    results = _results() if results is None else results
    stream = family_event_stream(acts, results, FPS, family="holes")
    return MetricContext(
        acts=dict(results),
        stats={n: act_stats(m, FPS) for n, m in results.items()},
        events={"holes": stream}, act_defs=acts,
        zones=zones if zones is not None else [
            _Zone("hole_a"), _Zone("hole_b", True), _Zone("hole_c")],
        frame_rate=FPS,
    )


def test_visit_order():
    assert compute_metric("visit_order", _ctx(), family="holes") == [
        "hole_c", "hole_b", "hole_a"]


def test_latency_to_target():
    assert compute_metric("latency_to_target", _ctx(), family="holes") == pytest.approx(1.0)


def test_primary_errors_counts_distinct_holes_before_target():
    assert compute_metric("primary_errors", _ctx(), family="holes") == 1.0


def test_primary_errors_counts_a_recheck_once():
    r = _results()
    r["h3"][6:8] = True                       # hole_c re-checked before target
    assert compute_metric("primary_errors", _ctx(results=r), family="holes") == 1.0


def test_target_never_visited_is_nan_not_an_error():
    r = _results()
    r["h2"][:] = False                        # target declared, never found
    assert math.isnan(compute_metric("latency_to_target", _ctx(results=r), family="holes"))
    assert math.isnan(compute_metric("primary_errors", _ctx(results=r), family="holes"))


def test_no_target_declared_raises_rather_than_nan():
    # The section-10 distinction: "not declared" is a setup error, not a result.
    ctx = _ctx(zones=[_Zone("hole_a"), _Zone("hole_b"), _Zone("hole_c")])
    with pytest.raises(SphynxMetricError):
        compute_metric("latency_to_target", ctx, family="holes")


def test_time_to_first_any():
    assert compute_metric("time_to_first", _ctx(), family="holes") == pytest.approx(0.2)


def test_time_to_first_labelled():
    got = compute_metric("time_to_first", _ctx(), family="holes", label="hole_a")
    assert got == pytest.approx(2.0)


def test_time_to_first_unvisited_label_is_nan():
    got = compute_metric("time_to_first", _ctx(), family="holes", label="ghost")
    assert math.isnan(got)


def test_time_to_completion():
    # last distinct zone (hole_a) first seen at frame 20
    assert compute_metric("time_to_completion", _ctx(), family="holes") == pytest.approx(2.0)


def test_time_to_completion_incomplete_is_nan():
    r = _results()
    r["h1"][:] = False
    assert math.isnan(compute_metric("time_to_completion", _ctx(results=r), family="holes"))


def test_ratio_index_between_any_two_acts():
    r = _results()
    ctx = _ctx(results=r)
    # h3 and h2 both fire for 2 frames -> equal -> 0.0
    assert compute_metric("ratio_index", ctx, act_a="h3", act_b="h2") == pytest.approx(0.0)


def test_ratio_index_favours_a():
    r = _results()
    r["h3"][2:8] = True                        # longer
    ctx = _ctx(results=r)
    got = compute_metric("ratio_index", ctx, act_a="h3", act_b="h2")
    assert got > 0


def test_ratio_index_both_zero_is_nan():
    r = {n: np.zeros(30, dtype=bool) for n in ("h1", "h2", "h3")}
    ctx = _ctx(results=r)
    assert math.isnan(compute_metric("ratio_index", ctx, act_a="h1", act_b="h2"))


def test_ratio_index_unknown_act_raises():
    with pytest.raises(SphynxMetricError):
        compute_metric("ratio_index", _ctx(), act_a="ghost", act_b="h2")


def test_ratio_index_unknown_stat_raises():
    with pytest.raises(SphynxMetricError):
        compute_metric("ratio_index", _ctx(), act_a="h1", act_b="h2", stat="nonsense")


def test_missing_family_stream_raises():
    with pytest.raises(SphynxMetricError):
        compute_metric("visit_order", _ctx(), family="ghost_family")
