"""Min-length / gap-bridge refinement for binary act traces. Ports of
sphynx.acts.refineAct and refineActArray. Run indices are 0-based inclusive."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np


@dataclass
class Run:
    frame_in: int   # 0-based inclusive
    frame_out: int  # 0-based inclusive
    duration: int


def _find_runs(line: np.ndarray, value: bool):
    """Return (starts, ends) 0-based inclusive line indices of runs == value."""
    marker = line == value
    aug = np.concatenate([[False], marker, [False]])
    trans = np.diff(aug.astype(np.int8))
    starts = np.flatnonzero(trans == 1)      # 0-based line start index
    ends = np.flatnonzero(trans == -1) - 1   # 0-based line end index
    return starts, ends


def refine_act(line, min_run_len1, min_run_len0):
    """Drop short 1-runs, close short 0-runs flanked by 1s, enumerate survivors.
    Returns (refined bool array, list[Run]). Port of refineAct.m."""
    line = np.asarray(line).astype(bool).ravel()
    n = line.size
    if n == 0:
        return line.copy(), []

    refined = line.copy()
    s1, e1 = _find_runs(refined, True)
    for a, b in zip(s1, e1):
        if (b - a + 1) < min_run_len1:
            refined[a : b + 1] = False

    s0, e0 = _find_runs(refined, False)
    for a, b in zip(s0, e0):
        if (b - a + 1) < min_run_len0 and a > 0 and b < n - 1:
            if refined[a - 1] and refined[b + 1]:
                refined[a : b + 1] = True

    s1, e1 = _find_runs(refined, True)
    runs = [Run(int(a), int(b), int(b - a + 1)) for a, b in zip(s1, e1)]
    return refined, runs


def _rle(b: np.ndarray):
    if b.size == 0:
        return [], []
    d = np.concatenate([[True], np.diff(b) != 0])
    starts = np.flatnonzero(d)
    ends = np.concatenate([starts[1:] - 1, [b.size - 1]])
    runs = list(zip(starts.tolist(), ends.tolist()))
    lengths = (ends - starts + 1).tolist()
    return runs, lengths


def refine_act_array(bool_arr, min_run_frames: int = 0, max_bridge_frames: int = 0) -> np.ndarray:
    """Bridge short holes (pass 1) then drop short runs (pass 2). Leading/trailing
    zero-runs are never bridged. Port of refineActArray.m."""
    b = np.asarray(bool_arr).astype(bool).ravel().copy()
    n = b.size
    if n == 0:
        return b

    if max_bridge_frames > 0:
        runs, lengths = _rle(b)
        for (s, e), ln in zip(runs, lengths):
            is_hole = not b[s]
            if is_hole and s != 0 and e != n - 1 and ln < max_bridge_frames:
                b[s : e + 1] = True

    if min_run_frames > 0:
        runs, lengths = _rle(b)
        for (s, e), ln in zip(runs, lengths):
            if b[s] and ln < min_run_frames:
                b[s : e + 1] = False

    return b
