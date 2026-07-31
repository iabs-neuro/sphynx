"""Barnes maze metrics (S2 layer 8).

Nothing here is Barnes-specific MACHINERY. The episodes come from a generic act
family (M4), the ordinal and error queries from the generic event stream (M5),
and the ring geometry from each zone's own `angle` (M1). That is what removes
the MATLAB `NumObjects=19` leak: the ring step is whatever the preset's holes
say it is, never a constant.

Metric list follows docs/TODO.md "Barnes maze metrics" (training-day and
test-day). `primary_latency` and `primary_errors` are already generic --
`latency_to_target` and `primary_errors` in metrics.builtins -- and are not
redefined here.

NaN policy (section 10): NaN means a legitimate empty result -- the target was
never found, no hole was ever checked. Anything that cannot be computed (a
family with no target member, holes without angles, a missing trajectory)
raises SphynxMetricError.
"""

from __future__ import annotations

import math

import numpy as np

from sphynx.exceptions import SphynxMetricError
from sphynx.metrics.registry import register_metric

_NAN = float("nan")
_BARNES = ("Barnes",)


# --- shared helpers -------------------------------------------------------

def _members(ctx, family):
    members = [a for a in ctx.act_defs if a.family == family]
    if not members:
        raise SphynxMetricError(f'family "{family}" has no member acts')
    return members


def _target_label(ctx, family) -> str:
    """The zone label of the family's target member."""
    targets = [a for a in _members(ctx, family) if a.is_target]
    if not targets:
        raise SphynxMetricError(
            f'family "{family}" has no member act on the target zone; '
            "the family selector does not cover it")
    if len(targets) > 1:
        raise SphynxMetricError(
            f'family "{family}" has {len(targets)} target members; '
            "exactly one hole must be marked as the target")
    return targets[0].zone_name or targets[0].name


def _zone_angles(ctx, family) -> dict:
    """Zone label -> angle in radians, for every member of the family.

    Angles are assigned by zones.geometry.assign_zone_angles once the arena
    centre is known. A hole without one cannot be placed on the ring, and
    guessing its position would fabricate an angular error."""
    by_name = {getattr(z, "name", None): z for z in ctx.zones}
    angles = {}
    missing = []
    for act in _members(ctx, family):
        label = act.zone_name or act.name
        zone = by_name.get(label)
        angle = getattr(zone, "angle", None) if zone is not None else None
        # A NaN angle is as unusable as a missing one, and would sort into an
        # arbitrary ring position -- fabricating a rotational order.
        if angle is None or not math.isfinite(float(angle)):
            missing.append(label)
        else:
            angles[label] = float(angle)
    if missing:
        raise SphynxMetricError(
            f"holes {sorted(missing)} have no usable angle; run "
            "assign_zone_angles against the arena centre before computing "
            "angular metrics")
    return angles


def _angular_distance_deg(a_rad, b_rad) -> float:
    """Absolute angular separation in degrees, folded into [0, 180]."""
    diff = math.degrees(a_rad - b_rad) % 360.0
    return diff if diff <= 180.0 else 360.0 - diff


def _ring_order(angles: dict) -> list:
    """Hole labels sorted by angle -- the physical order around the ring."""
    return [label for label, _ in sorted(angles.items(), key=lambda kv: kv[1])]


def _checked_labels(stream, target_label) -> list:
    """Distinct hole labels in order of first check, target included."""
    return [label for label in stream.unique_labels() if label is not None]


# --- latency and counts ---------------------------------------------------

@register_metric("total_latency", requires_events=("$family",),
                 paradigm=_BARNES)
def total_latency(ctx, family):
    """Seconds until the mouse ENTERS the target hole. `family` is the entry
    family (e.g. inside_hole), not the nose-check family. NaN when it never
    entered."""
    _target_label(ctx, family)
    event = ctx.events[family].first_where(lambda e: e.is_target)
    if event is None:
        return _NAN
    return event.start_frame / ctx.frame_rate


@register_metric("total_errors", requires_events=("$family",), paradigm=_BARNES)
def total_errors(ctx, family):
    """Every dip into a wrong hole, repeats included -- distinct from
    `primary_errors`, which counts distinct wrong holes before the target was
    first found."""
    _target_label(ctx, family)
    return float(sum(1 for e in ctx.events[family].events if not e.is_target))


@register_metric("non_target_checks", requires_events=("$family",),
                 paradigm=_BARNES)
def non_target_checks(ctx, family):
    """Test-day naming for `total_errors`."""
    return total_errors(ctx, family)


@register_metric("target_checks", requires_events=("$family",), paradigm=_BARNES)
def target_checks(ctx, family):
    """How many times the target hole was checked."""
    _target_label(ctx, family)
    return float(sum(1 for e in ctx.events[family].events if e.is_target))


@register_metric("time_near_target", requires_events=("$family",),
                 paradigm=_BARNES)
def time_near_target(ctx, family):
    """Seconds spent at the target hole, summed over every visit."""
    _target_label(ctx, family)
    return float(sum(e.duration_s for e in ctx.events[family].events if e.is_target))


@register_metric("target_ordinal", requires_events=("$family",), paradigm=_BARNES)
def target_ordinal(ctx, family):
    """0-based ordinal of the target among the holes actually checked: how many
    other holes were visited before it. NaN when it was never found."""
    label = _target_label(ctx, family)
    ordinal = ctx.events[family].order_of(label)
    return _NAN if ordinal is None else float(ordinal)


# --- angular metrics ------------------------------------------------------

@register_metric("angular_distance_first", requires_events=("$family",),
                 requires_geometry=("zones",), paradigm=_BARNES)
def angular_distance_first(ctx, family):
    """Degrees between the FIRST hole the animal checked and the target.
    NaN when no hole was checked at all."""
    target = _target_label(ctx, family)
    angles = _zone_angles(ctx, family)
    first = ctx.events[family].first()
    if first is None or first.label is None:
        return _NAN
    if first.label not in angles:
        raise SphynxMetricError(
            f'event label "{first.label}" is not a member of family "{family}"')
    return _angular_distance_deg(angles[first.label], angles[target])


@register_metric("mean_angular_distance", requires_events=("$family",),
                 requires_geometry=("zones",), paradigm=_BARNES)
def mean_angular_distance(ctx, family):
    """Mean angular distance from the target over the DISTINCT holes checked
    (the target itself contributes its own 0). NaN when nothing was checked."""
    target = _target_label(ctx, family)
    angles = _zone_angles(ctx, family)
    checked = _checked_labels(ctx.events[family], target)
    if not checked:
        return _NAN
    unknown = [c for c in checked if c not in angles]
    if unknown:
        raise SphynxMetricError(
            f'event labels {sorted(unknown)} are not members of family "{family}"')
    return float(np.mean([_angular_distance_deg(angles[c], angles[target])
                          for c in checked]))


# --- path length ----------------------------------------------------------

def _path_length_cm(x, y, upto=None) -> float:
    """Trajectory length in cm.

    Gaps are BRIDGED, not dropped: measuring between the finite samples either
    side of a dropout keeps the traversal in the total. Dropping the step
    instead (which is what filtering the diffs does) silently understates the
    path by the whole distance covered while tracking was lost."""
    x = np.asarray(x, dtype=float).ravel()
    y = np.asarray(y, dtype=float).ravel()
    if upto is not None:
        x, y = x[: upto + 1], y[: upto + 1]
    good = np.isfinite(x) & np.isfinite(y)
    x, y = x[good], y[good]
    if x.size < 2:
        return _NAN
    return float(np.hypot(np.diff(x), np.diff(y)).sum())


@register_metric("path_length", requires_geometry=("trajectory",))
def path_length(ctx):
    """Distance travelled over the whole trial, in cm.

    Not Barnes-specific: every paradigm wants it, so it carries no paradigm
    restriction."""
    return _path_length_cm(*ctx.trajectory_cm)


@register_metric("path_length_to_target", requires_events=("$family",),
                 requires_geometry=("trajectory",), paradigm=_BARNES)
def path_length_to_target(ctx, family):
    """Distance travelled up to the first target visit, in cm. NaN when the
    target was never found."""
    _target_label(ctx, family)
    event = ctx.events[family].first_where(lambda e: e.is_target)
    if event is None:
        return _NAN
    return _path_length_cm(*ctx.trajectory_cm, upto=event.start_frame)


# --- search strategy ------------------------------------------------------

@register_metric("search_strategy", requires_events=("$family",),
                 requires_geometry=("zones",), paradigm=_BARNES)
def search_strategy(ctx, family, max_direct_errors: int = 3,
                    direct_arc_deg: float = 60.0, min_serial_run: int = 3):
    """Classify the search as "direct", "serial" or "random" (Pitts 2018).

    The thresholds are parameters rather than magic numbers, and the rule is:

    * **direct** -- the target was found after checking at most
      `max_direct_errors` distinct wrong holes, AND every hole checked lay
      within `direct_arc_deg` of the target. Going straight to the right part
      of the ring is the spatial strategy.
    * **serial** -- the checked holes advance around the ring in ONE rotational
      direction for a run of at least `min_serial_run` adjacent holes.
    * **random** -- anything else, once at least one hole was checked.

    Returns "none" when no hole was checked at all: that is an absence of
    searching, not a strategy."""
    target = _target_label(ctx, family)
    angles = _zone_angles(ctx, family)
    stream = ctx.events[family]
    events = stream.events

    # Only the SEARCH PHASE counts: everything up to and including the first
    # target check. On a probe trial there is no escape box, so the animal keeps
    # searching afterwards; scoring that tail would make "direct" almost
    # unreachable for an animal that went straight to the target.
    first_target = next((i for i, e in enumerate(events) if e.is_target), None)
    found = first_target is not None
    phase = events[: first_target + 1] if found else list(events)

    # Ordered labels with immediate repeats collapsed: re-checking one hole
    # twice in a row is one step, but leaving and coming back is not, so a
    # perseverative h3,h4,h3,h5 must not compress into a serial sweep.
    sequence = []
    for event in phase:
        if event.label is None:
            continue
        if not sequence or event.label != sequence[-1]:
            sequence.append(event.label)
    if not sequence:
        return "none"

    checked = list(dict.fromkeys(sequence))

    ring = _ring_order(angles)
    position = {label: i for i, label in enumerate(ring)}
    n_holes = len(ring)

    wrong_before = len([c for c in checked if c != target])

    within_arc = all(
        _angular_distance_deg(angles[c], angles[target]) <= direct_arc_deg
        for c in checked)
    if found and wrong_before <= max_direct_errors and within_arc:
        return "direct"

    # Serial: a run of adjacent holes stepped in one direction around the ring.
    run, best = 1, 1
    previous_step = None
    for a, b in zip(sequence, sequence[1:]):
        step = (position[b] - position[a]) % n_holes
        step = step if step <= n_holes // 2 else step - n_holes   # signed
        if abs(step) == 1 and (previous_step is None or step == previous_step):
            run += 1
        else:
            run = 1
        previous_step = step if abs(step) == 1 else None
        best = max(best, run)
    if best >= min_serial_run:
        return "serial"

    return "random"
