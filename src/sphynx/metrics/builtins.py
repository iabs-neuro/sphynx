"""Universal act-derived metrics (S2 layer 5).

Every metric here is generic: it works over the merged EventStream of ANY act
family, so `visit_order` replaces the hardcoded order_barnes and `ratio_index`
replaces a bespoke novel/familiar discrimination index.

NaN policy: a metric returns NaN only for a legitimate empty result (a declared
target that was never visited, a family never completed, a ratio of two
zero-length acts). Anything the metric CANNOT compute raises SphynxMetricError
via the registry's dependency check.
"""

from __future__ import annotations

from sphynx.exceptions import SphynxMetricError
from sphynx.metrics.registry import register_metric

_NAN = float("nan")


@register_metric("visit_order", requires_events=("$family",))
def visit_order(ctx, family):
    """Zone labels in order of first visit. Replaces order_barnes."""
    return ctx.events[family].unique_labels()


@register_metric("time_to_first", requires_events=("$family",))
def time_to_first(ctx, family, label=None):
    """Seconds to the first episode of the family, or of `label` when given.
    NaN when it never happened."""
    stream = ctx.events[family]
    event = stream.first() if label is None else stream.first_where(
        lambda e: e.label == label)
    if event is None:
        return _NAN
    return event.start_frame / ctx.frame_rate


@register_metric("latency_to_target", requires_events=("$family",),
                 requires_geometry=("target_zone",))
def latency_to_target(ctx, family):
    """Seconds to the first visit of the target zone. NaN when the target was
    declared but never visited (no target declared at all is a dependency
    error, raised by the registry)."""
    event = ctx.events[family].first_where(lambda e: e.is_target)
    if event is None:
        return _NAN
    return event.start_frame / ctx.frame_rate


@register_metric("primary_errors", requires_events=("$family",),
                 requires_geometry=("target_zone",))
def primary_errors(ctx, family):
    """Distinct non-target zones checked before the target was first found.
    A re-check of the same zone counts once. NaN when the target was never
    visited."""
    stream = ctx.events[family]
    event = stream.first_where(lambda e: e.is_target)
    if event is None:
        return _NAN
    return float(len(stream.distinct_labels_before(event)))


@register_metric("time_to_completion", requires_events=("$family",))
def time_to_completion(ctx, family):
    """Seconds until every member zone of the family had been visited at least
    once. NaN when the family was never completed."""
    members = [a for a in ctx.act_defs if a.family == family]
    if not members:
        raise SphynxMetricError(f'family "{family}" has no member acts')
    total = len(members)
    seen = []
    for event in ctx.events[family].events:
        if event.label not in seen:
            seen.append(event.label)
            if len(seen) == total:
                return event.start_frame / ctx.frame_rate
    return _NAN


def _stat_value(ctx, act_name, stat):
    stats = ctx.stats.get(act_name)
    if stats is None:
        raise SphynxMetricError(f'no stats computed for act "{act_name}"')
    if not hasattr(stats, stat):
        raise SphynxMetricError(f'ActStats has no field "{stat}"')
    return float(getattr(stats, stat))


@register_metric("ratio_index", requires_acts=("$act_a", "$act_b"))
def ratio_index(ctx, act_a, act_b, stat="duration_s"):
    """(A - B) / (A + B) between ANY two acts, over any ActStats field.
    NOR discrimination is this metric called with the two object acts.
    NaN when both acts are zero -- the index is undefined, not zero."""
    a = _stat_value(ctx, act_a, stat)
    b = _stat_value(ctx, act_b, stat)
    total = a + b
    if total == 0:
        return _NAN
    return (a - b) / total
