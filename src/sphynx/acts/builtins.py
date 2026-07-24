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


def _make_odd(w: int) -> int:
    w = int(w)
    if w % 2 == 0:
        w += 1
    if w < 3:
        w = 3
    return w


def rear(
    bpx, bpy, point: Point, mode: str, pixels_per_cm,
    all_body_parts_threshold_pxl: float = 170, tailbase_paws_threshold_cm: float = 2.8,
    auto_threshold: bool = False, smooth_window_frames=None, min_run_frames: int = 5,
    frame_rate: float = 30, x_kcorr: float = 1.0,
) -> np.ndarray:
    """Per-frame rear. mode AllBodyParts|TailbasePaws; TailbasePaws degrades to
    AllBodyParts when tailbase/hindlimbs are unresolved. Port of rear.m."""
    if mode not in ("AllBodyParts", "TailbasePaws"):
        raise SphynxValueError(f"mode must be AllBodyParts|TailbasePaws; got {mode}")
    if pixels_per_cm is None or pixels_per_cm <= 0:
        raise SphynxValueError("pixels_per_cm is required")
    bpx = np.asarray(bpx, dtype=float)
    bpy = np.asarray(bpy, dtype=float)
    n = bpx.shape[1]

    eff = mode
    if mode == "TailbasePaws" and (
        point.tailbase is None or point.left_hind_limb is None or point.right_hind_limb is None
    ):
        eff = "AllBodyParts"

    if eff == "AllBodyParts":
        if point.center is None:
            return np.zeros(n, dtype=bool)
        cx = bpx[point.center, :]
        cy = bpy[point.center, :]
        sum_dist = np.zeros(n)
        for part in range(bpx.shape[0]):
            sum_dist += hypot_kcorr(cx - bpx[part, :], cy - bpy[part, :], x_kcorr)
        win = smooth_window_frames if smooth_window_frames else _make_odd(round(frame_rate))
        smoothed = np.asarray(smooth_derived(sum_dist, win))
        raw = smoothed < all_body_parts_threshold_pxl
    else:  # TailbasePaws
        tx = bpx[point.tailbase, :]
        ty = bpy[point.tailbase, :]
        sum_dist = np.zeros(n)
        for part in (point.left_hind_limb, point.right_hind_limb):
            sum_dist += hypot_kcorr(tx - bpx[part, :], ty - bpy[part, :], x_kcorr)
        win = smooth_window_frames if smooth_window_frames else _make_odd(int(np.ceil(frame_rate / 2)))
        smoothed = np.asarray(smooth_derived(sum_dist, win))
        if auto_threshold:
            thr_cm = auto_rear_threshold_cm(smoothed / pixels_per_cm)
            if not np.isfinite(thr_cm):
                thr_cm = tailbase_paws_threshold_cm
        else:
            thr_cm = tailbase_paws_threshold_cm
        raw = smoothed < thr_cm * pixels_per_cm

    refined, _ = refine_act(raw, min_run_frames, min_run_frames)
    return refined
