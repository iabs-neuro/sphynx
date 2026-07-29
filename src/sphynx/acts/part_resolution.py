"""Resolve the body parts an act needs, through declared fallback chains.

Never substitutes silently: every substitution is logged and flips `degraded`;
every unresolvable part lands in `missing` (also logged). Callers decide what a
degraded act means -- this module only reports (S2 layer 4a, section 10).
"""

from __future__ import annotations

from dataclasses import dataclass, field, fields

from sphynx.bodyparts.fallbacks import DEFAULT_FALLBACKS, GEOMETRY_CRITICAL
from sphynx.bodyparts.identify import identify_parts
from sphynx.bodyparts.resolve import resolve_part
from sphynx.logging_setup import get_logger

_log = get_logger()


@dataclass
class PartResolution:
    indices: dict = field(default_factory=dict)        # requested name -> 0-based index
    substitutions: dict = field(default_factory=dict)  # requested name -> name used
    missing: list = field(default_factory=list)        # unresolvable requested names
    degraded: bool = False

    @property
    def ok(self) -> bool:
        return not self.missing


def _canonical(name):
    """Canonical field name for an alias, or None. Lets a suggestion registry
    keyed by canonical names ("head_center") answer a request phrased in any
    alias the schema uses ("headcenter")."""
    p = identify_parts([str(name)])
    for f in fields(p):
        if getattr(p, f.name) is not None:
            return f.name
    return None


def _chain_for(name, fallback, use_defaults):
    """The ordered proxy chain for one requested part. An act-declared chain
    wins outright; the suggestion registry is consulted only on request."""
    if fallback:
        if name in fallback:
            return list(fallback[name])
        canon = _canonical(name)
        if canon is not None and canon in fallback:
            return list(fallback[canon])
    if not use_defaults:
        return []
    canon = _canonical(name)
    if canon is not None and canon in GEOMETRY_CRITICAL:
        return []                    # never proxy rear / head-angle geometry
    chain = DEFAULT_FALLBACKS.get(name)
    if chain is None and canon is not None:
        chain = DEFAULT_FALLBACKS.get(canon)
    return list(chain or [])


def resolve_act_parts(
    required, body_parts, fallback=None, use_defaults: bool = False
) -> PartResolution:
    """Resolve each required part, substituting only through a DECLARED chain.

    `use_defaults` is off by design: without an act-declared chain a missing
    part is reported, never stood in for (S2 layer 4a, section 10)."""
    res = PartResolution()
    for name in (required or []):
        idx = resolve_part(body_parts, name)
        if idx is not None:
            res.indices[name] = idx
            continue

        chain = _chain_for(name, fallback, use_defaults)

        for candidate in chain:
            alt = resolve_part(body_parts, candidate)
            if alt is not None:
                res.indices[name] = alt
                res.substitutions[name] = candidate
                res.degraded = True
                _log.warning(
                    'Body part "%s" absent; falling back to "%s"', name, candidate)
                break
        else:
            res.missing.append(name)
            res.degraded = True
            _log.warning(
                'Body part "%s" absent and no fallback resolved; act degraded', name)
    return res
