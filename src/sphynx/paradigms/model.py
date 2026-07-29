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
    """A named metric plus the parameters this paradigm calls it with.

    `as_` names the result. A paradigm may legitimately call one metric several
    times with different parameters -- `ratio_index` over two different object
    pairs, `visit_order` over two families -- so identity for merging and for
    the output key is `as_ or name`, not the metric name alone."""

    name: str = ""
    params: dict = field(default_factory=dict)
    as_: str = ""

    @property
    def key(self) -> str:
        return self.as_ or self.name


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
