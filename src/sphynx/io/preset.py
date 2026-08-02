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


def _optional_number(value, field, name):
    """A numeric zone field that may be absent. NaN in the file means None.

    NaN is how save_preset writes "not set" (a .mat struct field cannot hold
    Python's None), so it is the only value that maps back to None. Anything
    non-numeric is a malformed file and is reported, not guessed at.
    """
    if value is None or (hasattr(value, "size") and np.size(value) == 0):
        return None
    try:
        number = float(value)
    except (TypeError, ValueError) as e:
        raise SphynxIOError(
            f'zone "{name}": field "{field}" is not a number ({value!r})') from e
    return None if np.isnan(number) else number


def _parse_zones(mat_zones):
    """Convert mat_struct zones from preset to Zone objects.

    MATLAB zones have: name, type, maskfilled.
    Python Zone objects also need: zone_class, roles, index, angle, members.
    """
    if mat_zones is None:
        return None

    from sphynx.zones import Zone, ZoneRoles

    # squeeze_me collapses a one-zone array to a bare mat_struct, which is not
    # iterable; atleast_1d puts it back in a list of one.
    zones = []
    for mat_z in np.atleast_1d(mat_zones):
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

        # Read back what save_preset wrote rather than discarding it: a Barnes
        # hole's ring index and angle are geometry, not decoration.
        name = getattr(mat_z, "name", "unknown")
        index = _optional_number(getattr(mat_z, "index", None), "index", name)
        angle = _optional_number(getattr(mat_z, "angle", None), "angle", name)

        # Create Zone object with defaults for missing attributes
        z = Zone(
            name=name,
            type=getattr(mat_z, "type", "area"),
            maskfilled=mask,
            zone_class=getattr(mat_z, "zone_class", "unknown"),
            roles=roles,
            index=None if index is None else int(round(index)),
            angle=angle,
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
