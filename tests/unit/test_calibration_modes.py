"""The three calibration modes of CreatePresetApp (4 points / 2 lines / 1 line).

Ported from matlab/+sphynx/+app/CreatePresetApp.m (onCalibrateChoose,
onCalibrateCompute) and matlab/+sphynx/+preset/pixelsPerCm.m. Where MATLAB
divides by zero and carries the result on silently, these raise instead.
"""

import numpy as np
import pytest

from sphynx.exceptions import SphynxValueError
from sphynx.preset.calibration import (
    MODES, Calibration, calibrate, calibrate_four_points, calibrate_one_line,
    calibrate_two_lines,
)


# --- 4 points ------------------------------------------------------------
def test_four_points_uses_axis_projections_not_euclidean_length():
    # Points 1-2 give Y from |dy| alone, points 3-4 give X from |dx| alone,
    # exactly as pixelsPerCm.m does; the off-axis drift must not count.
    points = [(0.0, 0.0), (37.0, 100.0),       # dy = 100 despite dx = 37
              (0.0, 0.0), (100.0, 21.0)]       # dx = 100 despite dy = 21
    result = calibrate_four_points(points, 10.0, 10.0)
    assert result.pxl_y == pytest.approx(10.0)
    assert result.pxl_x == pytest.approx(10.0)
    assert result.pixels_per_cm == pytest.approx(10.0)
    assert result.x_kcorr == pytest.approx(1.0)


def test_four_points_within_threshold_averages_and_leaves_kcorr_at_one():
    points = [(0.0, 0.0), (0.0, 100.0), (0.0, 0.0), (102.0, 0.0)]
    result = calibrate_four_points(points, 10.0, 10.0)
    assert result.pixels_per_cm == pytest.approx(10.1)
    assert result.x_kcorr == pytest.approx(1.0)
    assert result.diff_pct == pytest.approx(0.2 / 10.2 * 100.0)


def test_four_points_beyond_threshold_keeps_y_and_reports_kcorr():
    # 100 px/10 cm vertically, 200 px/10 cm horizontally: the pixel is twice
    # as wide as it is tall, so y wins and x is corrected by the ratio.
    points = [(0.0, 0.0), (0.0, 100.0), (0.0, 0.0), (200.0, 0.0)]
    result = calibrate_four_points(points, 10.0, 10.0)
    assert result.pixels_per_cm == pytest.approx(10.0)
    assert result.pxl_x == pytest.approx(20.0)
    assert result.x_kcorr == pytest.approx(0.5)
    assert result.mode == "4 points"


def test_four_points_needs_exactly_four_points():
    with pytest.raises(SphynxValueError, match="4 points"):
        calibrate_four_points([(0.0, 0.0), (0.0, 100.0)], 10.0, 10.0)


def test_a_zero_separation_is_an_error_not_a_zero_scale():
    # MATLAB divides here and carries pxl/cm = 0 into every distance in the
    # session. A pair clicked twice on the same spot is a misclick.
    points = [(0.0, 50.0), (0.0, 50.0), (0.0, 0.0), (100.0, 0.0)]
    with pytest.raises(SphynxValueError, match="vertical"):
        calibrate_four_points(points, 10.0, 10.0)


def test_a_zero_distance_in_cm_is_an_error():
    points = [(0.0, 0.0), (0.0, 100.0), (0.0, 0.0), (100.0, 0.0)]
    with pytest.raises(SphynxValueError, match="greater than zero"):
        calibrate_four_points(points, 0.0, 10.0)


# --- 2 lines -------------------------------------------------------------
def test_two_lines_pack_as_the_same_four_points():
    line_y = [(10.0, 5.0), (13.0, 105.0)]      # |dy| = 100
    line_x = [(4.0, 60.0), (204.0, 66.0)]      # |dx| = 200
    lines = calibrate_two_lines(line_y, line_x, 10.0, 10.0)
    points = calibrate_four_points(
        [line_y[0], line_y[1], line_x[0], line_x[1]], 10.0, 10.0)
    assert lines.pixels_per_cm == pytest.approx(points.pixels_per_cm)
    assert lines.x_kcorr == pytest.approx(points.x_kcorr)
    assert lines.mode == "2 lines"


def test_a_reference_line_needs_two_endpoints():
    with pytest.raises(SphynxValueError, match="two endpoints"):
        calibrate_two_lines([(0.0, 0.0)], [(0.0, 0.0), (100.0, 0.0)],
                            10.0, 10.0)


# --- 1 line --------------------------------------------------------------
def test_one_line_uses_the_full_euclidean_length_and_scales_uniformly():
    # 3-4-5 triangle: 30 px across, 40 px down, 50 px long.
    result = calibrate_one_line([(0.0, 0.0), (30.0, 40.0)], 10.0)
    assert result.pixels_per_cm == pytest.approx(5.0)
    assert result.pxl_x == pytest.approx(5.0)
    assert result.pxl_y == pytest.approx(5.0)
    assert result.x_kcorr == pytest.approx(1.0)
    assert result.diff_pct == pytest.approx(0.0)
    assert result.mode == "1 line"


@pytest.mark.parametrize("end", [(100.0, 5.0), (5.0, 100.0)])
def test_one_line_refuses_a_line_too_close_to_an_axis(end):
    # Near-axis lines make the kcorr split degenerate and usually mean the
    # user dragged along the arena frame instead of a true diagonal.
    with pytest.raises(SphynxValueError, match="20"):
        calibrate_one_line([(0.0, 0.0), end], 10.0)


def test_one_line_accepts_the_ends_of_the_allowed_band():
    for angle_deg in (20.0, 45.0, 70.0):
        end = (100.0 * np.cos(np.radians(angle_deg)),
               100.0 * np.sin(np.radians(angle_deg)))
        result = calibrate_one_line([(0.0, 0.0), end], 10.0)
        assert result.pixels_per_cm == pytest.approx(10.0)


def test_one_line_angle_is_measured_regardless_of_drag_direction():
    # Dragging up-left is the same line as dragging down-right.
    down_right = calibrate_one_line([(0.0, 0.0), (30.0, 40.0)], 10.0)
    up_left = calibrate_one_line([(30.0, 40.0), (0.0, 0.0)], 10.0)
    assert down_right.pixels_per_cm == pytest.approx(up_left.pixels_per_cm)


def test_a_line_of_no_length_is_an_error():
    with pytest.raises(SphynxValueError):
        calibrate_one_line([(7.0, 7.0), (7.0, 7.0)], 10.0)


# --- the dispatcher ------------------------------------------------------
def test_every_declared_mode_dispatches():
    assert MODES == ("1 line", "2 lines", "4 points")
    points = {
        "1 line": [(0.0, 0.0), (30.0, 40.0)],
        "2 lines": [(0.0, 0.0), (0.0, 100.0), (0.0, 0.0), (100.0, 0.0)],
        "4 points": [(0.0, 0.0), (0.0, 100.0), (0.0, 0.0), (100.0, 0.0)],
    }
    for mode in MODES:
        result = calibrate(mode, points[mode], 10.0, 10.0)
        assert isinstance(result, Calibration)
        assert result.mode == mode
        assert result.pixels_per_cm > 0


def test_an_unknown_mode_names_the_known_ones():
    with pytest.raises(SphynxValueError, match="1 line"):
        calibrate("eyeball", [(0.0, 0.0), (30.0, 40.0)], 10.0, 10.0)


def test_the_dispatcher_says_how_many_points_each_mode_wants():
    with pytest.raises(SphynxValueError, match="4 points"):
        calibrate("4 points", [(0.0, 0.0), (30.0, 40.0)], 10.0, 10.0)
