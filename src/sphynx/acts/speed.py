"""Rest/walk/locomotion classification from velocity. Port of
sphynx.acts.speedActs."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from sphynx.acts.refine import refine_act
from sphynx.exceptions import SphynxError


@dataclass
class SpeedActs:
    rest: np.ndarray
    walk: np.ndarray
    locomotion: np.ndarray


def speed_acts(velocity, rest_threshold_cm_s, loc_threshold_cm_s, min_run_frames) -> SpeedActs:
    v = np.asarray(velocity, dtype=float).ravel()

    raw_rest = v < rest_threshold_cm_s
    raw_loc = v > loc_threshold_cm_s

    refined_rest, _ = refine_act(raw_rest, min_run_frames, min_run_frames)
    raw_loc_nonrest = raw_loc & ~refined_rest
    refined_loc, _ = refine_act(raw_loc_nonrest, min_run_frames, min_run_frames)
    raw_walk = ~(refined_rest | refined_loc)
    refined_walk, _ = refine_act(raw_walk, min_run_frames, min_run_frames)

    leftover = raw_walk & ~refined_walk
    mid = (rest_threshold_cm_s + loc_threshold_cm_s) / 2.0
    _, leftover_runs = refine_act(leftover, 0, 0)
    for r in leftover_runs:
        seg = v[r.frame_in : r.frame_out + 1]
        if np.mean(seg) > mid:
            refined_loc[r.frame_in : r.frame_out + 1] = True
        else:
            refined_rest[r.frame_in : r.frame_out + 1] = True

    total = refined_rest.astype(int) + refined_walk.astype(int) + refined_loc.astype(int)
    if not np.all(total == 1):
        raise SphynxError("rest+walk+locomotion does not partition the frames")

    return SpeedActs(refined_rest, refined_walk, refined_loc)
