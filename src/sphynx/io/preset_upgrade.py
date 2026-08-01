"""Upgrade a legacy preset so its zones carry roles (S2 layer 1).

Legacy presets name zones by convention and carry no roles, so every paradigm
beyond Open Field refuses to run on them. This module reads that convention and
writes the roles out explicitly, once, into a new file.

The convention, verified against real presets rather than assumed:

    <thing>Real     / <thing>_real      the thing itself (object footprint)
    <thing>Out      / <thing>_out       the ring AROUND it, disjoint from Real
    <thing>RealOut  / <thing>_realout   the union of the two
    <thing>_center                      its centre point

Only `*Real` and `*Out` are given a zone class. The unions and the `*All*`
aggregates are deliberately NOT classified: an act family expands over every
zone of a class, so classifying both `Object1Real` and `Object1RealOut` as
"object" would count each visit twice. Paradigms build their own composites.

What a legacy "object" MEANS depends on the experiment: in a Barnes maze the
numbered objects are the holes, everywhere else they are objects. That comes
from `Options.ExperimentType`, which the preset states -- it is not guessed.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import scipy.io

from sphynx.exceptions import SphynxIOError
from sphynx.logging_setup import get_logger

_log = get_logger()

# Suffix -> what the zone is. Order matters: "realout" must be tested before
# "real" and "out", or a union would be read as one of its parts.
_SUFFIXES = ("realout", "real", "out", "center")



@dataclass
class ZoneUpgrade:
    """What the upgrade decided about one zone."""

    name: str
    zone_class: str = "unknown"
    index: int | None = None
    is_target: bool = False
    reason: str = ""


@dataclass
class UpgradeReport:
    experiment_type: str = ""
    zones: list = field(default_factory=list)      # ZoneUpgrade
    skipped: list = field(default_factory=list)    # (name, why)

    @property
    def classified(self) -> list:
        return [z for z in self.zones if z.zone_class != "unknown"]

    def counts(self) -> dict:
        out: dict = {}
        for zone in self.classified:
            out[zone.zone_class] = out.get(zone.zone_class, 0) + 1
        return out


def _parse_legacy_name(name: str):
    """Split a legacy zone name into (base, number, suffix).

    Legacy naming is not consistent about where the number goes -- NOF writes
    `Object1Real` and `ArenaWallReal2` in the same file -- so both forms are
    handled."""
    text = str(name).lower().replace("_", "")
    head, trailing = re.match(r"^(.*?)(\d*)$", text).groups()

    suffix = ""
    for candidate in _SUFFIXES:
        if head.endswith(candidate) and head[: -len(candidate)]:
            head, suffix = head[: -len(candidate)], candidate
            break

    embedded = re.match(r"^(.*?)(\d+)$", head)
    if embedded:
        return embedded.group(1), int(embedded.group(2)), suffix
    return head, (int(trailing) if trailing else None), suffix


# Base -> (zone class, whether the target flag is implied).
_BASES = {
    "object": ("object", False),
    "target": ("object", True),
    "arena": ("arena", False),
    "arenawall": ("wall", False),
    "wall": ("wall", False),
    "arenacorner": ("corner", False),
    "corner": ("corner", False),
    "center": ("center", False),
    "centre": ("center", False),
    "wallsandcorners": ("legacy_aggregate", False),
    "border": ("legacy_aggregate", False),
}


def classify_legacy_zone(name: str, experiment_type: str = "") -> ZoneUpgrade:
    """Decide the class, index and target flag for one legacy zone name."""
    upgrade = ZoneUpgrade(name=name)
    base, number, suffix = _parse_legacy_name(name)

    if suffix in ("realout", "center"):
        upgrade.reason = f"legacy {suffix}: a derived zone, not a class member"
        upgrade.zone_class = f"legacy_{suffix}"
        return upgrade

    is_barnes = str(experiment_type).strip().lower() == "barnes"
    ring = suffix == "out"

    known = _BASES.get(base)
    if known is None:
        # "all" only marks an aggregate once no real base matched -- otherwise
        # every "wall" would look like one.
        if base.endswith("all"):
            upgrade.zone_class = "legacy_aggregate"
            upgrade.reason = ("legacy aggregate; paradigms build their own "
                              "composites")
        else:
            upgrade.reason = "no legacy convention matched; left unclassified"
        return upgrade

    kind, implies_target = known
    upgrade.is_target = implies_target
    if kind == "legacy_aggregate":
        upgrade.zone_class = kind
        upgrade.index = number
        upgrade.reason = "legacy aggregate; paradigms build their own composites"
        return upgrade

    if kind == "object" and is_barnes:
        # In a Barnes maze the numbered objects ARE the holes.
        kind = "hole"

    upgrade.zone_class = f"{kind}_ring" if ring else kind
    upgrade.index = number
    if implies_target:
        upgrade.reason = "named the target by the preset itself"
    else:
        upgrade.reason = f"legacy {base}{number if number is not None else ''} -> {upgrade.zone_class}"
    return upgrade


def upgrade_zone_structs(zones, experiment_type: str = "") -> UpgradeReport:
    """Annotate loaded preset zones in place and describe what was decided."""
    report = UpgradeReport(experiment_type=str(experiment_type))
    for zone in np.atleast_1d(zones):
        name = str(getattr(zone, "name", ""))
        mask = getattr(zone, "maskfilled", None)
        if getattr(mask, "ndim", 0) != 2:
            report.skipped.append((name, f"not a 2-D mask ({getattr(zone, 'type', '?')})"))
            continue

        upgrade = classify_legacy_zone(name, experiment_type)
        zone.zone_class = upgrade.zone_class
        zone.index = upgrade.index
        zone.angle = float("nan")          # assigned once the arena centre is known
        zone.roles = _Roles(is_target=upgrade.is_target)
        report.zones.append(upgrade)
    return report


class _Roles:
    """Minimal stand-in for ZoneRoles that survives a .mat round trip."""

    def __init__(self, is_target: bool = False, tags=None):
        self.is_target = bool(is_target)
        self.tags = list(tags or [])


def _roles_to_mat(roles) -> dict:
    return {"is_target": bool(getattr(roles, "is_target", False)),
            "tags": np.array(list(getattr(roles, "tags", []) or []), dtype=object)}


def _zone_to_mat(zone) -> dict:
    index = getattr(zone, "index", None)
    return {
        "name": str(getattr(zone, "name", "")),
        "type": str(getattr(zone, "type", "area")),
        "maskfilled": np.asarray(zone.maskfilled),
        "zone_class": str(getattr(zone, "zone_class", "unknown")),
        "index": np.nan if index is None else float(index),
        "angle": float(getattr(zone, "angle", float("nan"))),
        "roles": _roles_to_mat(getattr(zone, "roles", _Roles())),
    }


def upgrade_preset_file(source, destination) -> UpgradeReport:
    """Read a legacy preset, add zone roles, and write it to a new file."""
    source = Path(source)
    destination = Path(destination)
    if not source.is_file():
        raise SphynxIOError(f"preset not found: {source}")
    try:
        mat = scipy.io.loadmat(source, squeeze_me=True, struct_as_record=False)
    except Exception as e:                       # noqa: BLE001 - scipy is broad
        raise SphynxIOError(f"cannot read preset {source}: {e}") from e

    if "Zones" not in mat:
        raise SphynxIOError(f"preset {source} has no Zones")
    options = mat.get("Options")
    experiment_type = getattr(options, "ExperimentType", "") if options is not None else ""

    zones = list(np.atleast_1d(mat["Zones"]))
    report = upgrade_zone_structs(zones, experiment_type)

    keep = [z for z in zones if getattr(z, "ndim", None) is None
            and getattr(z.maskfilled, "ndim", 0) == 2]
    payload = {
        "Options": mat["Options"],
        "ArenaAndObjects": mat.get("ArenaAndObjects", np.array([])),
        "Zones": np.array([_zone_to_mat(z) for z in keep], dtype=object),
    }
    try:
        destination.parent.mkdir(parents=True, exist_ok=True)
        scipy.io.savemat(destination, payload, do_compression=True)
    except Exception as e:                       # noqa: BLE001 - scipy is broad
        raise SphynxIOError(f"cannot write preset {destination}: {e}") from e

    _log.info("Upgraded %s -> %s (%s)", source.name, destination.name,
              report.counts())
    return report
