"""Act families: one template bound to a zone CLASS, expanded over the geometry.

A family declares a ZoneSelector, never a zone name. Expansion produces one
concrete act per matching zone, inheriting that zone's identity and roles, which
is what removes the MATLAB `NumObjects=19` hardcode: the family is as large as
the preset actually is (S2 layer 3).
"""

from __future__ import annotations

import copy
from dataclasses import dataclass, field

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
