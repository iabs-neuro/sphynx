"""Pixels-per-cm calibration.

Port of matlab/+sphynx/+preset/pixelsPerCm.m together with the three modes the
MATLAB Create Preset app offers (CreatePresetApp.m, onCalibrateChoose /
onCalibrateCompute):

    '4 points'  click a vertical pair then a horizontal pair
    '2 lines'   drag a vertical reference line then a horizontal one
    '1 line'    drag one diagonal reference line of known total length

The first two measure the two axes separately, so they can detect a pixel that
is not square and report it as `x_kcorr`; the third measures one length and
scales both axes by it.

MATLAB divides by the measured pixel separation without checking it. A pair
clicked twice on the same spot therefore yields pxl/cm = 0 there, and every
distance, speed and zone width in the session silently becomes zero or
infinite. Those cases raise here instead.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np

from sphynx.exceptions import SphynxValueError

MODES = ("1 line", "2 lines", "4 points")

# Below 20 deg or above 70 deg from horizontal the single-line measurement is
# nearly an axis measurement, and it is usually a sign the line was dragged
# along the arena frame rather than across it (CreatePresetApp.m R14.6).
MIN_LINE_ANGLE_DEG = 20.0
MAX_LINE_ANGLE_DEG = 70.0

# Above this percentage the two axes are treated as genuinely different scales
# rather than measurement noise.
PERCENT_THRESHOLD = 3.0

_ANGLE_TOLERANCE_DEG = 1e-9      # so a line drawn exactly at the limit passes


@dataclass
class Calibration:
    """One calibration measurement, in the terms the preset Options use."""

    pixels_per_cm: float         # Options.pxl2sm
    x_kcorr: float               # Options.x_kcorr
    pxl_y: float                 # Options.pxl2smY
    pxl_x: float                 # Options.pxl2smX
    diff_pct: float              # how far the two axes disagreed
    mode: str

    @property
    def is_anisotropic(self) -> bool:
        return self.x_kcorr != 1.0


def _points(raw, expected: int, what: str) -> np.ndarray:
    points = np.asarray([(float(x), float(y)) for x, y in raw], dtype=float)
    if points.shape[0] != expected:
        raise SphynxValueError(
            f"{what} needs exactly {expected} points; got {points.shape[0]}")
    if not np.isfinite(points).all():
        raise SphynxValueError(f"{what} has a point that is not a number")
    return points


def _distance(value, name: str) -> float:
    value = float(value)
    if not value > 0:
        raise SphynxValueError(
            f"the {name} distance must be greater than zero; got {value:g}")
    return value


def _scale(pixels: float, distance_cm: float, axis: str) -> float:
    if not pixels > 0:
        where = "height" if axis == "vertical" else "column"
        raise SphynxValueError(
            f"the {axis} reference has no {axis} extent: its two points sit at "
            f"the same {where}, so pixels-per-cm cannot be measured from them")
    return pixels / distance_cm


def _combine(pxl_y: float, pxl_x: float, mode: str,
             percent_threshold: float) -> Calibration:
    """Average the two axes, or keep y and express x as a correction factor."""
    diff_pct = abs(pxl_x - pxl_y) / pxl_x * 100.0
    if diff_pct > percent_threshold:
        return Calibration(pixels_per_cm=pxl_y, x_kcorr=pxl_y / pxl_x,
                           pxl_y=pxl_y, pxl_x=pxl_x, diff_pct=diff_pct,
                           mode=mode)
    return Calibration(pixels_per_cm=(pxl_y + pxl_x) / 2.0, x_kcorr=1.0,
                       pxl_y=pxl_y, pxl_x=pxl_x, diff_pct=diff_pct, mode=mode)


def calibrate_four_points(points, distance_y_cm, distance_x_cm,
                          percent_threshold: float = PERCENT_THRESHOLD,
                          mode: str = "4 points") -> Calibration:
    """Points 1-2 are the vertical pair, points 3-4 the horizontal one.

    Only the axis projection of each pair counts, as in pixelsPerCm.m: the
    vertical pair contributes |dy| and the horizontal pair |dx|, so a pair
    clicked slightly off-axis still measures the axis it was meant for."""
    pts = _points(points, 4, mode)
    distance_y_cm = _distance(distance_y_cm, "vertical")
    distance_x_cm = _distance(distance_x_cm, "horizontal")
    pxl_y = _scale(abs(pts[1, 1] - pts[0, 1]), distance_y_cm, "vertical")
    pxl_x = _scale(abs(pts[3, 0] - pts[2, 0]), distance_x_cm, "horizontal")
    return _combine(pxl_y, pxl_x, mode, percent_threshold)


def calibrate_two_lines(line_y, line_x, distance_y_cm, distance_x_cm,
                        percent_threshold: float = PERCENT_THRESHOLD
                        ) -> Calibration:
    """Two dragged reference lines, one per axis.

    Identical to the four-point mode once the endpoints are unpacked: only
    each line's projection onto its own axis is measured."""
    ends_y = _points(line_y, 2, "the vertical reference line (two endpoints)")
    ends_x = _points(line_x, 2, "the horizontal reference line (two endpoints)")
    return calibrate_four_points(
        [ends_y[0], ends_y[1], ends_x[0], ends_x[1]],
        distance_y_cm, distance_x_cm, percent_threshold, mode="2 lines")


def calibrate_one_line(line, length_cm,
                       min_angle_deg: float = MIN_LINE_ANGLE_DEG,
                       max_angle_deg: float = MAX_LINE_ANGLE_DEG
                       ) -> Calibration:
    """One diagonal line of known total length, scaling both axes alike.

    A single line cannot separate the two axes, so `x_kcorr` is 1 by
    construction. Use a two-axis mode when the pixel may not be square."""
    ends = _points(line, 2, "the reference line (two endpoints)")
    length_cm = _distance(length_cm, "reference length")
    dx = ends[1, 0] - ends[0, 0]
    dy = ends[1, 1] - ends[0, 1]
    length_px = math.hypot(dx, dy)
    if not length_px > 0:
        raise SphynxValueError(
            "the reference line has zero length: its two endpoints are the "
            "same point")

    # Folded to 0..90, so which way the line was dragged does not matter.
    angle_deg = abs(math.degrees(math.atan2(dy, dx)))
    if angle_deg > 90.0:
        angle_deg = 180.0 - angle_deg
    if (angle_deg < min_angle_deg - _ANGLE_TOLERANCE_DEG
            or angle_deg > max_angle_deg + _ANGLE_TOLERANCE_DEG):
        raise SphynxValueError(
            f"the reference line sits at {angle_deg:.1f} deg from horizontal, "
            f"outside the allowed {min_angle_deg:g}..{max_angle_deg:g} deg; a "
            "line that close to an axis is usually the arena frame rather "
            "than a diagonal across it. Draw it again, or use the '2 lines' "
            "or '4 points' mode to measure the axes separately")

    scale = length_px / length_cm
    return Calibration(pixels_per_cm=scale, x_kcorr=1.0, pxl_y=scale,
                       pxl_x=scale, diff_pct=0.0, mode="1 line")


def calibrate(mode: str, points, distance_y_cm, distance_x_cm=None,
              percent_threshold: float = PERCENT_THRESHOLD) -> Calibration:
    """Dispatch to the mode named the way the app names it.

    `points` is a flat list: two endpoints for '1 line', four for the other
    two modes (the two lines of '2 lines' laid end to end)."""
    if mode == "1 line":
        return calibrate_one_line(points, distance_y_cm)
    if mode == "2 lines":
        pts = _points(points, 4, "2 lines")
        return calibrate_two_lines(pts[:2], pts[2:], distance_y_cm,
                                   distance_x_cm, percent_threshold)
    if mode == "4 points":
        return calibrate_four_points(points, distance_y_cm, distance_x_cm,
                                     percent_threshold)
    raise SphynxValueError(
        f"unknown calibration mode {mode!r}; expected one of {MODES}")


def points_needed(mode: str) -> int:
    """How many clicks the mode collects, so the UI can arm itself."""
    if mode == "1 line":
        return 2
    if mode in ("2 lines", "4 points"):
        return 4
    raise SphynxValueError(
        f"unknown calibration mode {mode!r}; expected one of {MODES}")


def pixels_per_cm(points, distances_cm, percent_threshold: float = 3):
    """Legacy tuple-returning form of the four-point mode.

    points: 4x2 [x, y] (pts 1-2 = vertical pair, 3-4 = horizontal pair);
    distances_cm: [d_vertical, d_horizontal]. Returns
    (ppc, x_kcorr, pxl_y, pxl_x, diff_pct)."""
    result = calibrate_four_points(points, distances_cm[0], distances_cm[1],
                                   percent_threshold)
    return (result.pixels_per_cm, result.x_kcorr, result.pxl_y, result.pxl_x,
            result.diff_pct)
