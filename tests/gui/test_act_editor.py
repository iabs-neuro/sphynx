import numpy as np
import pytest

from sphynx.acts import Act
from sphynx.zones import Zone
from sphynx_gui.act_editor import ActEditor


def _zones():
    mask = np.zeros((4, 4), dtype=bool)
    return [Zone("Center", "area", mask, zone_class="center"),
            Zone("Object1RealOut", "area", mask, zone_class="object_area", index=1),
            Zone("Object2RealOut", "area", mask, zone_class="object_area", index=2)]


def _editor(qtbot):
    editor = ActEditor()
    qtbot.addWidget(editor)
    editor.set_zones(_zones())
    editor.set_body_parts(["nose", "bodycenter", "tailbase"])
    return editor


def test_zone_list_comes_from_the_preset(qtbot):
    editor = _editor(qtbot)
    editor.binding.setCurrentText("single zone")
    items = [editor.zone_box.itemText(i) for i in range(editor.zone_box.count())]
    assert "Center" in items and "Object1RealOut" in items


def test_class_list_is_the_distinct_zone_classes(qtbot):
    editor = _editor(qtbot)
    editor.binding.setCurrentText("zone class")
    items = [editor.zone_box.itemText(i) for i in range(editor.zone_box.count())]
    assert "object_area" in items
    assert items.count("object_area") == 1          # distinct, not per zone


def test_round_trip_of_a_simple_act(qtbot):
    editor = _editor(qtbot)
    act = Act(name="nose_in_centre", type="simple", body_part="nose",
              zones=["Center"], speed_min=1.0, speed_max=8.0,
              min_duration_sec=0.4, max_gap_sec=0.2, median_window_sec=0.3)
    editor.load_act(act)
    back = editor.to_act()
    assert back.name == "nose_in_centre"
    assert back.body_part == "nose"
    assert back.zones == ["Center"]
    assert back.speed_min == 1.0
    assert back.speed_max == 8.0
    assert back.min_duration_sec == 0.4
    assert back.max_gap_sec == 0.2
    assert back.median_window_sec == 0.3


def test_required_parts_follow_the_chosen_body_part(qtbot):
    # The fallback chain is not a user setting; required_parts is simply what
    # the user declared.
    editor = _editor(qtbot)
    editor.load_act(Act(name="a", type="simple", body_part="nose"))
    back = editor.to_act()
    assert back.required_parts == ["nose"]
    assert back.fallback == {}


def test_editor_exposes_no_fallback_control(qtbot):
    editor = _editor(qtbot)
    assert not hasattr(editor, "fallback_box")


def test_class_binding_produces_a_family_selector_name(qtbot):
    editor = _editor(qtbot)
    editor.binding.setCurrentText("zone class")
    editor.zone_box.setCurrentText("object_area")
    editor.name_box.setText("nose_at_object")
    assert editor.is_family() is True
    assert editor.family_zone_class() == "object_area"


def test_single_binding_is_not_a_family(qtbot):
    editor = _editor(qtbot)
    editor.binding.setCurrentText("single zone")
    assert editor.is_family() is False


def test_changing_a_field_emits_changed(qtbot):
    editor = _editor(qtbot)
    with qtbot.waitSignal(editor.changed, timeout=500):
        editor.name_box.setText("renamed")
