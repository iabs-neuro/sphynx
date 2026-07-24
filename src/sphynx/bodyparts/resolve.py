"""Alias-tolerant body-part lookup. Port of sphynx.bodyparts.resolvePart."""

from __future__ import annotations

from dataclasses import fields

from sphynx.bodyparts.identify import identify_parts


def resolve_part(body_parts, query_name) -> int | None:
    """Find a body-part index by alias-tolerant name match: exact
    (case-insensitive) first, else resolve query and list to the same
    canonical. Returns None if nothing matches."""
    if not body_parts or not query_name:
        return None
    q = str(query_name)

    lowered = [str(b).strip().lower() for b in body_parts]
    ql = q.strip().lower()
    if ql in lowered:
        return lowered.index(ql)

    q_point = identify_parts([q])
    canons = [f.name for f in fields(q_point) if getattr(q_point, f.name) is not None]
    if not canons:
        return None

    bp_point = identify_parts(body_parts)
    for canon in canons:
        idx = getattr(bp_point, canon)
        if idx is not None:
            return idx
    return None
