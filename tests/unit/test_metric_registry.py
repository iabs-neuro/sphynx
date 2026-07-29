import pytest

from sphynx.exceptions import SphynxError, SphynxMetricError, SphynxValueError
from sphynx.metrics.registry import (
    REGISTRY, MetricContext, MetricResults, compute_metric, compute_metrics,
    missing_requirements, register_metric,
)


@pytest.fixture(autouse=True)
def _isolate_registry():
    saved = dict(REGISTRY)
    REGISTRY.clear()
    yield
    REGISTRY.clear()
    REGISTRY.update(saved)


class _Zone:
    def __init__(self, name, is_target=False, angle=None):
        self.name = name
        self.roles = type("R", (), {"is_target": is_target})()
        self.angle = angle


def _ctx(**kw):
    base = dict(acts={"a": [True]}, stats={"a": object()}, events={"fam": object()},
                act_defs=[], zones=[_Zone("z1")], frame_rate=10.0)
    base.update(kw)
    return MetricContext(**base)


def test_metric_error_is_a_sphynx_error():
    assert issubclass(SphynxMetricError, SphynxError)


def test_register_and_compute():
    @register_metric("double_it", requires_acts=("a",))
    def _m(ctx, k=2):
        return 21 * k

    assert "double_it" in REGISTRY
    assert compute_metric("double_it", _ctx()) == 42


def test_unknown_metric_raises():
    with pytest.raises(SphynxMetricError):
        compute_metric("nope", _ctx())


def test_missing_act_dependency_raises_not_nan():
    @register_metric("needs_b", requires_acts=("b",))
    def _m(ctx):
        return 1.0

    with pytest.raises(SphynxMetricError) as exc:
        compute_metric("needs_b", _ctx())
    assert "b" in str(exc.value)


def test_missing_event_dependency_raises():
    @register_metric("needs_stream", requires_events=("other",))
    def _m(ctx):
        return 1.0

    with pytest.raises(SphynxMetricError):
        compute_metric("needs_stream", _ctx())


def test_missing_geometry_dependency_raises():
    @register_metric("needs_target", requires_geometry=("target_zone",))
    def _m(ctx):
        return 1.0

    with pytest.raises(SphynxMetricError):
        compute_metric("needs_target", _ctx())          # no zone is_target


def test_geometry_dependency_satisfied():
    @register_metric("needs_target2", requires_geometry=("target_zone",))
    def _m(ctx):
        return 7.0

    assert compute_metric("needs_target2", _ctx(zones=[_Zone("t", True)])) == 7.0


def test_unknown_geometry_key_rejected_at_registration():
    with pytest.raises(SphynxValueError):
        @register_metric("bad", requires_geometry=("teleporter",))
        def _m(ctx):
            return 1.0


def test_parameter_placeholder_dependency():
    @register_metric("uses_param", requires_acts=("$which",))
    def _m(ctx, which):
        return 5.0

    assert compute_metric("uses_param", _ctx(), which="a") == 5.0
    with pytest.raises(SphynxMetricError):
        compute_metric("uses_param", _ctx(), which="ghost")


def test_placeholder_without_parameter_raises():
    @register_metric("needs_param", requires_acts=("$which",))
    def _m(ctx, which=None):
        return 1.0

    with pytest.raises(SphynxMetricError):
        compute_metric("needs_param", _ctx())


def test_missing_requirements_lists_all():
    @register_metric("hungry", requires_acts=("x", "y"), requires_events=("s",))
    def _m(ctx):
        return 1.0

    missing = missing_requirements(REGISTRY["hungry"], _ctx(), {})
    assert len(missing) == 3


def test_compute_metrics_reports_values_and_errors():
    @register_metric("ok", requires_acts=("a",))
    def _ok(ctx):
        return 1.0

    @register_metric("bad", requires_acts=("ghost",))
    def _bad(ctx):
        return 2.0

    res = compute_metrics(["ok", "bad"], _ctx())
    assert isinstance(res, MetricResults)
    assert res.values == {"ok": 1.0}
    assert "bad" in res.errors        # recorded, never silently dropped


def test_paradigm_filter():
    @register_metric("barnes_only", paradigm=("Barnes",))
    def _m(ctx):
        return 1.0

    res = compute_metrics(["barnes_only"], _ctx(), paradigm="OF")
    assert res.values == {}
    assert res.errors == {}           # not applicable is not an error
    res2 = compute_metrics(["barnes_only"], _ctx(), paradigm="Barnes")
    assert res2.values == {"barnes_only": 1.0}
