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


def _family_members(ctx, family):
    members = [a for a in ctx.act_defs if a.family == family]
    if not members:
        raise SphynxMetricError(f'family "{family}" has no member acts')
    return members


def _family_labels(ctx, family):
    """The zone labels the family COULD produce, from its member acts."""
    return {a.zone_name or a.name for a in _family_members(ctx, family)}


@register_metric("time_to_first", requires_events=("$family",))
def time_to_first(ctx, family, label=None):
    """Seconds to the first episode of the family, or of `label` when given.
    NaN when it never happened -- but an unknown label raises, since "never
    visited" and "no such zone" are different answers."""
    stream = ctx.events[family]
    if label is None:
        event = stream.first()
    else:
        known = _family_labels(ctx, family)
        if label not in known:
            raise SphynxMetricError(
                f'family "{family}" has no zone labelled "{label}"; '
                f"known: {sorted(known)}")
        event = stream.first_where(lambda e: e.label == label)
    if event is None:
        return _NAN
    return event.start_frame / ctx.frame_rate


def _require_target_member(ctx, family):
    """The registry checks that a target ZONE exists; this checks that the
    family actually covers it. A target declared in the geometry but not carried
    by any member act means the family was expanded over the wrong selector --
    a setup error, not "the animal never went there"."""
    if not any(a.is_target for a in _family_members(ctx, family)):
        raise SphynxMetricError(
            f'family "{family}" has no member act on the target zone; '
            "the family selector does not cover it")


@register_metric("latency_to_target", requires_events=("$family",),
                 requires_geometry=("target_zone",))
def latency_to_target(ctx, family):
    """Seconds to the first visit of the target zone. NaN when the target was
    declared but never visited (no target declared at all, or a family that
    does not cover it, is a setup error and raises)."""
    _require_target_member(ctx, family)
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
    _require_target_member(ctx, family)
    stream = ctx.events[family]
    event = stream.first_where(lambda e: e.is_target)
    if event is None:
        return _NAN
    return float(len(stream.distinct_labels_before(event)))


@register_metric("time_to_completion", requires_events=("$family",))
def time_to_completion(ctx, family):
    """Seconds until every member zone of the family had been visited at least
    once. NaN when the family was never completed.

    Counts DISTINCT member zone labels, not member acts, and ignores any event
    whose label is not one of them: comparing against a raw act count would
    report NaN for a family whose zones share a label, or finish early on a
    foreign event that leaked into the stream."""
    expected = _family_labels(ctx, family)
    seen = set()
    for event in ctx.events[family].events:
        if event.label not in expected:
            continue
        seen.add(event.label)
        if seen == expected:
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
