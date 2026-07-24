"""Load a sphynx preset .mat file. Port of sphynx.io.readPreset."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import scipy.io

from sphynx.exceptions import SphynxIOError


@dataclass
class PresetData:
    options: object
    zones: object
    arena_and_objects: object


def read_preset(mat_path) -> PresetData:
    """Load the legacy preset .mat (fields Options, Zones, ArenaAndObjects).
    Struct fields are attribute-accessible (e.g. options.FrameRate).
    """
    path = Path(mat_path)
    if not path.is_file():
        raise SphynxIOError(f"Preset .mat not found: {path}")
    mat = scipy.io.loadmat(path, squeeze_me=True, struct_as_record=False)
    return PresetData(
        options=mat.get("Options"),
        zones=mat.get("Zones"),
        arena_and_objects=mat.get("ArenaAndObjects"),
    )
