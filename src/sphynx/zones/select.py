"""Declarative zone selection (S2 layer 2). Selectors are data, not lambdas,
so paradigms can serialize them."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from sphynx.exceptions import SphynxGeometryError, SphynxValueError
from sphynx.zones.strips import Zone


@dataclass
class ZoneSelector:
    zone_class: str | None = None
    is_target: bool | None = None
    index: int | None = None
    tags_all: list | None = None
    tags_any: list | None = None

    def matches(self, zone) -> bool:
        if self.zone_class is not None and zone.zone_class != self.zone_class:
            return False
        if self.is_target is not None and bool(zone.roles.is_target) != self.is_target:
            return False
        if self.index is not None and zone.index != self.index:
            return False
        tags = set(zone.roles.tags)
        # A bare string would silently decompose into characters via set();
        # that is a wrong-result trap, so reject it (section 10).
        if isinstance(self.tags_all, str) or isinstance(self.tags_any, str):
            raise SphynxValueError("tags_all/tags_any must be lists of tags, not a str")
        # Empty tag lists are don't-care on BOTH sides (symmetric).
        if self.tags_all and not set(self.tags_all).issubset(tags):
            return False
        if self.tags_any and tags.isdisjoint(set(self.tags_any)):
            return False
        return True


def select(zones, selector: ZoneSelector) -> list:
    return [z for z in zones if selector.matches(z)]


def union_mask(zones) -> np.ndarray:
    if not zones:
        raise SphynxGeometryError("union_mask needs at least one zone")
    masks = [np.asarray(z.maskfilled) > 0 for z in zones]
    shape = masks[0].shape
    for m in masks[1:]:
        if m.shape != shape:
            raise SphynxGeometryError(
                f"zone masks have mismatched shapes: {shape} vs {m.shape}")
    out = np.zeros(shape, dtype=bool)
    for m in masks:
        out |= m
    return out


def make_composite(name, zones, selector, zone_class: str = "composite") -> Zone:
    chosen = select(zones, selector)
    if not chosen:
        raise SphynxValueError(f'composite "{name}": selector matched no zones')
    z = Zone(name, "area", union_mask(chosen), zone_class=zone_class)
    z.members = [c.name for c in chosen]
    return z


def target_zone(zones, zone_class: str = "hole") -> Zone:
    hits = select(zones, ZoneSelector(zone_class=zone_class, is_target=True))
    if len(hits) != 1:
        raise SphynxValueError(
            f"expected exactly one target {zone_class}; found {len(hits)}")
    return hits[0]


def neutral_composite(name, zones, zone_class: str = "hole") -> Zone:
    return make_composite(
        name, zones, ZoneSelector(zone_class=zone_class, is_target=False))


def class_composite(name, zones, zone_class) -> Zone:
    return make_composite(name, zones, ZoneSelector(zone_class=zone_class))
