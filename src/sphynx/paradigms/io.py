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


_TOP_LEVEL_KEYS = {
    "schema_version", "name", "parent", "doc", "composites", "families",
    "acts", "metrics", "config_defaults", "validation",
}

# JSON has no literal for these, and Python's json writes bare Infinity/NaN,
# which other readers (JS, MATLAB, jq) reject. Encode them explicitly.
_INF, _NEG_INF, _NAN_TAG = "__inf__", "__-inf__", "__nan__"


def _encode_specials(value):
    if isinstance(value, float):
        if value == float("inf"):
            return _INF
        if value == float("-inf"):
            return _NEG_INF
        if value != value:                      # NaN
            return _NAN_TAG
        return value
    if isinstance(value, dict):
        return {k: _encode_specials(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [_encode_specials(v) for v in value]
    return value


def _decode_specials(value):
    if isinstance(value, str):
        if value == _INF:
            return float("inf")
        if value == _NEG_INF:
            return float("-inf")
        if value == _NAN_TAG:
            return float("nan")
        return value
    if isinstance(value, dict):
        return {k: _decode_specials(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_decode_specials(v) for v in value]
    return value


def _check_keys(data, known, what):
    if not isinstance(data, dict):
        raise SphynxValueError(f"{what} must be an object; got {type(data).__name__}")
    unknown = set(data) - set(known)
    if unknown:
        raise SphynxValueError(
            f"{what} has unknown field(s) {sorted(unknown)}; known: {sorted(known)}")


def _from_fields(cls, data, what):
    """Build a dataclass from a dict, rejecting unknown keys loudly."""
    _check_keys(data, {f.name for f in fields(cls)}, what)
    return cls(**data)


def _act_to_dict(act, what):
    """Acts serialise as plain fields. An expression tree cannot: asdict would
    flatten it into anonymous dicts that rebuild as unknown nodes, and the act
    would silently evaluate to all-false after a round trip."""
    if getattr(act, "expr", None) is not None:
        raise SphynxValueError(
            f'{what} "{act.name}" carries an expression tree, which cannot be '
            "saved yet; declare it with the flat components/operation fields")
    return asdict(act)


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
                "template": _act_to_dict(f.template, "family template"),
            }
            for f in paradigm.families
        ],
        "acts": [_act_to_dict(a, "act") for a in paradigm.acts],
        "metrics": [{"name": m.name, "params": dict(m.params), "as_": m.as_}
                    for m in paradigm.metrics],
        "config_defaults": dict(paradigm.config_defaults),
        "validation": [asdict(r) for r in paradigm.validation],
    }


def paradigm_from_dict(data: dict) -> Paradigm:
    """Rebuild a paradigm from `paradigm_to_dict` output."""
    _check_keys(data, _TOP_LEVEL_KEYS, "paradigm data")
    if "schema_version" not in data:
        raise SphynxValueError("paradigm data has no schema_version")
    version = data["schema_version"]
    if version != SCHEMA_VERSION:
        raise SphynxValueError(
            f"unsupported paradigm schema version {version}; "
            f"this build reads version {SCHEMA_VERSION}")
    if not data.get("name"):
        raise SphynxValueError("paradigm data has no name")

    composites = []
    for c in data.get("composites", []):
        _check_keys(c, {"name", "selector"}, "composite")
        composites.append(CompositeSpec(
            name=c.get("name", ""),
            selector=_from_fields(ZoneSelector, c.get("selector", {}),
                                  "composite selector")))

    families = []
    for f in data.get("families", []):
        _check_keys(f, {"name", "selector", "template", "name_pattern"}, "family")
        families.append(ActFamily(
            name=f.get("name", ""),
            selector=_from_fields(ZoneSelector, f.get("selector", {}),
                                  "family selector"),
            template=_from_fields(Act, f.get("template", {}), "act template"),
            name_pattern=f.get("name_pattern", "{family}{index}"),
        ))

    metrics = []
    for m in data.get("metrics", []):
        _check_keys(m, {"name", "params", "as_"}, "metric reference")
        metrics.append(MetricRef(name=m.get("name", ""),
                                 params=dict(m.get("params", {})),
                                 as_=m.get("as_", "")))
    return Paradigm(
        name=data["name"],
        parent=data.get("parent"),
        doc=data.get("doc", ""),
        composites=composites,
        families=families,
        acts=[_from_fields(Act, a, "act") for a in data.get("acts", [])],
        metrics=metrics,
        config_defaults=dict(data.get("config_defaults", {})),
        validation=[_from_fields(ValidationRule, r, "validation rule")
                    for r in data.get("validation", [])],
    )


def save_paradigm(paradigm: Paradigm, path) -> str:
    """Write a paradigm to a JSON file. Returns the path written.

    Written through a temporary file and moved into place, so a serialisation
    failure cannot leave a truncated file where a good paradigm used to be."""
    target = Path(path)
    payload = _encode_specials(paradigm_to_dict(paradigm))
    tmp = target.with_name(target.name + ".tmp")
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as fh:
            # allow_nan=False: non-finite floats are encoded by _encode_specials,
            # so anything left is a value json cannot represent portably.
            json.dump(payload, fh, indent=2, sort_keys=False, allow_nan=False)
        tmp.replace(target)
    except (OSError, TypeError, ValueError) as e:
        tmp.unlink(missing_ok=True)
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
    return paradigm_from_dict(_decode_specials(data))
