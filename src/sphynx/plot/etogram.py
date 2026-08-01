"""Etogram: one row of episode bars per act along the session timeline (S4b)."""

from __future__ import annotations

import numpy as np

from sphynx.acts.refine import refine_act
from sphynx.exceptions import SphynxValueError

_BAR_COLOUR = (0.20, 0.45, 0.75)


def draw_etogram(axes, acts, frame_rate, max_acts=None) -> list:
    """Draw the acts onto `axes` and return the names in row order.

    Truncation is stated on the plot rather than left silent: a chart that
    quietly shows five of twelve acts reads as the whole picture."""
    if not frame_rate > 0:
        raise SphynxValueError(f"frame_rate must be positive; got {frame_rate}")

    acts = list(acts or [])
    total = len(acts)
    if max_acts is not None and total > max_acts:
        acts = acts[:max_acts]

    if not acts:
        axes.text(0.5, 0.5, "No acts to show", ha="center", va="center",
                  transform=axes.transAxes)
        axes.set_yticks([])
        return []

    names = []
    duration = 0.0
    for row, act in enumerate(acts):
        mask = np.asarray(getattr(act, "array", []), dtype=float)
        duration = max(duration, mask.size / frame_rate)
        _, runs = refine_act(mask.astype(bool), 0, 0)
        spans = [(run.frame_in / frame_rate, run.duration / frame_rate)
                 for run in runs]
        axes.broken_barh(spans, (row - 0.4, 0.8), facecolors=_BAR_COLOUR)
        names.append(str(getattr(act, "name", "")))

    axes.set_yticks(range(len(names)))
    axes.set_yticklabels(names, fontsize=8)
    axes.invert_yaxis()
    axes.set_ylim(len(names) - 0.5, -0.5)
    axes.set_xlim(0, duration)
    axes.set_xlabel("time, s")

    if max_acts is not None and total > max_acts:
        axes.text(0.99, 1.02, f"showing {len(names)} of {total} acts",
                  ha="right", va="bottom", transform=axes.transAxes, fontsize=8)
    return names
