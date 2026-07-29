"""Save/load a paradigm as JSON (S2 layer 6).

This is what makes a user-defined ("New") paradigm a first-class citizen: it is
the same declarative data as a built-in, so it round-trips through a file with
no code. Act templates carried by families are plain field dictionaries --
expression trees are not serialised because a family template may not be a
complex act (see acts.families), so no tree can appear here.
"""

from __future__ import annotations

import json
from dataclasses import asdict, fields
from pathlib import Path

from sphynx.acts import Act, ActFamily
from sphynx.exceptions import SphynxIOError, SphynxValueError
from sphynx.paradigms.model import CompositeSpec, MetricRef, Paradigm
from sphynx.paradigms.validate import ValidationRule
from sphynx.zones import ZoneSelector

SCHEMA_VERSION = 1


def _from_fields(cls, data, what):
    """Build a dataclass from a dict, rejecting unknown keys loudly."""
    if not isinstance(data, dict):
        raise SphynxValueError(f"{what} must be an object; got {type(data).__name__}")
    known = {f.name for f in fields(cls)}
    unknown = set(data) - known
    if unknown:
        raise SphynxValueError(
            f"{what} has unknown field(s) {sorted(unknown)}; known: {sorted(known)}")
    return cls(**data)


def paradigm_to_dict(paradigm: Paradigm) -> dict:
    """Serialise a paradigm to plain JSON-compatible data."""
    return {
        "schema_version": SCHEMA_VERSION,
        "name": paradigm.name,
        "parent": paradigm.parent,
        "doc": paradigm.doc,
        "composites": [
            {"name": c.name, "selector": asdict(c.selector)}
            for c in paradigm.composites
        ],
        "families": [
            {
                "name": f.name,
                "selector": asdict(f.selector),
                "name_pattern": f.name_pattern,
                "template": asdict(f.template),
            }
            for f in paradigm.families
        ],
        "acts": [asdict(a) for a in paradigm.acts],
        "metrics": [{"name": m.name, "params": dict(m.params)}
                    for m in paradigm.metrics],
        "config_defaults": dict(paradigm.config_defaults),
        "validation": [asdict(r) for r in paradigm.validation],
    }


def paradigm_from_dict(data: dict) -> Paradigm:
    """Rebuild a paradigm from `paradigm_to_dict` output."""
    if not isinstance(data, dict):
        raise SphynxValueError(
            f"paradigm data must be an object; got {type(data).__name__}")
    version = data.get("schema_version", SCHEMA_VERSION)
    if version != SCHEMA_VERSION:
        raise SphynxValueError(
            f"unsupported paradigm schema version {version}; "
            f"this build reads version {SCHEMA_VERSION}")
    if not data.get("name"):
        raise SphynxValueError("paradigm data has no name")

    composites = [
        CompositeSpec(
            name=c.get("name", ""),
            selector=_from_fields(ZoneSelector, c.get("selector", {}),
                                  "composite selector"))
        for c in data.get("composites", [])
    ]
    families = [
        ActFamily(
            name=f.get("name", ""),
            selector=_from_fields(ZoneSelector, f.get("selector", {}),
                                  "family selector"),
            template=_from_fields(Act, f.get("template", {}), "act template"),
            name_pattern=f.get("name_pattern", "{family}{index}"),
        )
        for f in data.get("families", [])
    ]
    return Paradigm(
        name=data["name"],
        parent=data.get("parent"),
        doc=data.get("doc", ""),
        composites=composites,
        families=families,
        acts=[_from_fields(Act, a, "act") for a in data.get("acts", [])],
        metrics=[MetricRef(name=m.get("name", ""), params=dict(m.get("params", {})))
                 for m in data.get("metrics", [])],
        config_defaults=dict(data.get("config_defaults", {})),
        validation=[_from_fields(ValidationRule, r, "validation rule")
                    for r in data.get("validation", [])],
    )


def save_paradigm(paradigm: Paradigm, path) -> str:
    """Write a paradigm to a JSON file. Returns the path written."""
    target = Path(path)
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        with open(target, "w", encoding="utf-8") as fh:
            json.dump(paradigm_to_dict(paradigm), fh, indent=2, sort_keys=False)
    except OSError as e:
        raise SphynxIOError(f"cannot write paradigm to {target}: {e}") from e
    return str(target)


def load_paradigm(path) -> Paradigm:
    """Read a paradigm from a JSON file."""
    source = Path(path)
    if not source.is_file():
        raise SphynxIOError(f"paradigm file not found: {source}")
    try:
        with open(source, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except json.JSONDecodeError as e:
        raise SphynxIOError(f"malformed paradigm JSON in {source}: {e}") from e
    except OSError as e:
        raise SphynxIOError(f"cannot read paradigm from {source}: {e}") from e
    return paradigm_from_dict(data)
