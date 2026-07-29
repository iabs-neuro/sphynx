"""Declarative zone selection (S2 layer 2). Selectors are data, not lambdas,
so paradigms can serialize them."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class ZoneSelector:
    zone_class: str | None = None
    is_target: bool | None = None
    tags_all: list | None = None
    tags_any: list | None = None

    def matches(self, zone) -> bool:
        if self.zone_class is not None and zone.zone_class != self.zone_class:
            return False
        if self.is_target is not None and bool(zone.roles.is_target) != self.is_target:
            return False
        tags = set(zone.roles.tags)
        if self.tags_all is not None and not set(self.tags_all).issubset(tags):
            return False
        if self.tags_any is not None and tags.isdisjoint(set(self.tags_any)):
            return False
        return True


def select(zones, selector: ZoneSelector) -> list:
    return [z for z in zones if selector.matches(z)]
