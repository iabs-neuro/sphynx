"""Standalone built-in acts called directly by the pipeline (freezing, rear).
Ports of sphynx.acts.freezing and sphynx.acts.rear."""

from __future__ import annotations

import numpy as np

from sphynx.acts.refine import refine_act
from sphynx.acts.rear_threshold import auto_rear_threshold_cm
from sphynx.bodyparts import Point
from sphynx.exceptions import SphynxValueError
from sphynx.geom import hypot_kcorr
from sphynx.util.smoothing import smooth_derived


def freezing(body_parts_velocity, point: Point, mode: str, rest_threshold_cm_s, min_run_frames) -> np.ndarray:
    """Per-frame freezing. mode AllBodyParts|NoseAndCenter|HeadAndCenter; the
    latter two degrade to AllBodyParts when their parts are unresolved."""
    if mode not in ("AllBodyParts", "NoseAndCenter", "HeadAndCenter"):
        raise SphynxValueError(
            f"mode must be AllBodyParts|NoseAndCenter|HeadAndCenter; got {mode}")
    bpv = np.asarray(body_parts_velocity, dtype=float)
    parts, n = bpv.shape

    eff = mode
    if mode == "NoseAndCenter" and (point.nose is None or point.center is None):
        eff = "AllBodyParts"
    elif mode == "HeadAndCenter" and (point.head_center is None or point.center is None):
        eff = "AllBodyParts"

    if eff == "AllBodyParts":
        total_v = bpv.sum(axis=0)
        raw = total_v < rest_threshold_cm_s * parts
    elif eff == "NoseAndCenter":
        raw = (bpv[point.nose, :] < rest_threshold_cm_s * 2) & (
            bpv[point.center, :] < rest_threshold_cm_s)
    else:  # HeadAndCenter
        raw = (bpv[point.head_center, :] < rest_threshold_cm_s) & (
            bpv[point.center, :] < rest_threshold_cm_s)

    refined, _ = refine_act(raw, min_run_frames, min_run_frames)
    return refined
