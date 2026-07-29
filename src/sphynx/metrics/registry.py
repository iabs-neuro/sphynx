"""Named-metric registry (S2 layer 5).

Auto `act x stat` metrics are NOT registered -- they are generated per act by
sphynx.acts.stats. Only named metrics register, and each declares what it needs.
Explicit dependencies buy three things: a computable evaluation order, a clear
error instead of a silent NaN when something upstream is absent, and per-paradigm
filtering for the GUI.

A dependency may be a parameter placeholder ("$family"), so a parameterised
metric keeps honest dependencies.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from sphynx.exceptions import SphynxMetricError, SphynxValueError

# geometry requirement -> predicate over the context
_GEOMETRY_CHECKS = {
    "zones": lambda ctx: bool(ctx.zones),
    "target_zone": lambda ctx: any(
        getattr(getattr(z, "roles", None), "is_target", False) for z in ctx.zones),
    "zone_angles": lambda ctx: bool(ctx.zones) and all(
        getattr(z, "angle", None) is not None for z in ctx.zones),
}


@dataclass
class MetricContext:
    """Everything a named metric may read."""

    acts: dict = field(default_factory=dict)       # act name -> per-frame mask
    stats: dict = field(default_factory=dict)      # act name -> ActStats
    events: dict = field(default_factory=dict)     # family name -> EventStream
    act_defs: list = field(default_factory=list)   # Act objects (provenance)
    zones: list = field(default_factory=list)
    frame_rate: float = 30.0


@dataclass
class MetricSpec:
    name: str
    fn: object
    requires_acts: tuple = ()
    requires_events: tuple = ()
    requires_geometry: tuple = ()
    paradigm: tuple = ()
    doc: str = ""


@dataclass
class MetricResults:
    values: dict = field(default_factory=dict)
    errors: dict = field(default_factory=dict)     # metric name -> message


REGISTRY: dict = {}


def register_metric(name, requires_acts=(), requires_events=(),
                    requires_geometry=(), paradigm=(), doc=""):
    """Register a named metric with its explicit dependencies."""
    for key in requires_geometry:
        if key not in _GEOMETRY_CHECKS:
            raise SphynxValueError(
                f'metric "{name}": unknown geometry requirement "{key}"; '
                f"known: {sorted(_GEOMETRY_CHECKS)}")

    def decorator(fn):
        REGISTRY[name] = MetricSpec(
            name=name, fn=fn, requires_acts=tuple(requires_acts),
            requires_events=tuple(requires_events),
            requires_geometry=tuple(requires_geometry),
            paradigm=tuple(paradigm), doc=doc or (fn.__doc__ or ""),
        )
        return fn

    return decorator


def _resolve(dep, params, metric_name):
    """Resolve a "$param" placeholder against the call's parameters."""
    if isinstance(dep, str) and dep.startswith("$"):
        key = dep[1:]
        if key not in params or params[key] is None:
            raise SphynxMetricError(
                f'metric "{metric_name}" needs parameter "{key}"')
        return params[key]
    return dep


def missing_requirements(spec: MetricSpec, ctx: MetricContext, params) -> list:
    """Human-readable list of everything the metric needs but cannot see."""
    params = params or {}
    missing = []
    for dep in spec.requires_acts:
        name = _resolve(dep, params, spec.name)
        if name not in ctx.acts and name not in ctx.stats:
            missing.append(f'act "{name}"')
    for dep in spec.requires_events:
        name = _resolve(dep, params, spec.name)
        if name not in ctx.events:
            missing.append(f'event stream "{name}"')
    for key in spec.requires_geometry:
        if not _GEOMETRY_CHECKS[key](ctx):
            missing.append(f"geometry: {key}")
    return missing


def applies_to(spec: MetricSpec, paradigm) -> bool:
    return not spec.paradigm or paradigm is None or paradigm in spec.paradigm


def compute_metric(name, ctx: MetricContext, **params):
    """Compute one metric. Raises SphynxMetricError when it CANNOT be computed;
    a metric that legitimately has no value returns NaN itself."""
    spec = REGISTRY.get(name)
    if spec is None:
        raise SphynxMetricError(f'unknown metric "{name}"')
    missing = missing_requirements(spec, ctx, params)
    if missing:
        raise SphynxMetricError(
            f'metric "{name}" cannot be computed; missing ' + ", ".join(missing))
    return spec.fn(ctx, **params)


def compute_metrics(names, ctx: MetricContext, params_by_name=None,
                    paradigm=None) -> MetricResults:
    """Compute several metrics. Failures are RECORDED in `errors`, never dropped;
    metrics that do not apply to `paradigm` are skipped without an error."""
    params_by_name = params_by_name or {}
    out = MetricResults()
    for name in names:
        spec = REGISTRY.get(name)
        if spec is not None and not applies_to(spec, paradigm):
            continue
        try:
            out.values[name] = compute_metric(
                name, ctx, **params_by_name.get(name, {}))
        except SphynxMetricError as e:
            out.errors[name] = str(e)
    return out
