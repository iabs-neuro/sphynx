"""Session-wide overview plots to PNG (trajectory, occupancy heatmap, speed
histogram, speed vs time).

Port of sphynx.pipeline.saveSessionPlots (matlab/+sphynx/+pipeline/saveSessionPlots.m).
The MATLAB version also writes a .fig per plot; PNG only here. Uses the Agg
backend so it runs headless. Video overlays (renderActsVideo/renderActStitched)
are deferred to S4 (they need a source mp4 + frame-by-frame writer).
"""

from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")  # headless; must precede pyplot import
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
from scipy.ndimage import gaussian_filter  # noqa: E402

_TRACE_BLUE = (0.10, 0.50, 0.90)
_HIST_GREEN = (0.30, 0.70, 0.30)
_LINE_BLUE = (0.30, 0.55, 0.85)


def _opt(options, name, default=None):
    v = getattr(options, name, None) if options is not None else None
    return default if v is None else v


def _bodycenter_trace(result):
    """Return (x_smooth, y_smooth, velocity, name) for the bodycenter trace,
    falling back to the first kept trace (mirrors saveSessionPlots.m)."""
    traces = result.body_parts_traces
    if not traces:
        return np.array([]), np.array([]), np.array([]), ""
    idx = next(
        (i for i, t in enumerate(traces) if t.name.lower() == "bodycenter"), 0
    )
    t = traces[idx]
    x = np.asarray(t.x_smooth, dtype=float).ravel()
    y = np.asarray(t.y_smooth, dtype=float).ravel()
    v = np.asarray(t.velocity, dtype=float).ravel() if t.velocity is not None else np.array([])
    return x, y, v, t.name


def _save(fig, out_dir: Path, base: str) -> str:
    png = out_dir / f"{base}.png"
    fig.savefig(png, dpi=100, bbox_inches="tight")
    plt.close(fig)
    return str(png)


def _render_trajectory(x_cm, y_cm, name):
    fig, ax = plt.subplots(figsize=(8, 7))
    ax.plot(x_cm, y_cm, "-", color=_TRACE_BLUE, linewidth=1.2)
    ax.set_aspect("equal", adjustable="box")
    ax.invert_yaxis()  # image coords: y grows downward
    ax.set_xlabel("X, cm", fontsize=14)
    ax.set_ylabel("Y, cm", fontsize=14)
    ax.tick_params(labelsize=13)
    ax.set_title(f"Trajectory ({name})", fontsize=15)
    return fig


def _render_heatmap(x_cm, y_cm, options, bin_cm, fps):
    fig, ax = plt.subplots(figsize=(8, 7))
    valid = np.isfinite(x_cm) & np.isfinite(y_cm)
    extent_x = float(np.nanmax(x_cm)) if valid.any() else bin_cm
    extent_y = float(np.nanmax(y_cm)) if valid.any() else bin_cm
    width = _opt(options, "Width")
    height = _opt(options, "Height")
    pxl = _opt(options, "pxl2sm")
    if width is not None and height is not None and pxl:
        extent_x = float(width) / float(pxl)
        extent_y = float(height) / float(pxl)
    edges_x = np.arange(0, max(extent_x, bin_cm) + bin_cm, bin_cm)
    edges_y = np.arange(0, max(extent_y, bin_cm) + bin_cm, bin_cm)
    counts, _, _ = np.histogram2d(x_cm[valid], y_cm[valid], bins=[edges_x, edges_y])
    secs = counts / fps
    secs_smooth = gaussian_filter(secs, sigma=1)
    im = ax.imshow(
        secs_smooth.T, origin="upper", aspect="equal",
        extent=[edges_x[0], edges_x[-1], edges_y[-1], edges_y[0]],
        cmap="viridis",
    )
    cb = fig.colorbar(im, ax=ax)
    cb.set_label("time, s", fontsize=14)
    cb.ax.tick_params(labelsize=12)
    ax.set_xlim(0, extent_x)
    ax.set_ylim(extent_y, 0)
    ax.set_xlabel("X, cm", fontsize=14)
    ax.set_ylabel("Y, cm", fontsize=14)
    ax.tick_params(labelsize=13)
    ax.set_title(f"Occupancy ({bin_cm:g} cm bins, gaussian sigma=1 bin)", fontsize=15)
    return fig


def _render_speed_histogram(v, name):
    fig, ax = plt.subplots(figsize=(8, 5))
    finite = v[np.isfinite(v)] if v.size else v
    if finite.size:
        ax.hist(finite, bins=150, color=_HIST_GREEN, edgecolor="none")
    ax.set_xlabel("speed, cm/s", fontsize=14)
    ax.set_ylabel("frames", fontsize=14)
    ax.tick_params(labelsize=13)
    ax.set_title(f"Speed histogram ({name})", fontsize=15)
    return fig


def _render_speed_trace(v, fps, name):
    fig, ax = plt.subplots(figsize=(10, 4))
    if v.size:
        if np.isfinite(fps) and fps > 0:
            t = np.arange(v.size) / fps
            ax.plot(t, v, "-", color=_LINE_BLUE, linewidth=0.8)
            ax.set_xlabel("time, s", fontsize=14)
        else:
            ax.plot(np.arange(v.size), v, "-", color=_LINE_BLUE, linewidth=0.8)
            ax.set_xlabel("frame", fontsize=14)
        ax.set_ylabel("speed, cm/s", fontsize=14)
    ax.tick_params(labelsize=13)
    ax.set_title(f"Speed vs time ({name})", fontsize=15)
    return fig


def save_session_plots(result, out_dir, heatmap_bin_cm: float = 4.0, prefix: str = "") -> dict:
    """Write the four session overview PNGs and return {which: png_path}.

    `result` is a SessionResult (or any object exposing body_parts_traces and
    options). `out_dir` is created if missing.
    """
    if not (heatmap_bin_cm > 0):
        from sphynx.exceptions import SphynxValueError
        raise SphynxValueError(f"heatmap_bin_cm must be > 0; got {heatmap_bin_cm}")

    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)

    options = getattr(result, "options", None)
    pxl_per_cm = float(_opt(options, "pxl2sm", 1.0))
    fps = float(_opt(options, "FrameRate", 30.0))

    x, y, v, name = _bodycenter_trace(result)
    x_cm = x / pxl_per_cm
    y_cm = y / pxl_per_cm

    paths = {}
    paths["trajectory"] = _save(_render_trajectory(x_cm, y_cm, name), out, f"{prefix}trajectory")
    paths["heatmap"] = _save(_render_heatmap(x_cm, y_cm, options, heatmap_bin_cm, fps), out, f"{prefix}heatmap")
    paths["speed_histogram"] = _save(_render_speed_histogram(v, name), out, f"{prefix}speed_histogram")
    paths["speed_vs_time"] = _save(_render_speed_trace(v, fps, name), out, f"{prefix}speed_vs_time")
    return paths
