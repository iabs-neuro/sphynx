"""Draw zones on a video frame (S4d).

Drawing uses matplotlib's own selectors rather than hand-written mouse
handling: less code, and fewer places to get a coordinate convention wrong.

Masks are FILLED regions, not outlines -- a zone is the area an animal can be
inside of. `sphynx.preset.mask.mask_from_border` marks only the border pixels,
so the interior comes from a point-in-polygon test, the same one the
preprocess orchestrator uses.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure
from matplotlib.path import Path as MplPath
from matplotlib.widgets import EllipseSelector, PolygonSelector, RectangleSelector
from PySide6.QtCore import Signal
from PySide6.QtWidgets import QVBoxLayout, QWidget

from sphynx.exceptions import SphynxValueError

KINDS = ("rectangle", "ellipse", "polygon")
_OUTLINE = {"rectangle": "#e8c547", "ellipse": "#7ec8e3", "polygon": "#c586c0"}
_PICKED = "#4ec9b0"              # calibration clicks, distinct from any shape


@dataclass
class Shape:
    """One drawn figure, in pixel coordinates of the frame."""

    name: str
    kind: str
    geometry: dict = field(default_factory=dict)
    points: list = field(default_factory=list)


def _vertices(shape) -> np.ndarray:
    """The closed outline of a shape as an (N, 2) array of (x, y)."""
    points = [(float(x), float(y)) for x, y in shape.points]
    if shape.kind == "polygon":
        if len(points) < 3:
            raise SphynxValueError(
                f"polygon {shape.name!r} needs at least 3 points; "
                f"got {len(points)}")
        return np.asarray(points, dtype=float)

    if len(points) != 2:
        raise SphynxValueError(
            f"{shape.kind} {shape.name!r} is two corners; got {len(points)}")
    (x0, y0), (x1, y1) = points
    x0, x1 = min(x0, x1), max(x0, x1)
    y0, y1 = min(y0, y1), max(y0, y1)

    if shape.kind == "rectangle":
        return np.asarray([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], dtype=float)

    # An ellipse inscribed in the box, sampled finely enough that the mask
    # does not show the sampling.
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    rx, ry = (x1 - x0) / 2.0, (y1 - y0) / 2.0
    angle = np.linspace(0.0, 2.0 * np.pi, 361)[:-1]
    return np.column_stack([cx + rx * np.cos(angle), cy + ry * np.sin(angle)])


def shape_vertices(shape) -> np.ndarray:
    """The closed outline of a shape as an (N, 2) array of (x, y) pixels."""
    return _vertices(shape)


def shape_mask(shape, height: int, width: int) -> np.ndarray:
    """A filled HxW mask, clipped to the frame.

    A shape drawn off the edge is clipped, not refused: the animal cannot be
    outside the frame anyway, and refusing would lose the whole zone."""
    vertices = _vertices(shape)
    ys, xs = np.mgrid[0:height, 0:width]
    points = np.column_stack([xs.ravel(), ys.ravel()])
    if shape.kind == "rectangle":
        # contains_points excludes the upper edge of an axis-aligned path, so
        # a rectangle is tested by its bounds directly and stays inclusive.
        x0, y0 = vertices.min(axis=0)
        x1, y1 = vertices.max(axis=0)
        inside = ((points[:, 0] >= x0) & (points[:, 0] <= x1)
                  & (points[:, 1] >= y0) & (points[:, 1] <= y1))
    else:
        inside = MplPath(vertices).contains_points(points)
    return inside.reshape(height, width)


class PresetCanvas(QWidget):
    """An embedded matplotlib canvas that shows a frame and collects shapes.

    It also collects bare points, which is how calibration is measured: the
    reference length is clicked on the frame itself rather than inferred from
    a shape drawn for another purpose."""

    shape_drawn = Signal(str)
    points_picked = Signal(list)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.shapes: list = []
        self.tool = "rectangle"
        self.frame_shape = None
        self.points: list = []           # calibration clicks, in frame pixels
        self._frame = None
        self._selector = None
        self._pending_name = None
        self._wanted_points = 0
        self._click_cid = None

        self.figure = Figure(figsize=(6.0, 4.5), layout="constrained")
        self.axes = self.figure.add_subplot(111)
        self.axes.set_axis_off()
        self.canvas = FigureCanvas(self.figure)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.addWidget(self.canvas)

    # --- the frame --------------------------------------------------------
    def show_frame(self, frame) -> None:
        frame = np.asarray(frame)
        if frame.ndim not in (2, 3):
            raise SphynxValueError(
                f"a frame is a 2-D or 3-D image; got shape {frame.shape}")
        self._frame = frame
        self.frame_shape = (int(frame.shape[0]), int(frame.shape[1]))
        # A selector armed on the old axes would keep drawing onto artists
        # that _redraw is about to throw away.
        self.cancel_shape()
        # Points measured on one frame describe that frame. Keeping them
        # across a change would let a length clicked on frame 0 be computed
        # against frame 9000 of a video that was re-opened at another size.
        self.clear_points()
        self._redraw()

    # --- tools ------------------------------------------------------------
    def set_tool(self, kind: str) -> None:
        if kind not in KINDS:
            raise SphynxValueError(
                f"unknown drawing tool {kind!r}; expected one of {KINDS}")
        self.tool = kind
        if self._pending_name is not None:
            self.begin_shape(self._pending_name)

    def begin_shape(self, name: str) -> None:
        """Arm the current tool; the next drag or polygon becomes `name`."""
        self.cancel_points()
        self._pending_name = str(name)
        self._disconnect_selector()
        if self.tool == "rectangle":
            self._selector = RectangleSelector(
                self.axes, self._on_box, useblit=False, interactive=False)
        elif self.tool == "ellipse":
            self._selector = EllipseSelector(
                self.axes, self._on_box, useblit=False, interactive=False)
        else:
            self._selector = PolygonSelector(
                self.axes, self._on_polygon, useblit=False)

    def cancel_shape(self) -> None:
        self._pending_name = None
        self._disconnect_selector()

    def _disconnect_selector(self) -> None:
        if self._selector is not None:
            self._selector.set_active(False)
            self._selector.disconnect_events()
            self._selector = None

    # --- picking bare points ---------------------------------------------
    def begin_points(self, count: int) -> None:
        """Collect `count` clicks, then emit them as one list.

        Any half-finished previous pick is dropped: leaving two of the four
        points of an earlier attempt on the canvas would silently mix two
        measurements into one calibration."""
        count = int(count)
        if count < 1:
            raise SphynxValueError(
                f"a point pick collects at least one point; got {count}")
        self._disconnect_selector()
        self._pending_name = None
        self.points = []
        self._wanted_points = count
        if self._click_cid is None:
            self._click_cid = self.canvas.mpl_connect(
                "button_press_event", self._on_click)
        self._redraw()

    def cancel_points(self) -> None:
        self._wanted_points = 0
        if self._click_cid is not None:
            self.canvas.mpl_disconnect(self._click_cid)
            self._click_cid = None

    def clear_points(self) -> None:
        self.cancel_points()
        self.points = []
        self._redraw()

    def add_point(self, x, y) -> None:
        """Record one picked point; emits once the wanted count is reached."""
        if self._wanted_points < 1:
            return
        self.points.append((float(x), float(y)))
        if len(self.points) >= self._wanted_points:
            picked = list(self.points)
            self.cancel_points()
            self._redraw()
            self.points_picked.emit(picked)
            return
        self._redraw()

    def _on_click(self, event) -> None:
        if event.inaxes is not self.axes:
            return
        if event.xdata is None or event.ydata is None:
            return
        self.add_point(event.xdata, event.ydata)

    # --- selector callbacks ----------------------------------------------
    def _on_box(self, press, release) -> None:
        if self._pending_name is None:
            return
        points = [(press.xdata, press.ydata), (release.xdata, release.ydata)]
        if any(v is None for point in points for v in point):
            return                       # a drag that left the axes
        self.add_shape(self._pending_name, self.tool, points)

    def _on_polygon(self, vertices) -> None:
        if self._pending_name is None or len(vertices) < 3:
            return
        self.add_shape(self._pending_name, "polygon",
                       [(float(x), float(y)) for x, y in vertices])

    # --- the shape list ---------------------------------------------------
    def add_shape(self, name: str, kind: str, points) -> Shape:
        if kind not in KINDS:
            raise SphynxValueError(
                f"unknown shape kind {kind!r}; expected one of {KINDS}")
        points = [(float(x), float(y)) for x, y in points]
        shape = Shape(name=str(name), kind=kind, points=points)
        _vertices(shape)                 # refuse a degenerate shape here, not
                                         # later when its mask comes out empty
        self.remove_shape(shape.name)
        self.shapes.append(shape)
        self._pending_name = None
        self._disconnect_selector()
        self._redraw()
        self.shape_drawn.emit(shape.name)
        return shape

    def remove_shape(self, name: str) -> bool:
        before = len(self.shapes)
        self.shapes = [s for s in self.shapes if s.name != name]
        removed = len(self.shapes) != before
        if removed:
            self.cancel_shape()
            self._redraw()
        return removed

    def clear_shapes(self) -> None:
        self.shapes = []
        self.cancel_shape()
        self._redraw()

    def mask_for(self, shape, height: int, width: int) -> np.ndarray:
        return shape_mask(shape, int(height), int(width))

    # --- drawing ----------------------------------------------------------
    def _redraw(self) -> None:
        self.axes.clear()
        self.axes.set_axis_off()
        if self._frame is not None:
            self.axes.imshow(self._frame)
        for shape in self.shapes:
            outline = _vertices(shape)
            closed = np.vstack([outline, outline[:1]])
            self.axes.plot(closed[:, 0], closed[:, 1], "-", linewidth=1.4,
                           color=_OUTLINE[shape.kind])
            self.axes.annotate(shape.name, (outline[:, 0].mean(),
                                            outline[:, 1].mean()),
                               color=_OUTLINE[shape.kind], fontsize=8,
                               ha="center", va="center")
        if self.points:
            picked = np.asarray(self.points, dtype=float)
            self.axes.plot(picked[:, 0], picked[:, 1], "+", markersize=10,
                           color=_PICKED, markeredgewidth=1.4)
            # Points are consumed in pairs, so joining them in pairs shows
            # what is about to be measured rather than one zigzag.
            for start in range(0, len(picked) - 1, 2):
                pair = picked[start:start + 2]
                self.axes.plot(pair[:, 0], pair[:, 1], "-", linewidth=1.0,
                               color=_PICKED)
            for order, (x, y) in enumerate(picked, start=1):
                self.axes.annotate(str(order), (x, y), color=_PICKED,
                                   fontsize=8, ha="left", va="bottom")
        if self.frame_shape is not None:
            height, width = self.frame_shape
            self.axes.set_xlim(-0.5, width - 0.5)
            self.axes.set_ylim(height - 0.5, -0.5)
        self.canvas.draw_idle()
