"""Resolve the body parts an act needs, through declared fallback chains.

Never substitutes silently: every substitution is logged and flips `degraded`;
every unresolvable part lands in `missing` (also logged). Callers decide what a
degraded act means -- this module only reports (S2 layer 4a, section 10).
"""

from __future__ import annotations

from dataclasses import dataclass, field

from sphynx.bodyparts.fallbacks import DEFAULT_FALLBACKS
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


def resolve_act_parts(
    required, body_parts, fallback=None, use_defaults: bool = True
) -> PartResolution:
    res = PartResolution()
    for name in (required or []):
        idx = resolve_part(body_parts, name)
        if idx is not None:
            res.indices[name] = idx
            continue

        if fallback is not None and name in fallback:
            chain = list(fallback[name])          # explicit chain wins outright
        elif use_defaults:
            chain = list(DEFAULT_FALLBACKS.get(name, []))
        else:
            chain = []

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
