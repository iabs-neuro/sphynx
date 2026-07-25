"""Open Field paradigm — minimal declarative bundle. The full paradigm
system (roles, composite zones, act families, named-metric registry,
inheritance) is designed in S2."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class Paradigm:
    name: str
    builtin_acts: list[str] = field(default_factory=list)
    metrics: list[str] = field(default_factory=list)


def open_field() -> Paradigm:
    """Empty arena, no objects: default speed acts + freezing + rear;
    generic metrics distance / mean speed / arena occupancy."""
    return Paradigm(
        name="OF",
        builtin_acts=["rest", "walk", "locomotion", "freezing", "rear"],
        metrics=["distance", "mean_speed", "occupancy"],
    )
