"""Act families: one template bound to a zone CLASS, expanded over the geometry.

A family declares a ZoneSelector, never a zone name. Expansion produces one
concrete act per matching zone, inheriting that zone's identity and roles, which
is what removes the MATLAB `NumObjects=19` hardcode: the family is as large as
the preset actually is (S2 layer 3).
"""

from __future__ import annotations

import copy
from dataclasses import dataclass, field

from sphynx.acts.events import EventStream, events_from_act
from sphynx.acts.schema import Act
from sphynx.exceptions import SphynxValueError
from sphynx.logging_setup import get_logger
from sphynx.zones.select import ZoneSelector, select

_log = get_logger()


@dataclass
class ActFamily:
    name: str = ""
    selector: ZoneSelector = field(default_factory=ZoneSelector)
    template: Act = field(default_factory=Act)
    name_pattern: str = "{family}{index}"


def _check_template_uses_its_zone(family: ActFamily) -> None:
    """A family rebinds `zones` per member, so the template must be a kind of act
    that actually reads its zone. Otherwise expansion yields N identical acts
    under N different zone labels -- N duplicate event sets."""
    t = family.template
    if t.expr is not None or (t.type or "").lower() == "complex":
        raise SphynxValueError(
            f'act family "{family.name}": a complex/expression template ignores '
            "its zone binding, so expanding it would produce identical members")
    kind = (t.special_kind or "").lower()
    if (t.type or "").lower() == "special" and kind not in ("allinzone",):
        _log.warning(
            'Act family "%s": special kind "%s" does not read its zone; '
            "members will differ only by label", family.name, t.special_kind)


def expand_family(family: ActFamily, zones) -> list[Act]:
    """Expand a family into one concrete act per zone matching its selector."""
    if not family.name:
        raise SphynxValueError("act family needs a name")
    _check_template_uses_its_zone(family)

    chosen = select(zones, family.selector)
    if not chosen:
        raise SphynxValueError(
            f'act family "{family.name}": selector matched no zones')

    seen_zones = set()
    for z in chosen:
        if z.name in seen_zones:
            # Provenance is keyed by zone name: duplicates would collapse two
            # members into one label and lose a zone from unique_labels().
            raise SphynxValueError(
                f'act family "{family.name}": duplicate zone name "{z.name}"')
        seen_zones.add(z.name)

    acts: list[Act] = []
    used_names: dict = {}
    for position, z in enumerate(chosen, start=1):
        # deep copy so members never share the template's mutable fields
        act = copy.deepcopy(family.template)
        idx = z.index
        if idx is None:
            _log.warning(
                'Zone "%s" has no class index; numbering family "%s" by position',
                z.name, family.name)
            idx = position
        act.name = family.name_pattern.format(
            family=family.name, index=idx, zone=z.name)
        if act.name in used_names:
            # Results are keyed by act name: a collision would drop one member's
            # mask and read another's twice under two different zone labels.
            raise SphynxValueError(
                f'act family "{family.name}": zones "{used_names[act.name]}" and '
                f'"{z.name}" both render act name "{act.name}"; '
                "use a name_pattern that includes {zone}")
        used_names[act.name] = z.name
        act.zones = [z.name]
        act.family = family.name
        act.zone_name = z.name
        act.zone_index = idx
        act.is_target = bool(z.roles.is_target)
        acts.append(act)
    return acts


def family_event_stream(acts, results, frame_rate, family=None) -> EventStream:
    """Merge a family's per-member episodes into ONE time-ordered stream.

    Every event is labelled with the zone it came from, so order-of-visit and
    errors-before-target become generic queries over the stream instead of
    bespoke per-paradigm code (S2 layer 3 -> layer 5).

    `family=None` infers the family when the acts contain exactly one; with
    several it RAISES rather than interleaving unrelated streams (a wall event
    inside a hole stream would silently shift every visit ordinal)."""
    if family is not None and not family:
        raise SphynxValueError("family must be a non-empty name or None")

    present = []
    for a in acts:
        if a.family and a.family not in present:
            present.append(a.family)

    if family is None:
        if not present:
            return EventStream([])
        if len(present) > 1:
            raise SphynxValueError(
                f"acts span several families {present}; name the one to merge")
        family = present[0]
    elif family not in present:
        raise SphynxValueError(f'no acts belong to family "{family}"')

    members = [a for a in acts if a.family == family]
    events = []
    for act in members:
        if act.name not in results:
            raise SphynxValueError(
                f'family member "{act.name}" has no computed result')
        events.extend(events_from_act(
            results[act.name], frame_rate, act_name=act.name,
            label=act.zone_name or act.name, index=act.zone_index,
            is_target=act.is_target))
    events.sort(key=lambda e: (e.start_frame, e.end_frame))
    return EventStream(events)
