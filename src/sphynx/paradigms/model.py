"""Paradigm data model (S2 layer 6).

A paradigm is DATA: which zone roles it expects, which composites to build,
which act families and acts to evaluate, which named metrics to compute, its
config defaults, and the rules that decide whether a given preset satisfies it.
Behaviour lives in the engine; the paradigm only declares.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from sphynx.zones import ZoneSelector


@dataclass
class MetricRef:
    """A named metric plus the parameters this paradigm calls it with."""

    name: str = ""
    params: dict = field(default_factory=dict)


@dataclass
class CompositeSpec:
    """A composite zone the paradigm wants built from the geometry."""

    name: str = ""
    selector: ZoneSelector = field(default_factory=ZoneSelector)


@dataclass
class Paradigm:
    name: str = ""
    parent: str | None = None
    composites: list = field(default_factory=list)      # CompositeSpec
    families: list = field(default_factory=list)        # ActFamily
    acts: list = field(default_factory=list)            # Act
    metrics: list = field(default_factory=list)         # MetricRef
    config_defaults: dict = field(default_factory=dict)
    validation: list = field(default_factory=list)      # ValidationRule
    doc: str = ""
