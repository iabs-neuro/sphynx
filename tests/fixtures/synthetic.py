"""Synthetic DLC fixtures with known ground truth (test-only)."""

from __future__ import annotations

import numpy as np


def make_rotating_mouse_dlc(
    total_rotation_deg, duration_s, frame_rate: float = 30.0, nose_radius_cm: float = 1.5
) -> dict:
    """A mouse rotating uniformly in place. Port of
    sphynx.testing.makeRotatingMouseDLC."""
    n = int(round(duration_s * frame_rate))
    t = np.arange(n) / frame_rate
    ang = np.deg2rad(total_rotation_deg) * t / duration_s
    return {
        "head_center_x": np.zeros(n),
        "head_center_y": np.zeros(n),
        "head_tip_x": nose_radius_cm * np.cos(ang),
        "head_tip_y": nose_radius_cm * np.sin(ang),
        "frame_rate": frame_rate,
        "n_frames": n,
        "expected_total_rotation_rad": np.deg2rad(total_rotation_deg),
    }
