"""Act library as JSON (S4b).

The same rules as the paradigm codec: schema version required, unknown fields
rejected, non-finite floats encoded explicitly. Expression trees cannot be
saved -- `asdict` would flatten a tree into anonymous dicts that reload as
unknown nodes and evaluate to all-false.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field

from sphynx.acts.families import ActFamily
from sphynx.acts.schema import Act
from sphynx.exceptions import SphynxValueError
from sphynx.io.jsonio import check_keys, from_fields, read_json, write_json
from sphynx.zones.select import ZoneSelector

SCHEMA_VERSION = 1

_TOP_LEVEL = {"schema_version", "acts", "families"}
_FAMILY_KEYS = {"name", "selector", "template", "name_pattern"}


@dataclass
class ActLibrary:
    acts: list = field(default_factory=list)        # Act
    families: list = field(default_factory=list)    # ActFamily


def _act_to_dict(act, what):
    if getattr(act, "expr", None) is not None:
        raise SphynxValueError(
            f'{what} "{act.name}" carries an expression tree, which cannot be '
            "saved yet; declare it with the flat components/operation fields")
    return asdict(act)


def library_to_dict(library: ActLibrary) -> dict:
    return {
        "schema_version": SCHEMA_VERSION,
        "acts": [_act_to_dict(a, "act") for a in library.acts],
        "families": [
            {"name": f.name, "selector": asdict(f.selector),
             "template": _act_to_dict(f.template, "family template"),
             "name_pattern": f.name_pattern}
            for f in library.families
        ],
    }


def library_from_dict(data: dict) -> ActLibrary:
    check_keys(data, _TOP_LEVEL, "act library")
    if "schema_version" not in data:
        raise SphynxValueError("act library has no schema_version")
    if data["schema_version"] != SCHEMA_VERSION:
        raise SphynxValueError(
            f"unsupported act library schema version {data['schema_version']}; "
            f"this build reads version {SCHEMA_VERSION}")

    families = []
    for entry in data.get("families", []):
        check_keys(entry, _FAMILY_KEYS, "act family")
        families.append(ActFamily(
            name=entry.get("name", ""),
            selector=from_fields(ZoneSelector, entry.get("selector", {}),
                                 "family selector"),
            template=from_fields(Act, entry.get("template", {}), "act template"),
            name_pattern=entry.get("name_pattern", "{family}{index}"),
        ))
    return ActLibrary(
        acts=[from_fields(Act, a, "act") for a in data.get("acts", [])],
        families=families,
    )


def save_library(library: ActLibrary, path) -> str:
    return write_json(library_to_dict(library), path)


def load_library(path) -> ActLibrary:
    return library_from_dict(read_json(path))
