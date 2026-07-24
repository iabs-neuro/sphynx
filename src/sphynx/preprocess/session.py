"""Detect the session-start frame from a DLC trace. Port of
sphynx.preprocess.detectSessionStartFrame. Frame numbers are 1-based."""

from __future__ import annotations

import numpy as np
import pandas as pd
from pandas.api.indexers import FixedForwardWindowIndexer


def detect_session_start_frame(
    dlc, window_frames: int = 30, population_ratio: float = 0.5,
    window_fill_ratio: float = 0.5,
):
    x = np.asarray(dlc.X, dtype=float)
    y = np.asarray(dlc.Y, dtype=float)
    n_parts, n_frames = x.shape

    info = {
        "first_populated_frame": None,
        "total_populated_ratio": 0.0,
        "window_frames": window_frames,
        "threshold": window_fill_ratio,
        "message": "",
    }
    if n_frames == 0:
        info["message"] = "No frames in DLC trace"
        return 1, info

    populated = (~np.isnan(x)) & (~np.isnan(y)) & (x >= 0) & (y >= 0)
    per_frame = populated.sum(axis=0) / n_parts
    frame_is_in = per_frame >= population_ratio

    if not frame_is_in.any():
        info["message"] = "Animal never reaches PopulationRatio in any frame"
        return 1, info
    first_hit = int(np.argmax(frame_is_in))  # 0-based
    info["first_populated_frame"] = first_hit + 1
    info["total_populated_ratio"] = float(frame_is_in.sum() / n_frames)

    w = int(round(window_frames))
    indexer = FixedForwardWindowIndexer(window_size=w)
    rolling = (
        pd.Series(frame_is_in.astype(float))
        .rolling(indexer, min_periods=1)
        .mean()
        .to_numpy()
    )

    hits = np.flatnonzero(rolling >= window_fill_ratio)
    if hits.size == 0:
        info["message"] = (
            f"No {w}-frame window reaches fill ratio {window_fill_ratio:.2f} "
            f"(peak rolling = {rolling.max():.2f})"
        )
        return 1, info
    candidate = int(hits[0])  # 0-based
    tail = np.flatnonzero(frame_is_in[candidate:])
    start0 = candidate if tail.size == 0 else candidate + int(tail[0])
    return start0 + 1, info  # 1-based
