"""Object zones and the rings around them (S4d).

Port of matlab/+sphynx/+preset/buildObjectZones.m. Each object yields three
zones, and they are three DIFFERENT classes so an act family binds exactly one
and nothing is counted twice:

    <name>_real     the object footprint          class <kind>
    <name>_out      the ring around it            class <kind>_ring
    <name>_realout  footprint + ring together     class <kind>_area

The ring is inflated in normalized (isotropic-cm) space when the pixel is
anisotropic, so a 2.5 cm band is physically 2.5 cm on both axes.
"""

from __future__ import annotations

import numpy as np
from scipy.ndimage import distance_transform_edt, zoom

from sphynx.exceptions import SphynxValueError
from sphynx.zones.strips import Zone, ZoneRoles


def _to_norm(mask, x_kcorr):
    """Stretch the columns so distances are isotropic. Rows are unchanged."""
    if x_kcorr == 1:
        return np.asarray(mask, dtype=bool)
    return zoom(np.asarray(mask, dtype=np.uint8), (1.0, x_kcorr),
                order=0) > 0


def _from_norm(mask, shape):
    if mask.shape == tuple(shape):
        return np.asarray(mask, dtype=bool)
    factors = (shape[0] / mask.shape[0], shape[1] / mask.shape[1])
    out = zoom(np.asarray(mask, dtype=np.uint8), factors, order=0) > 0
    # zoom can land one pixel short or long; trim or pad to the exact frame.
    fixed = np.zeros(tuple(shape), dtype=bool)
    rows = min(shape[0], out.shape[0])
    cols = min(shape[1], out.shape[1])
    fixed[:rows, :cols] = out[:rows, :cols]
    return fixed


def inflate_mask(mask, width_pixels, x_kcorr: float = 1.0):
    """(inflated, ring) for `mask` grown by `width_pixels`."""
    mask = np.asarray(mask, dtype=bool)
    if width_pixels <= 0:
        return mask.copy(), np.zeros_like(mask)

    if x_kcorr == 1:
        # bwdist(mask) in MATLAB is the distance to the nearest True pixel,
        # which is the EDT of the complement here.
        distance = distance_transform_edt(~mask)
        inflated = distance <= width_pixels
        return inflated, inflated & ~mask

    shape = mask.shape
    normalized = _to_norm(mask, x_kcorr)
    distance = distance_transform_edt(~normalized)
    inflated_norm = distance <= width_pixels
    inflated = _from_norm(inflated_norm, shape)
    ring = inflated & ~mask
    return inflated, ring


def build_object_zones(objects, height, width, pixels_per_cm=None,
                       zone_width_cm: float = 2.5, x_kcorr: float = 1.0,
                       kind: str = "object", targets=None) -> list:
    """Three zones per object, plus the combined set when there are several."""
    objects = list(objects or [])
    if not objects:
        return []
    if zone_width_cm > 0 and not pixels_per_cm:
        raise SphynxValueError(
            "a ring width in centimetres needs the pixels-per-cm calibration; "
            "calibrate first or set the width to 0")

    targets = set(targets or ())
    width_pixels = float(zone_width_cm) * float(pixels_per_cm or 1.0)
    zones: list = []

    def _add(name, mask, zone_class, index, is_target):
        zones.append(Zone(name, "area", np.asarray(mask, dtype=bool),
                          zone_class=zone_class,
                          roles=ZoneRoles(is_target=is_target), index=index))

    all_real = np.zeros((height, width), dtype=bool)
    all_realout = np.zeros((height, width), dtype=bool)

    for position, (name, mask) in enumerate(objects, start=1):
        mask = np.asarray(mask, dtype=bool)
        is_target = name in targets
        _add(f"{name}_real", mask, kind, position, is_target)
        all_real |= mask
        if width_pixels > 0:
            inflated, ring = inflate_mask(mask, width_pixels, x_kcorr)
            _add(f"{name}_realout", inflated, f"{kind}_area", position, is_target)
            _add(f"{name}_out", ring, f"{kind}_ring", position, is_target)
            all_realout |= inflated

    if len(objects) >= 2:
        _add("objectall_real", all_real, "legacy_aggregate", None, False)
        if width_pixels > 0:
            _add("objectall_realout", all_realout, "legacy_aggregate", None, False)
            _add("objectall_out", all_realout & ~all_real, "legacy_aggregate",
                 None, False)
    return zones
