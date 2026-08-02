"""Write a preset .mat (S4d).

The on-disk shape is described HERE and nowhere else: the legacy upgrade and the
preset builder both write through this module, so the two cannot drift into
producing files the engine reads differently.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import scipy.io

from sphynx.exceptions import SphynxIOError


class Roles:
    """Roles that survive a .mat round trip."""

    def __init__(self, is_target: bool = False, tags=None):
        self.is_target = bool(is_target)
        self.tags = list(tags or [])


def roles_to_mat(roles) -> dict:
    return {"is_target": bool(getattr(roles, "is_target", False)),
            "tags": np.array(list(getattr(roles, "tags", []) or []),
                             dtype=object)}


def _angle_of(zone) -> float:
    angle = getattr(zone, "angle", None)
    return float("nan") if angle is None else float(angle)


def zone_to_mat(zone) -> dict:
    index = getattr(zone, "index", None)
    return {
        "name": str(getattr(zone, "name", "")),
        "type": str(getattr(zone, "type", "area")),
        "maskfilled": np.asarray(zone.maskfilled),
        "zone_class": str(getattr(zone, "zone_class", "unknown")),
        "index": np.nan if index is None else float(index),
        # `or` would turn a legitimate angle of 0.0 into NaN.
        "angle": float(_angle_of(zone)),
        "roles": roles_to_mat(getattr(zone, "roles", Roles())),
    }


def options_struct(frame_rate, pixels_per_cm, width, height,
                   x_kcorr: float = 1.0, experiment_type: str = "",
                   pxl_y=None, pxl_x=None, **extra) -> dict:
    """The Options fields the engine reads, under their legacy names.

    The per-axis scales are kept beside the combined one, as the MATLAB app
    does (assembleOptions): `pxl2sm` alone cannot say whether it is an average
    of two agreeing axes or the y-axis of two that disagreed, and that is
    exactly what a reader needs to judge `x_kcorr`. Absent measurements fall
    back to the combined scale, matching setPixelsPerCm's ifNaN."""
    pixels_per_cm = float(pixels_per_cm)
    options = {
        "FrameRate": float(frame_rate),
        "pxl2sm": pixels_per_cm,
        "pxl2smY": pixels_per_cm if pxl_y is None else float(pxl_y),
        "pxl2smX": pixels_per_cm if pxl_x is None else float(pxl_x),
        "Width": int(width),
        "Height": int(height),
        "x_kcorr": float(x_kcorr),
        "ExperimentType": str(experiment_type),
    }
    options.update(extra)
    return options


def save_preset(zones, options, path, arena_and_objects=None) -> str:
    """Write zones and options as the .mat shape read_preset expects."""
    zones = list(zones or [])
    if not zones:
        raise SphynxIOError("a preset needs at least one zone")

    target = Path(path)
    payload = {
        "Options": dict(options or {}),
        "ArenaAndObjects": (np.array([]) if arena_and_objects is None
                            else arena_and_objects),
        "Zones": np.array([zone_to_mat(z) for z in zones], dtype=object),
    }
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        scipy.io.savemat(target, payload, do_compression=True)
    except Exception as e:      # noqa: BLE001 - scipy raises broadly
        raise SphynxIOError(f"cannot write preset {target}: {e}") from e
    return str(target)
