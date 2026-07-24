"""Read DeepLabCut tracking CSVs (single- or multi-animal). Port of
sphynx.io.readDLC.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd

from sphynx.exceptions import SphynxIOError


@dataclass
class DlcData:
    body_parts: list[str]
    X: np.ndarray
    Y: np.ndarray
    likelihood: np.ndarray
    n_frames: int
    individuals: list[str] | None = None
    selected_individual: str | None = None


def read_dlc(
    csv_path, start_frame: int = 1, end_frame: int = 0, individual: str = ""
) -> DlcData:
    """Parse a DLC CSV. start_frame is 1-based inclusive; end_frame 0 = read all.
    For multi-animal ('individuals' header row) auto-picks the most-populated
    true animal (>1 bodypart), excluding 'single' trackers, unless `individual`
    forces one. Negative x/y sentinels (-1.0) become NaN.
    """
    if start_frame < 1:
        raise SphynxIOError(f"start_frame must be >= 1, got {start_frame}")
    if end_frame < 0:
        raise SphynxIOError(f"end_frame must be >= 0, got {end_frame}")

    path = Path(csv_path)
    if not path.is_file():
        raise SphynxIOError(f"DLC csv not found: {path}")

    header_lines: list[str] = []
    try:
        with open(path, "r", encoding="utf-8", newline="") as fh:
            for k in range(4):
                line = fh.readline()
                if line == "":
                    raise SphynxIOError(f"CSV ended before header line {k + 1}")
                header_lines.append(line.rstrip("\n").rstrip("\r"))
    except OSError as e:
        raise SphynxIOError(f"Failed to open DLC csv {path}: {e}") from e

    row2 = header_lines[1].split(",")
    is_multi = bool(row2) and row2[0].strip().lower() == "individuals"
    if is_multi:
        num_header = 4
        bodyparts_tokens = header_lines[2].split(",")
        individuals_tokens = row2[1:]
    else:
        num_header = 3
        bodyparts_tokens = header_lines[1].split(",")
        individuals_tokens = []
    bodyparts_tokens = bodyparts_tokens[1:]  # drop the leading label
    n_cols = len(bodyparts_tokens)
    if n_cols % 3 != 0:
        raise SphynxIOError(f"Expected 3 columns per part, got {n_cols} data columns")

    try:
        data = pd.read_csv(path, skiprows=num_header, header=None).to_numpy(dtype=float)
    except (OSError, ValueError) as e:
        raise SphynxIOError(f"Failed to parse DLC csv data {path}: {e}") from e
    n_total = data.shape[0]
    end = end_frame if (end_frame != 0 and end_frame <= n_total) else n_total
    rows = slice(start_frame - 1, end)  # 1-based inclusive -> 0-based half-open

    if is_multi:
        part_cols, part_names, picked, all_individuals = _pick_multi_animal(
            individuals_tokens, bodyparts_tokens, data, individual
        )
        individuals_out: list[str] | None = all_individuals
        selected_out: str | None = picked
    else:
        if individual:
            raise SphynxIOError(
                f'Forced Individual "{individual}" requested but CSV is '
                "single-animal (no individuals to select)"
            )
        n_parts = n_cols // 3
        part_names = [bodyparts_tokens[i * 3] for i in range(n_parts)]
        part_cols = [i * 3 for i in range(n_parts)]
        individuals_out = None
        selected_out = None

    n_parts = len(part_names)
    n_sel = end - (start_frame - 1)
    xs = np.zeros((n_parts, n_sel))
    ys = np.zeros((n_parts, n_sel))
    ls = np.zeros((n_parts, n_sel))
    for part in range(n_parts):
        col = part_cols[part] + 1  # +1 to skip the frame-index column (col 0)
        xs[part, :] = data[rows, col]
        ys[part, :] = data[rows, col + 1]
        ls[part, :] = data[rows, col + 2]

    miss = (xs < 0) | (ys < 0)
    xs[miss] = np.nan
    ys[miss] = np.nan
    ls[miss] = np.nan

    return DlcData(
        body_parts=[t.strip() for t in part_names],
        X=xs, Y=ys, likelihood=ls, n_frames=n_sel,
        individuals=individuals_out, selected_individual=selected_out,
    )


def _pick_multi_animal(
    individuals_tokens: list[str],
    bodyparts_tokens: list[str],
    data: np.ndarray,
    forced: str,
) -> tuple[list[int], list[str], str, list[str]]:
    n_data_cols = len(individuals_tokens)
    if n_data_cols % 3 != 0:
        raise SphynxIOError(
            f"Multi-animal: column counts inconsistent ({n_data_cols} not divisible by 3)"
        )
    n_triplets = n_data_cols // 3
    triplet_individual = [individuals_tokens[t * 3].strip() for t in range(n_triplets)]
    triplet_bodypart = [bodyparts_tokens[t * 3].strip() for t in range(n_triplets)]

    all_individuals = list(dict.fromkeys(triplet_individual))  # unique, stable

    candidates = [
        name
        for name in all_individuals
        if len({triplet_bodypart[t] for t in range(n_triplets)
                if triplet_individual[t] == name}) > 1
    ]
    if not candidates:
        candidates = all_individuals

    if forced:
        if forced in all_individuals:
            picked = forced
        else:
            raise SphynxIOError(
                f'Forced Individual "{forced}" not in CSV; available: {all_individuals}'
            )
    else:
        best = -1
        picked = candidates[0]
        for name in candidates:
            score = 0
            for t in range(n_triplets):
                if triplet_individual[t] != name:
                    continue
                col = t * 3 + 1  # +1 to skip frame-index column
                xs = data[:, col]
                ys = data[:, col + 1]
                populated = ~np.isnan(xs) & ~np.isnan(ys) & (xs >= 0) & (ys >= 0)
                score += int(np.sum(populated))
            if score > best:
                best = score
                picked = name

    picked_idx = [t for t in range(n_triplets) if triplet_individual[t] == picked]
    part_names = [triplet_bodypart[t] for t in picked_idx]
    part_cols = [t * 3 for t in picked_idx]
    return part_cols, part_names, picked, all_individuals
