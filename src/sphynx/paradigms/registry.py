"""Paradigm registry + inheritance resolution (S2 layer 6)."""

from __future__ import annotations

import copy

from sphynx.exceptions import SphynxValueError
from sphynx.paradigms.model import Paradigm

PARADIGMS: dict = {}


def register_paradigm(paradigm: Paradigm, replace: bool = False) -> Paradigm:
    if not paradigm.name:
        raise SphynxValueError("paradigm needs a name")
    if paradigm.name in PARADIGMS and not replace:
        raise SphynxValueError(
            f'paradigm "{paradigm.name}" is already registered; pass '
            "replace=True to override it deliberately")
    PARADIGMS[paradigm.name] = paradigm
    return paradigm


def get_paradigm(name) -> Paradigm:
    p = PARADIGMS.get(name)
    if p is None:
        raise SphynxValueError(
            f'unknown paradigm "{name}"; known: {sorted(PARADIGMS)}')
    return p


def _merge_by_name(base, child, key=lambda item: item.name, what="entry",
                   owner=""):
    """Child entries override same-keyed parent entries; order is parent-first,
    then any genuinely new child entries.

    Duplicates WITHIN one paradigm's own list are an authoring error: silently
    collapsing them would drop a metric or an act the author declared."""
    seen = set()
    for item in child:
        k = key(item)
        if k in seen:
            raise SphynxValueError(
                f'paradigm "{owner}" declares {what} "{k}" twice; '
                "give them distinct names")
        seen.add(k)

    out = [copy.deepcopy(item) for item in base]
    index = {key(item): i for i, item in enumerate(out)}
    for item in child:
        k = key(item)
        if k in index:
            out[index[k]] = copy.deepcopy(item)
        else:
            index[k] = len(out)
            out.append(copy.deepcopy(item))
    return out


def _chain(paradigm: Paradigm, registry=None) -> list:
    """Ancestors root-first, ending with `paradigm` itself."""
    registry = PARADIGMS if registry is None else registry
    chain = [paradigm]
    seen = {paradigm.name}
    current = paradigm
    while current.parent is not None:
        if current.parent == current.name:
            raise SphynxValueError(
                f'paradigm "{current.name}" is its own parent')
        parent = registry.get(current.parent)
        if parent is None:
            raise SphynxValueError(
                f'paradigm "{current.name}" has unknown parent '
                f'"{current.parent}"')
        if parent.name in seen:
            raise SphynxValueError(
                f'paradigm parent cycle at "{parent.name}" '
                f"(chain: {[p.name for p in chain]})")
        seen.add(parent.name)
        chain.append(parent)
        current = parent
    chain.reverse()
    return chain


def resolve_paradigm(name_or_paradigm, registry=None) -> Paradigm:
    """Flatten a paradigm against its ancestors. Returns a NEW Paradigm; the
    registered ones are never mutated."""
    if registry is None:
        registry = PARADIGMS
    paradigm = (name_or_paradigm if isinstance(name_or_paradigm, Paradigm)
                else (registry.get(name_or_paradigm) or get_paradigm(name_or_paradigm)))
    chain = _chain(paradigm, registry)

    merged = Paradigm(name=paradigm.name, doc=paradigm.doc)
    for link in chain:
        merged.composites = _merge_by_name(
            merged.composites, link.composites, what="composite", owner=link.name)
        merged.families = _merge_by_name(
            merged.families, link.families, what="family", owner=link.name)
        merged.acts = _merge_by_name(
            merged.acts, link.acts, what="act", owner=link.name)
        merged.metrics = _merge_by_name(
            merged.metrics, link.metrics, key=lambda m: m.key,
            what="metric", owner=link.name)
        merged.validation = _merge_by_name(
            merged.validation, link.validation, key=lambda r: r.code,
            what="validation rule", owner=link.name)
        merged.config_defaults = {**merged.config_defaults,
                                  **copy.deepcopy(link.config_defaults)}
    return merged


def lineage(name_or_paradigm, registry=None) -> tuple:
    """The paradigm's own name followed by its ancestors, child first.

    Pass this to metrics.compute_metrics / compute_metric_refs so a paradigm
    INHERITS its parent's metrics: matching on the child's name alone would
    silently drop every metric registered against the parent."""
    paradigm = (name_or_paradigm if isinstance(name_or_paradigm, Paradigm)
                else get_paradigm(name_or_paradigm))
    return tuple(link.name for link in reversed(_chain(paradigm, registry)))
