"""Four session plots in a 2x2 grid, any one of which can be maximised (S4a).

Rendering reuses the same maths as sphynx.plot.session_plots but draws onto
embedded canvases instead of writing PNGs.
"""

from __future__ import annotations

import numpy as np
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure
from PySide6.QtWidgets import QGridLayout, QWidget
from scipy.ndimage import gaussian_filter

from sphynx.plot.etogram import draw_etogram

PLOT_NAMES = ("trajectory", "heatmap", "speed_histogram", "speed_vs_time", "etogram")
_TITLES = {
    "trajectory": "Trajectory",
    "heatmap": "Occupancy",
    "speed_histogram": "Speed histogram",
    "speed_vs_time": "Speed vs time",
    "etogram": "Etogram",
}
_POSITIONS = {"trajectory": (0, 0), "heatmap": (0, 1),
              "speed_histogram": (1, 0), "speed_vs_time": (1, 1), "etogram": (2, 0)}


class _ClickableCanvas(FigureCanvas):
    def __init__(self, figure, name, on_double_click):
        super().__init__(figure)
        self._name = name
        self._on_double_click = on_double_click

    def mouseDoubleClickEvent(self, event):   # noqa: N802 - Qt naming
        self._on_double_click(self._name)
        super().mouseDoubleClickEvent(event)


def _opt(options, name, default):
    value = getattr(options, name, None) if options is not None else None
    return default if value is None else value


def _reference_trace(result):
    traces = list(getattr(result, "body_parts_traces", []) or [])
    if not traces:
        return None
    for trace in traces:
        if str(getattr(trace, "name", "")).lower() == "bodycenter":
            return trace
    return traces[0]


class PlotGrid(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.canvases: dict = {}
        self.maximised: str | None = None
        self._layout = QGridLayout(self)
        for name in PLOT_NAMES:
            canvas = _ClickableCanvas(Figure(figsize=(4, 3)), name,
                                      self.toggle_maximise)
            self.canvases[name] = canvas
            row, column = _POSITIONS[name]
            span = 2 if name == "etogram" else 1
            self._layout.addWidget(canvas, row, column, 1, span)

    def clear(self) -> None:
        for canvas in self.canvases.values():
            canvas.figure.clear()
            canvas.draw_idle()

    def toggle_maximise(self, name: str) -> None:
        self.maximised = None if self.maximised == name else name
        for other, canvas in self.canvases.items():
            canvas.setVisible(self.maximised is None or other == self.maximised)

    def show_result(self, result, heatmap_bin_cm: float = 4.0) -> None:
        trace = _reference_trace(result)
        options = getattr(result, "options", None)
        pixels_per_cm = float(_opt(options, "pxl2sm", 1.0)) or 1.0
        frame_rate = float(_opt(options, "FrameRate", 30.0)) or 30.0

        if trace is None:
            self.clear()
            return

        x_cm = np.asarray(trace.x_smooth, dtype=float) / pixels_per_cm
        y_cm = np.asarray(trace.y_smooth, dtype=float) / pixels_per_cm
        velocity = np.asarray(
            trace.velocity if trace.velocity is not None else [], dtype=float)

        self._draw_trajectory(x_cm, y_cm)
        self._draw_heatmap(x_cm, y_cm, options, pixels_per_cm,
                           heatmap_bin_cm, frame_rate)
        self._draw_speed_histogram(velocity)
        self._draw_speed_trace(velocity, frame_rate)
        self._draw_etogram(getattr(result, "acts", None), frame_rate)
        for canvas in self.canvases.values():
            canvas.draw_idle()

    def _axes(self, name):
        figure = self.canvases[name].figure
        figure.clear()
        axes = figure.add_subplot(111)
        axes.set_title(_TITLES[name], fontsize=10)
        return axes

    def _draw_trajectory(self, x_cm, y_cm):
        axes = self._axes("trajectory")
        axes.plot(x_cm, y_cm, "-", color=(0.10, 0.50, 0.90), linewidth=1.0)
        axes.set_aspect("equal", adjustable="box")
        axes.invert_yaxis()
        axes.set_xlabel("X, cm")
        axes.set_ylabel("Y, cm")

    def _draw_heatmap(self, x_cm, y_cm, options, pixels_per_cm, bin_cm, frame_rate):
        axes = self._axes("heatmap")
        valid = np.isfinite(x_cm) & np.isfinite(y_cm)
        if not valid.any():
            return
        width = _opt(options, "Width", None)
        height = _opt(options, "Height", None)
        extent_x = (float(width) / pixels_per_cm if width is not None
                    else float(np.nanmax(x_cm)))
        extent_y = (float(height) / pixels_per_cm if height is not None
                    else float(np.nanmax(y_cm)))
        edges_x = np.arange(0, max(extent_x, bin_cm) + bin_cm, bin_cm)
        edges_y = np.arange(0, max(extent_y, bin_cm) + bin_cm, bin_cm)
        counts, _, _ = np.histogram2d(x_cm[valid], y_cm[valid],
                                      bins=[edges_x, edges_y])
        seconds = gaussian_filter(counts / frame_rate, sigma=1)
        image = axes.imshow(
            seconds.T, origin="upper", aspect="equal", cmap="viridis",
            extent=[edges_x[0], edges_x[-1], edges_y[-1], edges_y[0]])
        axes.figure.colorbar(image, ax=axes, label="time, s")
        axes.set_xlabel("X, cm")
        axes.set_ylabel("Y, cm")

    def _draw_speed_histogram(self, velocity):
        axes = self._axes("speed_histogram")
        finite = velocity[np.isfinite(velocity)] if velocity.size else velocity
        if finite.size:
            axes.hist(finite, bins=100, color=(0.30, 0.70, 0.30), edgecolor="none")
        axes.set_xlabel("speed, cm/s")
        axes.set_ylabel("frames")

    def _draw_speed_trace(self, velocity, frame_rate):
        axes = self._axes("speed_vs_time")
        if velocity.size:
            axes.plot(np.arange(velocity.size) / frame_rate, velocity, "-",
                      color=(0.30, 0.55, 0.85), linewidth=0.8)
        axes.set_xlabel("time, s")
        axes.set_ylabel("speed, cm/s")

    def _draw_etogram(self, acts, frame_rate):
        axes = self._axes("etogram")
        draw_etogram(axes, [a for a in (acts or []) if a.array is not None],
                     frame_rate, max_acts=12)
