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


def expand_family(family: ActFamily, zones) -> list[Act]:
    """Expand a family into one concrete act per zone matching its selector."""
    chosen = select(zones, family.selector)
    if not chosen:
        raise SphynxValueError(
            f'act family "{family.name}": selector matched no zones')

    acts: list[Act] = []
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
    bespoke per-paradigm code (S2 layer 3 -> layer 5)."""
    members = [
        a for a in acts
        if (a.family if family is None else a.family == family) and a.family
    ]
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
