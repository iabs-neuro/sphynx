"""Load a sphynx preset .mat file. Port of sphynx.io.readPreset."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np
import scipy.io

from sphynx.exceptions import SphynxIOError


@dataclass
class PresetData:
    options: object
    zones: object
    arena_and_objects: object


def _parse_zones(mat_zones):
    """Convert mat_struct zones from preset to Zone objects.

    MATLAB zones have: name, type, maskfilled.
    Python Zone objects also need: zone_class, roles, index, angle, members.
    """
    if mat_zones is None:
        return None

    from sphynx.zones import Zone, ZoneRoles

    zones = []
    for mat_z in mat_zones:
        # Convert MATLAB mask to Python boolean array
        mask = np.asarray(getattr(mat_z, "maskfilled", np.zeros((1, 1))), dtype=bool)

        # Extract and reconstruct roles from mat file
        mat_roles = getattr(mat_z, "roles", None)
        if mat_roles is not None:
            tags = getattr(mat_roles, "tags", [])
            # Convert array to list; empty arrays need special handling
            tags = list(tags) if hasattr(tags, "__len__") else []
            roles = ZoneRoles(
                is_target=bool(getattr(mat_roles, "is_target", False)),
                tags=tags
            )
        else:
            roles = ZoneRoles()

        # Create Zone object with defaults for missing attributes
        z = Zone(
            name=getattr(mat_z, "name", "unknown"),
            type=getattr(mat_z, "type", "area"),
            maskfilled=mask,
            zone_class=getattr(mat_z, "zone_class", "unknown"),
            roles=roles,
            index=None,
            angle=None,
            members=[],
        )
        zones.append(z)

    return zones if zones else None


def read_preset(mat_path) -> PresetData:
    """Load the legacy preset .mat (fields Options, Zones, ArenaAndObjects).
    Struct fields are attribute-accessible (e.g. options.FrameRate).
    Zones are converted from mat_struct to Zone objects.
    """
    path = Path(mat_path)
    if not path.is_file():
        raise SphynxIOError(f"Preset .mat not found: {path}")
    try:
        mat = scipy.io.loadmat(path, squeeze_me=True, struct_as_record=False)
    except Exception as e:
        raise SphynxIOError(f"Failed to load preset {path}: {e}") from e
    return PresetData(
        options=mat.get("Options"),
        zones=_parse_zones(mat.get("Zones")),
        arena_and_objects=mat.get("ArenaAndObjects"),
    )
