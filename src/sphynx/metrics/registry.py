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
from sphynx.logging_setup import get_logger

_log = get_logger()

# geometry requirement -> predicate over the context
_GEOMETRY_CHECKS = {
    "zones": lambda ctx: bool(ctx.zones),
    "target_zone": lambda ctx: any(
        getattr(getattr(z, "roles", None), "is_target", False) for z in ctx.zones),
    "zone_angles": lambda ctx: bool(ctx.zones) and all(
        getattr(z, "angle", None) is not None for z in ctx.zones),
    "trajectory": lambda ctx: (
        ctx.trajectory_cm is not None and len(ctx.trajectory_cm) == 2
        and len(ctx.trajectory_cm[0]) > 0),
}


@dataclass
class MetricContext:
    """Everything a named metric may read."""

    acts: dict = field(default_factory=dict)       # act name -> per-frame mask
    stats: dict = field(default_factory=dict)      # act name -> ActStats
    events: dict = field(default_factory=dict)     # family name -> EventStream
    act_defs: list = field(default_factory=list)   # Act objects (provenance)
    zones: list = field(default_factory=list)
    # Carried over from ActContext.degraded (M3a): act name -> reasons. A
    # degraded act's mask is all-false for a reason that has nothing to do with
    # the animal, so metrics must refuse it rather than report "never happened".
    degraded: dict = field(default_factory=dict)
    # (x, y) of the animal in CENTIMETRES. The name carries the unit on purpose:
    # body-part traces are stored in PIXELS everywhere else, and feeding those in
    # would scale every path length by the calibration factor, silently.
    # metrics. Absent by default so a metric that needs it must declare it.
    trajectory_cm: tuple | None = None
    # No default: an assumed frame rate silently rescales every time metric.
    frame_rate: float | None = None

    def __post_init__(self):
        if self.frame_rate is None or not self.frame_rate > 0:
            raise SphynxValueError(
                f"MetricContext needs a positive frame_rate; got {self.frame_rate}")


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


def _as_tuple(value) -> tuple:
    """A bare string would decompose into characters, so wrap it."""
    if value is None:
        return ()
    if isinstance(value, str):
        return (value,)
    return tuple(value)


def register_metric(name, requires_acts=(), requires_events=(),
                    requires_geometry=(), paradigm=(), doc="", replace=False):
    """Register a named metric with its explicit dependencies."""
    requires_acts = _as_tuple(requires_acts)
    requires_events = _as_tuple(requires_events)
    requires_geometry = _as_tuple(requires_geometry)
    paradigm = _as_tuple(paradigm)
    for key in requires_geometry:
        if key not in _GEOMETRY_CHECKS:
            raise SphynxValueError(
                f'metric "{name}": unknown geometry requirement "{key}"; '
                f"known: {sorted(_GEOMETRY_CHECKS)}")

    def decorator(fn):
        if name in REGISTRY and not replace:
            # Silent overwrite would let import order decide which metric wins.
            raise SphynxValueError(
                f'metric "{name}" is already registered; pass replace=True to '
                "override it deliberately")
        REGISTRY[name] = MetricSpec(
            name=name, fn=fn, requires_acts=requires_acts,
            requires_events=requires_events,
            requires_geometry=requires_geometry,
            paradigm=paradigm, doc=doc or (fn.__doc__ or ""),
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
        elif ctx.degraded.get(name):
            # An all-false mask produced by a missing body part is not evidence
            # that the behaviour never happened (M3a / R31#4).
            reasons = "; ".join(ctx.degraded[name])
            missing.append(f'act "{name}" is degraded ({reasons})')
    for dep in spec.requires_events:
        name = _resolve(dep, params, spec.name)
        if name not in ctx.events:
            missing.append(f'event stream "{name}"')
            continue
        # A stream is only as trustworthy as the acts it was built from: if a
        # member act degraded, its episodes are missing for a reason that has
        # nothing to do with the animal (M3a / R31#4).
        bad = sorted(a.name for a in ctx.act_defs
                     if getattr(a, "family", "") == name and ctx.degraded.get(a.name))
        if bad:
            missing.append(
                f'event stream "{name}" has degraded member act(s) {bad}')
    for key in spec.requires_geometry:
        if not _GEOMETRY_CHECKS[key](ctx):
            missing.append(f"geometry: {key}")
    return missing


_ANY_PARADIGM = object()


def applies_to(spec: MetricSpec, paradigm) -> bool:
    """Whether a metric applies to the paradigm being computed.

    `paradigm` may be a single name or the whole lineage (child first, then its
    ancestors). Passing the lineage is what lets a paradigm INHERIT another's
    metrics: a child of Barnes declares no metrics of its own, so matching only
    its own name would silently drop every inherited Barnes metric."""
    if not spec.paradigm:
        return True
    if paradigm is _ANY_PARADIGM or paradigm is None:
        return True
    names = (paradigm,) if isinstance(paradigm, str) else tuple(paradigm)
    return any(name in spec.paradigm for name in names)


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


def compute_metrics(names, ctx: MetricContext, *, paradigm,
                    params_by_name=None) -> MetricResults:
    """Compute several metrics. Failures are RECORDED in `errors`, never dropped;
    metrics that do not apply to `paradigm` are skipped without an error.

    `paradigm` is required rather than defaulted: a forgotten argument would run
    a Barnes-only metric on an Open Field session. Pass `ANY_PARADIGM` to opt out
    of filtering deliberately."""
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
        except Exception as e:            # noqa: BLE001 - a bug in a metric fn
            # Do not abort the batch and discard the metrics already computed,
            # but do not disguise a real bug as a dependency problem either.
            out.errors[name] = f"unexpected {type(e).__name__}: {e}"
            _log.error('metric "%s" raised %s: %s', name, type(e).__name__, e)
    return out


def compute_metric_refs(refs, ctx: MetricContext, *, paradigm) -> MetricResults:
    """Compute a paradigm's MetricRef list, keying results by `ref.key`.

    This is what makes an alias live: a paradigm may call one metric several
    times with different parameters (`ratio_index` over two object pairs) and
    name each result, which computing by bare metric name cannot express."""
    out = MetricResults()
    for ref in refs:
        spec = REGISTRY.get(ref.name)
        if spec is not None and not applies_to(spec, paradigm):
            continue
        try:
            out.values[ref.key] = compute_metric(ref.name, ctx, **dict(ref.params))
        except SphynxMetricError as e:
            out.errors[ref.key] = str(e)
        except Exception as e:            # noqa: BLE001 - a bug in a metric fn
            out.errors[ref.key] = f"unexpected {type(e).__name__}: {e}"
            _log.error('metric "%s" raised %s: %s', ref.name, type(e).__name__, e)
    return out
