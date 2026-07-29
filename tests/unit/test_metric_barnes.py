"""Barnes metrics over a synthetic 8-hole ring (S2 M7).

The ring is built from real zone angles, so nothing in these tests -- or in the
metrics -- depends on a hole-count constant.
"""

import math

import numpy as np
import pytest

from sphynx.acts import Act, family_event_stream
from sphynx.exceptions import SphynxMetricError
from sphynx.metrics import MetricContext, compute_metric
import sphynx.metrics.barnes  # noqa: F401  (registers the Barnes metrics)

FPS = 10.0
N_HOLES = 8
N_FRAMES = 200
TARGET = "hole0"


class _Zone:
    """Minimal zone stand-in carrying the fields the metrics read."""

    def __init__(self, name, angle, is_target=False):
        self.name = name
        self.angle = angle
        self.zone_class = "hole"
        self.roles = type("R", (), {"is_target": is_target, "tags": []})()


def _ring(with_angles=True):
    """hole0 at 0 rad, then every 45 degrees anticlockwise."""
    zones = []
    for i in range(N_HOLES):
        angle = (2 * math.pi * i / N_HOLES) if with_angles else None
        zones.append(_Zone(f"hole{i}", angle, is_target=(i == 0)))
    return zones


def _acts(family="nose_at_hole"):
    return [
        Act(name=f"{family}{i + 1}", type="simple", family=family,
            zone_name=f"hole{i}", zone_index=i + 1, is_target=(i == 0))
        for i in range(N_HOLES)
    ]


def _results(visits, family="nose_at_hole"):
    """visits: list of (hole_index, start_frame) -- each a 4-frame episode."""
    acts = _acts(family)
    out = {a.name: np.zeros(N_FRAMES, dtype=bool) for a in acts}
    for hole, start in visits:
        out[f"{family}{hole + 1}"][start:start + 4] = True
    return out


def _ctx(visits, zones=None, trajectory_cm="default", family="nose_at_hole"):
    acts = _acts(family)
    results = _results(visits, family)
    stream = family_event_stream(acts, results, FPS, family=family)
    if trajectory_cm == "default":
        # a 1 cm step per frame -> path length is a round number
        trajectory_cm = (np.arange(N_FRAMES, dtype=float),
                         np.zeros(N_FRAMES, dtype=float))
    return MetricContext(
        acts=dict(results), stats={}, events={family: stream}, act_defs=acts,
        zones=_ring() if zones is None else zones,
        trajectory_cm=trajectory_cm, frame_rate=FPS,
    )


# --- counts and latency ----------------------------------------------------

def test_total_errors_counts_repeats():
    # hole3 checked twice, hole5 once, then the target
    ctx = _ctx([(3, 10), (5, 30), (3, 50), (0, 70)])
    assert compute_metric("total_errors", ctx, family="nose_at_hole") == 3.0


def test_primary_errors_counts_distinct_holes_before_target():
    # the generic M5 metric: hole3 twice counts once, and only before the target
    ctx = _ctx([(3, 10), (5, 30), (3, 50), (0, 70)])
    assert compute_metric("primary_errors", ctx, family="nose_at_hole") == 2.0


def test_target_checks_and_time_near_target():
    ctx = _ctx([(3, 10), (0, 40), (0, 90)])
    assert compute_metric("target_checks", ctx, family="nose_at_hole") == 2.0
    # two 4-frame episodes at 10 fps
    assert compute_metric("time_near_target", ctx, family="nose_at_hole") == \
        pytest.approx(0.8)


def test_target_ordinal_is_a_visit_ordinal():
    ctx = _ctx([(3, 10), (5, 30), (0, 60)])
    assert compute_metric("target_ordinal", ctx, family="nose_at_hole") == 2.0


def test_target_ordinal_nan_when_never_found():
    ctx = _ctx([(3, 10), (5, 30)])
    assert math.isnan(compute_metric("target_ordinal", ctx, family="nose_at_hole"))


def test_total_latency_uses_the_entry_family():
    ctx = _ctx([(4, 20), (0, 80)], family="inside_hole")
    got = compute_metric("total_latency", ctx, family="inside_hole")
    assert got == pytest.approx(8.0)


def test_total_latency_nan_when_never_entered():
    ctx = _ctx([(4, 20)], family="inside_hole")
    assert math.isnan(compute_metric("total_latency", ctx, family="inside_hole"))


# --- angular metrics -------------------------------------------------------

def test_angular_distance_first_is_degrees():
    # hole2 sits 90 degrees from hole0
    ctx = _ctx([(2, 10), (0, 50)])
    assert compute_metric("angular_distance_first", ctx,
                          family="nose_at_hole") == pytest.approx(90.0)


def test_angular_distance_folds_past_180():
    # hole5 is 225 degrees anticlockwise -> 135 degrees of separation
    ctx = _ctx([(5, 10)])
    assert compute_metric("angular_distance_first", ctx,
                          family="nose_at_hole") == pytest.approx(135.0)


def test_mean_angular_distance_over_distinct_holes():
    # hole1 (45), hole7 (45), target (0) -> mean 30
    ctx = _ctx([(1, 10), (7, 30), (0, 60)])
    assert compute_metric("mean_angular_distance", ctx,
                          family="nose_at_hole") == pytest.approx(30.0)


def test_angular_metrics_nan_when_nothing_checked():
    ctx = _ctx([])
    assert math.isnan(compute_metric("angular_distance_first", ctx,
                                     family="nose_at_hole"))
    assert math.isnan(compute_metric("mean_angular_distance", ctx,
                                     family="nose_at_hole"))


def test_holes_without_angles_raise_rather_than_guess():
    ctx = _ctx([(2, 10)], zones=_ring(with_angles=False))
    with pytest.raises(SphynxMetricError) as exc:
        compute_metric("angular_distance_first", ctx, family="nose_at_hole")
    assert "angle" in str(exc.value)


def test_ring_geometry_comes_from_the_zones_not_a_constant():
    # A 4-hole preset: the step is 90 degrees, not 360/19 as the MATLAB
    # NumObjects=19 default would have made it (docs/TODO.md line 89).
    zones = [_Zone(f"hole{i}", 2 * math.pi * i / 4, is_target=(i == 0))
             for i in range(4)]
    acts = [Act(name=f"nose_at_hole{i + 1}", type="simple", family="nose_at_hole",
                zone_name=f"hole{i}", zone_index=i + 1, is_target=(i == 0))
            for i in range(4)]
    results = {a.name: np.zeros(N_FRAMES, dtype=bool) for a in acts}
    results["nose_at_hole2"][10:14] = True          # hole1, one step round
    stream = family_event_stream(acts, results, FPS, family="nose_at_hole")
    ctx = MetricContext(acts=dict(results), stats={},
                        events={"nose_at_hole": stream}, act_defs=acts,
                        zones=zones, frame_rate=FPS)
    assert compute_metric("angular_distance_first", ctx,
                          family="nose_at_hole") == pytest.approx(90.0)


# --- path length -----------------------------------------------------------

def test_path_length_whole_trial():
    ctx = _ctx([(0, 10)])
    assert compute_metric("path_length", ctx) == pytest.approx(N_FRAMES - 1)


def test_path_length_to_target_truncates():
    ctx = _ctx([(3, 10), (0, 50)])
    assert compute_metric("path_length_to_target", ctx,
                          family="nose_at_hole") == pytest.approx(50.0)


def test_path_length_to_target_nan_when_never_found():
    ctx = _ctx([(3, 10)])
    assert math.isnan(compute_metric("path_length_to_target", ctx,
                                     family="nose_at_hole"))


def test_missing_trajectory_raises():
    ctx = _ctx([(0, 10)], trajectory_cm=None)
    with pytest.raises(SphynxMetricError):
        compute_metric("path_length", ctx)


def test_path_length_bridges_tracking_gaps():
    # M7 review (I1): dropping the step across a dropout understates the path
    # by the whole distance covered while tracking was lost.
    x = np.arange(N_FRAMES, dtype=float)
    y = np.zeros(N_FRAMES, dtype=float)
    x[50:60] = np.nan
    ctx = _ctx([(0, 10)], trajectory_cm=(x, y))
    assert compute_metric("path_length", ctx) == pytest.approx(N_FRAMES - 1)


# --- search strategy -------------------------------------------------------

def test_direct_strategy():
    # straight to the neighbourhood of the target, then the target
    ctx = _ctx([(1, 10), (0, 40)])
    assert compute_metric("search_strategy", ctx, family="nose_at_hole") == "direct"


def test_serial_strategy():
    # a sweep around the ring: hole3 -> 4 -> 5 -> 6, target last
    ctx = _ctx([(3, 10), (4, 30), (5, 50), (6, 70), (0, 120)])
    assert compute_metric("search_strategy", ctx, family="nose_at_hole") == "serial"


def test_random_strategy():
    # jumping across the ring with no order and far from the target
    ctx = _ctx([(3, 10), (6, 30), (2, 50), (5, 70)])
    assert compute_metric("search_strategy", ctx, family="nose_at_hole") == "random"


def test_no_search_is_not_a_strategy():
    assert compute_metric("search_strategy", _ctx([]),
                          family="nose_at_hole") == "none"


def test_direct_thresholds_are_parameters():
    ctx = _ctx([(1, 10), (7, 30), (2, 50), (6, 70), (0, 100)])
    assert compute_metric("search_strategy", ctx, family="nose_at_hole",
                          max_direct_errors=10, direct_arc_deg=180) == "direct"
    assert compute_metric("search_strategy", ctx, family="nose_at_hole",
                          max_direct_errors=1) != "direct"


# --- dependency failures ---------------------------------------------------

def test_family_without_a_target_member_raises():
    acts = [a for a in _acts() if not a.is_target]
    results = {a.name: np.zeros(N_FRAMES, dtype=bool) for a in acts}
    results["nose_at_hole4"][10:14] = True
    stream = family_event_stream(acts, results, FPS, family="nose_at_hole")
    ctx = MetricContext(acts=dict(results), stats={},
                        events={"nose_at_hole": stream}, act_defs=acts,
                        zones=_ring(), frame_rate=FPS)
    for metric in ("total_errors", "target_checks", "target_ordinal",
                   "time_near_target", "angular_distance_first"):
        with pytest.raises(SphynxMetricError):
            compute_metric(metric, ctx, family="nose_at_hole")


def test_unknown_family_raises():
    with pytest.raises(SphynxMetricError):
        compute_metric("total_errors", _ctx([(0, 10)]), family="ghost")


def test_barnes_metrics_are_paradigm_scoped():
    from sphynx.metrics.registry import REGISTRY

    for name in ("total_errors", "target_ordinal", "search_strategy",
                 "path_length", "mean_angular_distance"):
        assert REGISTRY[name].paradigm == ("Barnes",)


# --- M7 review regressions (2 Critical, 6 Important) ---

def test_degraded_family_member_blocks_the_metric():
    # C1: a session with the nose part missing used to report total_errors=0.0
    # and search_strategy="none" with a clean errors dict (R31#4 again).
    ctx = _ctx([(3, 10), (0, 50)])
    ctx.degraded = {"nose_at_hole4": ['body part "nose" not found']}
    for metric in ("total_errors", "target_checks", "search_strategy"):
        with pytest.raises(SphynxMetricError) as exc:
            compute_metric(metric, ctx, family="nose_at_hole")
        assert "degraded" in str(exc.value)


def test_strategy_scores_the_search_phase_only():
    # C2: an animal that went straight to the target and then kept searching
    # (as it must on a probe trial, where there is no escape box) was scored
    # "serial" on the post-target tail.
    ctx = _ctx([(0, 10), (3, 40), (4, 60), (5, 80), (6, 100)])
    assert compute_metric("search_strategy", ctx, family="nose_at_hole") == "direct"


def test_perseveration_is_not_a_serial_sweep():
    # I6: h3,h4,h3,h5,h3,h6 compressed to a clean sweep once repeats were
    # dropped by distinct-first-visit ordering.
    ctx = _ctx([(3, 10), (4, 25), (3, 40), (5, 55), (3, 70), (6, 85)])
    assert compute_metric("search_strategy", ctx, family="nose_at_hole") != "serial"


def test_nan_zone_angle_raises_rather_than_fabricating_a_ring():
    # I2: a NaN angle passed the `is None` guard and sorted arbitrarily.
    zones = _ring()
    zones[4].angle = float("nan")
    ctx = _ctx([(2, 10)], zones=zones)
    with pytest.raises(SphynxMetricError):
        compute_metric("search_strategy", ctx, family="nose_at_hole")
