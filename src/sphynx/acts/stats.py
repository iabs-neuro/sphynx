"""Per-act numeric statistics. Port of sphynx.acts.actStats. Field names are
snake_case (spec section 5)."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from sphynx.acts.refine import refine_act
from sphynx.exceptions import SphynxValueError

_NAN = float("nan")


@dataclass
class ActStats:
    count: int
    percent: float
    duration_s: float
    mean_time: float
    median_time: float
    std_time: float
    mad_time: float
    first_start_s: float
    first_end_s: float
    last_start_s: float
    last_end_s: float
    first_duration_s: float
    rest_duration_s: float
    distance_cm: float
    mean_distance_cm: float
    mean_velocity: float
    max_velocity: float
    min_velocity: float
    velocity: float


def act_stats(act_mask, frame_rate, velocity=None) -> ActStats:
    if not frame_rate > 0:
        raise SphynxValueError(f"frame_rate must be positive; got {frame_rate}")
    mask = np.asarray(act_mask).astype(bool).ravel()
    n = mask.size
    _, runs = refine_act(mask, 0, 0)
    durations = np.array([r.duration for r in runs], dtype=float)

    count = len(runs)
    percent = round(100.0 * mask.sum() / max(n, 1), 2)
    duration_s = round(mask.sum() / frame_rate, 2)

    if durations.size == 0:
        mean_time = median_time = std_time = mad_time = 0.0
    else:
        dur_sec = durations / frame_rate
        mean_time = round(float(np.mean(dur_sec)), 2)
        median_time = round(float(np.median(dur_sec)), 2)
        std_time = round(float(np.std(dur_sec, ddof=1)) if dur_sec.size > 1 else 0.0, 2)
        mad_time = round(float(np.mean(np.abs(dur_sec - np.mean(dur_sec)))), 2)

    if not runs:
        first_start_s = first_end_s = last_start_s = last_end_s = _NAN
        first_duration_s = rest_duration_s = _NAN
    else:
        first_start_s = round(runs[0].frame_in / frame_rate, 2)
        first_end_s = round(runs[0].frame_out / frame_rate, 2)
        last_start_s = round(runs[-1].frame_in / frame_rate, 2)
        last_end_s = round(runs[-1].frame_out / frame_rate, 2)
        first_dur = runs[0].duration / frame_rate
        first_duration_s = round(first_dur, 2)
        rest_duration_s = round(max(0.0, duration_s - first_dur), 2)

    if velocity is None or not mask.any():
        return ActStats(
            count, percent, duration_s, mean_time, median_time, std_time, mad_time,
            first_start_s, first_end_s, last_start_s, last_end_s,
            first_duration_s, rest_duration_s, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        )

    v = np.asarray(velocity, dtype=float).ravel()
    v_in = v[mask]
    mean_velocity = round(float(np.nanmean(v_in)), 2)
    max_velocity = round(float(np.nanmax(v_in)), 2)
    min_velocity = round(float(np.nanmin(v_in)), 2)
    distance_cm = round(float(np.nansum(v_in)) / frame_rate, 2)
    mean_distance_cm = round(distance_cm / count, 2) if count > 0 else 0.0
    return ActStats(
        count, percent, duration_s, mean_time, median_time, std_time, mad_time,
        first_start_s, first_end_s, last_start_s, last_end_s,
        first_duration_s, rest_duration_s, distance_cm, mean_distance_cm,
        mean_velocity, max_velocity, min_velocity, mean_velocity,
    )
