"""The preset drawing canvas: shapes in, masks out (S4d)."""

import numpy as np
import pytest

from sphynx_gui.preset_canvas import PresetCanvas, Shape


def _canvas(qtbot, height=60, width=80):
    canvas = PresetCanvas()
    qtbot.addWidget(canvas)
    canvas.show_frame(np.zeros((height, width, 3), dtype=np.uint8))
    return canvas


# --- the frame -------------------------------------------------------------

def test_a_frame_is_displayed(qtbot):
    canvas = _canvas(qtbot)
    assert canvas.frame_shape == (60, 80)


def test_without_a_frame_there_is_no_shape(qtbot):
    canvas = PresetCanvas()
    qtbot.addWidget(canvas)
    assert canvas.frame_shape is None
    assert canvas.shapes == []


# --- shapes ----------------------------------------------------------------

def test_a_rectangle_fills_its_area(qtbot):
    canvas = _canvas(qtbot)
    canvas.add_shape("arena", "rectangle", [(10, 10), (30, 25)])
    mask = canvas.mask_for(canvas.shapes[0], 60, 80)
    # 10..30 inclusive by 10..25 inclusive
    assert mask.sum() == 21 * 16
    assert mask[10, 10] and mask[25, 30]
    assert not mask[9, 10] and not mask[10, 9]


def test_an_ellipse_is_smaller_than_its_box(qtbot):
    canvas = _canvas(qtbot)
    canvas.add_shape("o1", "ellipse", [(10, 10), (40, 40)])
    ellipse = canvas.mask_for(canvas.shapes[0], 60, 80)
    canvas.add_shape("box", "rectangle", [(10, 10), (40, 40)])
    box = canvas.mask_for(canvas.shapes[1], 60, 80)
    assert 0 < ellipse.sum() < box.sum()
    # every ellipse pixel is inside the bounding box
    assert not (ellipse & ~box).any()


def test_a_polygon_follows_its_vertices(qtbot):
    canvas = _canvas(qtbot)
    canvas.add_shape("tri", "polygon", [(5, 5), (45, 5), (5, 45)])
    mask = canvas.mask_for(canvas.shapes[0], 60, 80)
    assert mask[6, 6]                    # just inside the right angle
    assert not mask[40, 40]              # beyond the hypotenuse
    assert mask.sum() < 41 * 41          # a triangle, not its box


def test_adding_a_shape_emits(qtbot):
    canvas = _canvas(qtbot)
    with qtbot.waitSignal(canvas.shape_drawn, timeout=1000) as blocker:
        canvas.add_shape("arena", "rectangle", [(1, 1), (5, 5)])
    assert blocker.args == ["arena"]


def test_removing_a_shape_drops_it(qtbot):
    canvas = _canvas(qtbot)
    canvas.add_shape("a", "rectangle", [(1, 1), (5, 5)])
    canvas.add_shape("b", "rectangle", [(6, 6), (9, 9)])
    canvas.remove_shape("a")
    assert [s.name for s in canvas.shapes] == ["b"]


def test_a_repeated_name_replaces_rather_than_duplicates(qtbot):
    canvas = _canvas(qtbot)
    canvas.add_shape("a", "rectangle", [(1, 1), (5, 5)])
    canvas.add_shape("a", "rectangle", [(6, 6), (9, 9)])
    assert len(canvas.shapes) == 1
    assert canvas.shapes[0].points[0] == (6, 6)


def test_an_unknown_kind_is_refused(qtbot):
    canvas = _canvas(qtbot)
    with pytest.raises(Exception):
        canvas.add_shape("a", "hexagon", [(1, 1), (5, 5)])


# --- masks are clipped, not fatal ------------------------------------------

def test_a_shape_off_the_frame_is_clipped(qtbot):
    canvas = _canvas(qtbot)
    canvas.add_shape("wide", "rectangle", [(-20, -20), (200, 200)])
    mask = canvas.mask_for(canvas.shapes[0], 60, 80)
    assert mask.shape == (60, 80)
    assert mask.all()


def test_a_shape_entirely_off_the_frame_is_empty_not_an_error(qtbot):
    canvas = _canvas(qtbot)
    canvas.add_shape("gone", "rectangle", [(200, 200), (250, 250)])
    mask = canvas.mask_for(canvas.shapes[0], 60, 80)
    assert not mask.any()


# --- the tool selection ----------------------------------------------------

def test_the_tool_can_be_switched(qtbot):
    canvas = _canvas(qtbot)
    for kind in ("rectangle", "ellipse", "polygon"):
        canvas.set_tool(kind)
        assert canvas.tool == kind


def test_an_unknown_tool_is_refused(qtbot):
    canvas = _canvas(qtbot)
    with pytest.raises(Exception):
        canvas.set_tool("lasso")


def test_the_shape_record_carries_its_kind(qtbot):
    canvas = _canvas(qtbot)
    canvas.add_shape("a", "ellipse", [(1, 1), (5, 5)])
    shape = canvas.shapes[0]
    assert isinstance(shape, Shape)
    assert shape.kind == "ellipse"
