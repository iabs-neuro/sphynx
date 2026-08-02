"""Create Preset tab: video, calibration, zones, validation, save (S4d)."""

from pathlib import Path

import numpy as np
import pytest

from sphynx.io.preset import read_preset
from sphynx_gui.preset_tab import PresetTab
from sphynx_gui.state import AppState

VIDEO = Path("Demo/Video/NOF_H01_1D.mp4")


def _tab(qtbot, paradigm="EOF"):
    state = AppState()
    state.paradigm = paradigm
    tab = PresetTab(state)
    qtbot.addWidget(tab)
    # A frame stands in for a video everywhere the video itself is not the
    # thing under test.
    tab.controller.use_frame(np.zeros((120, 160, 3), dtype=np.uint8))
    return tab


def _draw_arena_and_objects(tab):
    tab.canvas.add_shape("arena", "rectangle", [(10, 10), (150, 110)])
    tab.set_shape_role("arena", "arena", False)
    tab.canvas.add_shape("object1", "ellipse", [(40, 40), (60, 60)])
    tab.set_shape_role("object1", "object", False)
    tab.canvas.add_shape("object2", "ellipse", [(100, 40), (120, 60)])
    tab.set_shape_role("object2", "object", False)
    tab.pixels_per_cm_box.setValue(4.0)


# --- opening a video -------------------------------------------------------

def test_a_missing_video_is_reported_not_raised(qtbot):
    tab = _tab(qtbot)
    tab.controller.open_video("no/such/file.mp4")
    assert "not found" in tab.status_label.text().lower()


@pytest.mark.skipif(not VIDEO.is_file(), reason="demo video absent")
def test_the_frame_spin_is_bounded_by_the_video(qtbot):
    tab = _tab(qtbot)
    tab.controller.open_video(VIDEO)
    assert tab.frame_spin.maximum() > 0
    assert tab.canvas.frame_shape is not None


@pytest.mark.skipif(not VIDEO.is_file(), reason="demo video absent")
def test_a_frame_past_the_end_is_reported(qtbot):
    tab = _tab(qtbot)
    tab.controller.open_video(VIDEO)
    tab.controller.show_frame(10_000_000)
    assert "frame" in tab.status_label.text().lower()


# --- calibration -----------------------------------------------------------

def _calibrate(tab, mode, points, distance_y=10.0, distance_x=10.0):
    """Drive the Choose -> click -> Compute flow the way the buttons do."""
    tab.calib_mode_box.setCurrentText(mode)
    tab.distance_y_box.setValue(distance_y)
    tab.distance_x_box.setValue(distance_x)
    tab.controller.begin_calibration()
    for x, y in points:
        tab.canvas.add_point(x, y)
    tab.controller.compute_calibration()


def test_choose_arms_the_canvas_for_as_many_points_as_the_mode_needs(qtbot):
    tab = _tab(qtbot)
    for mode, wanted in (("1 line", 2), ("2 lines", 4), ("4 points", 4)):
        tab.calib_mode_box.setCurrentText(mode)
        tab.controller.begin_calibration()
        for index in range(wanted):
            assert tab.controller.calib_points == []
            tab.canvas.add_point(10.0 + index, 20.0 + index)
        assert len(tab.controller.calib_points) == wanted


def test_one_line_calibration_fills_the_box_and_leaves_kcorr_at_one(qtbot):
    tab = _tab(qtbot)
    _calibrate(tab, "1 line", [(0.0, 0.0), (30.0, 40.0)], distance_y=10.0)
    assert tab.pixels_per_cm_box.value() == pytest.approx(5.0)
    assert tab.controller.x_kcorr() == pytest.approx(1.0)


def test_four_point_calibration_measures_the_anisotropy(qtbot):
    tab = _tab(qtbot)
    # 100 px per 10 cm down, 200 px per 10 cm across: a pixel twice as wide
    # as it is tall.
    _calibrate(tab, "4 points",
               [(0.0, 0.0), (0.0, 100.0), (0.0, 0.0), (200.0, 0.0)])
    assert tab.pixels_per_cm_box.value() == pytest.approx(10.0)
    assert tab.controller.x_kcorr() == pytest.approx(0.5)
    assert "kcorr: 0.500" in tab.calib_label.text()


def test_two_line_calibration_agrees_with_the_same_points_clicked(qtbot):
    tab = _tab(qtbot)
    points = [(0.0, 0.0), (0.0, 100.0), (0.0, 0.0), (200.0, 0.0)]
    _calibrate(tab, "2 lines", points)
    from_lines = tab.controller.calibration
    _calibrate(tab, "4 points", points)
    assert from_lines.pixels_per_cm == pytest.approx(
        tab.controller.calibration.pixels_per_cm)
    assert from_lines.x_kcorr == pytest.approx(
        tab.controller.calibration.x_kcorr)


def test_a_near_axis_single_line_is_refused_with_the_angle_named(qtbot):
    tab = _tab(qtbot)
    _calibrate(tab, "1 line", [(0.0, 0.0), (100.0, 5.0)])
    assert "deg" in tab.status_label.text().lower()
    assert tab.pixels_per_cm_box.value() == 0.0
    assert tab.controller.calibration is None


def test_computing_before_picking_any_point_is_reported(qtbot):
    tab = _tab(qtbot)
    tab.controller.compute_calibration()
    assert "choose" in tab.status_label.text().lower()


def test_a_refused_measurement_clears_the_points_so_it_is_not_half_reused(qtbot):
    tab = _tab(qtbot)
    _calibrate(tab, "1 line", [(0.0, 0.0), (100.0, 5.0)])
    assert tab.controller.calib_points == []
    assert tab.canvas.points == []


def test_the_x_distance_is_disabled_for_the_single_line_mode(qtbot):
    tab = _tab(qtbot)
    tab.calib_mode_box.setCurrentText("1 line")
    assert not tab.distance_x_box.isEnabled()
    tab.calib_mode_box.setCurrentText("4 points")
    assert tab.distance_x_box.isEnabled()


def test_typing_a_pixels_per_cm_by_hand_drops_the_measured_anisotropy(qtbot):
    # The kcorr belongs to the measurement it came from. Kept beside a
    # hand-typed scale it would stretch every zone against a measurement
    # that was never made.
    tab = _tab(qtbot)
    _calibrate(tab, "4 points",
               [(0.0, 0.0), (0.0, 100.0), (0.0, 0.0), (200.0, 0.0)])
    assert tab.controller.x_kcorr() == pytest.approx(0.5)
    tab.pixels_per_cm_box.setValue(7.0)
    assert tab.controller.x_kcorr() == pytest.approx(1.0)
    assert tab.controller.options()["x_kcorr"] == pytest.approx(1.0)


def test_a_new_frame_drops_points_picked_on_the_old_one(qtbot):
    tab = _tab(qtbot)
    tab.controller.begin_calibration()
    tab.canvas.add_point(10.0, 10.0)
    tab.controller.use_frame(np.zeros((120, 160, 3), dtype=np.uint8))
    assert tab.canvas.points == []


# --- building the zones ----------------------------------------------------

def test_building_without_an_arena_is_reported(qtbot):
    tab = _tab(qtbot)
    tab.canvas.add_shape("object1", "ellipse", [(40, 40), (60, 60)])
    tab.set_shape_role("object1", "object", False)
    tab.pixels_per_cm_box.setValue(4.0)
    tab.controller.build_zones()
    assert "arena" in tab.status_label.text().lower()
    assert tab.controller.zones == []


def test_building_without_calibration_is_reported(qtbot):
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.pixels_per_cm_box.setValue(0.0)
    tab.controller.build_zones()
    assert "calibrat" in tab.status_label.text().lower()
    assert tab.controller.zones == []


def test_an_arena_and_two_objects_give_the_trio(qtbot):
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.controller.build_zones()
    classes = [z.zone_class for z in tab.controller.zones]
    assert classes.count("object") == 2
    assert classes.count("object_ring") == 2
    assert classes.count("object_area") == 2
    assert "arena" in classes


def test_the_ring_width_defaults_to_two_and_a_half(qtbot):
    tab = _tab(qtbot)
    assert tab.ring_width_box.value() == pytest.approx(2.5)


def test_a_wider_ring_gives_a_bigger_area(qtbot):
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.controller.build_zones()
    narrow = sum(int(z.maskfilled.sum()) for z in tab.controller.zones
                 if z.zone_class == "object_area")
    tab.ring_width_box.setValue(5.0)
    tab.controller.build_zones()
    wide = sum(int(z.maskfilled.sum()) for z in tab.controller.zones
               if z.zone_class == "object_area")
    assert wide > narrow


def test_the_arena_gives_walls_corners_and_a_centre(qtbot):
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.controller.build_zones()
    classes = {z.zone_class for z in tab.controller.zones}
    assert {"wall", "corner", "center"} <= classes


def test_a_target_object_carries_the_flag(qtbot):
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.set_shape_role("object1", "object", True)
    tab.controller.build_zones()
    flagged = [z.name for z in tab.controller.zones if z.roles.is_target]
    assert any(name.startswith("object1") for name in flagged)
    assert not any(name.startswith("object2") for name in flagged)


def test_holes_are_built_as_holes(qtbot):
    tab = _tab(qtbot, paradigm="Barnes")
    tab.canvas.add_shape("arena", "rectangle", [(10, 10), (150, 110)])
    tab.set_shape_role("arena", "arena", False)
    tab.canvas.add_shape("hole1", "ellipse", [(40, 40), (50, 50)])
    tab.set_shape_role("hole1", "hole", True)
    tab.pixels_per_cm_box.setValue(4.0)
    tab.controller.build_zones()
    classes = {z.zone_class for z in tab.controller.zones}
    assert {"hole", "hole_ring", "hole_area"} <= classes


# --- validation ------------------------------------------------------------

def test_the_warnings_panel_answers_the_chosen_paradigm(qtbot):
    tab = _tab(qtbot, paradigm="NOR")
    tab.canvas.add_shape("arena", "rectangle", [(10, 10), (150, 110)])
    tab.set_shape_role("arena", "arena", False)
    tab.canvas.add_shape("object1", "ellipse", [(40, 40), (60, 60)])
    tab.set_shape_role("object1", "object", False)
    tab.pixels_per_cm_box.setValue(4.0)
    tab.controller.build_zones()
    tab.controller.validate()
    text = " ".join(str(r) for r in tab.warnings.rows).lower()
    assert "object" in text          # NOR wants two, one was drawn


def test_validating_before_building_is_reported(qtbot):
    tab = _tab(qtbot)
    tab.controller.validate()
    assert "build" in tab.status_label.text().lower()


def test_a_complete_eof_preset_validates_clean(qtbot):
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.controller.build_zones()
    tab.controller.validate()
    errors = [r for r in tab.warnings.rows if r[1] == "error"]
    assert errors == []


# --- saving ----------------------------------------------------------------

def test_saving_before_building_is_reported(qtbot, tmp_path):
    tab = _tab(qtbot)
    tab.controller.save(tmp_path / "p.mat")
    assert "build" in tab.status_label.text().lower()
    assert not (tmp_path / "p.mat").exists()


def test_a_saved_preset_is_read_back_by_the_engine(qtbot, tmp_path):
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.controller.build_zones()
    target = tmp_path / "built.mat"
    tab.controller.save(target)
    assert target.is_file()

    preset = read_preset(target)
    names = [str(z.name) for z in np.atleast_1d(preset.zones)]
    assert "object1_real" in names and "object1_realout" in names
    classes = [str(z.zone_class) for z in np.atleast_1d(preset.zones)]
    assert classes.count("object_area") == 2


def test_the_saved_options_carry_the_calibration(qtbot, tmp_path):
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.controller.build_zones()
    target = tmp_path / "built.mat"
    tab.controller.save(target)
    preset = read_preset(target)
    assert float(preset.options.pxl2sm) == pytest.approx(4.0)
    assert int(preset.options.Width) == 160
    assert int(preset.options.Height) == 120


def test_a_measured_anisotropy_reaches_the_saved_options(qtbot, tmp_path):
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    # 40 px per 10 cm down, 80 px per 10 cm across.
    _calibrate(tab, "4 points",
               [(0.0, 0.0), (0.0, 40.0), (0.0, 0.0), (80.0, 0.0)])
    tab.controller.build_zones()
    target = tmp_path / "aniso.mat"
    tab.controller.save(target)
    preset = read_preset(target)
    assert float(preset.options.x_kcorr) == pytest.approx(0.5)
    assert float(preset.options.pxl2smY) == pytest.approx(4.0)
    assert float(preset.options.pxl2smX) == pytest.approx(8.0)
    assert str(preset.options.CalibrationMode) == "4 points"


def test_a_measured_anisotropy_changes_the_object_rings(qtbot):
    # The whole point of measuring kcorr: the ring must be the same number of
    # centimetres on both axes, which on a non-square pixel is a different
    # number of pixels on each.
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.controller.build_zones()
    square = {z.name: int(np.asarray(z.maskfilled).sum())
              for z in tab.controller.zones}

    _calibrate(tab, "4 points",
               [(0.0, 0.0), (0.0, 40.0), (0.0, 0.0), (80.0, 0.0)])
    tab.controller.build_zones()
    stretched = {z.name: int(np.asarray(z.maskfilled).sum())
                 for z in tab.controller.zones}

    assert tab.controller.x_kcorr() == pytest.approx(0.5)
    assert square["object1_out"] != stretched["object1_out"]


def test_saving_sets_the_preset_path_on_the_state(qtbot, tmp_path):
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.controller.build_zones()
    target = tmp_path / "built.mat"
    tab.controller.save(target)
    assert tab.state.preset_path == str(target)


# --- the shapes table ------------------------------------------------------

def test_the_table_lists_what_was_drawn(qtbot):
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    names = [tab.shapes_table.item(r, 0).text()
             for r in range(tab.shapes_table.rowCount())]
    assert names == ["arena", "object1", "object2"]


def test_removing_a_shape_updates_the_table(qtbot):
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.remove_selected_shape("object2")
    names = [tab.shapes_table.item(r, 0).text()
             for r in range(tab.shapes_table.rowCount())]
    assert names == ["arena", "object1"]


def test_a_removed_shape_leaves_no_zone(qtbot):
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.remove_selected_shape("object2")
    tab.controller.build_zones()
    classes = [z.zone_class for z in tab.controller.zones]
    assert classes.count("object") == 1


# --- S4d slice-review regressions -----------------------------------------

def test_recalibrating_without_rebuilding_refuses_to_save(qtbot, tmp_path):
    # C2: options were read at save time and masks at build time, so a
    # rebuild-free recalibration shipped a pxl2sm the masks were not built for
    # -- a ring labelled 2.5 cm that is physically half that.
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.controller.build_zones()
    tab.pixels_per_cm_box.setValue(8.0)
    tab.controller.save(tmp_path / "stale.mat")
    assert not (tmp_path / "stale.mat").exists()
    assert "rebuild" in tab.status_label.text().lower()


def test_the_saved_options_are_the_ones_the_masks_were_built_for(qtbot, tmp_path):
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.controller.build_zones()
    target = tmp_path / "ok.mat"
    tab.controller.save(target)
    preset = read_preset(target)
    assert float(preset.options.pxl2sm) == pytest.approx(4.0)


def test_a_new_frame_of_another_size_drops_the_shapes(qtbot):
    # I3: shapes survived in old pixel coordinates, so an arena covering most
    # of a small frame became a corner patch on a larger one, silently.
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.controller.use_frame(np.zeros((240, 320, 3), dtype=np.uint8))
    assert tab.canvas.shapes == []
    assert "size" in tab.status_label.text().lower()


def test_a_new_frame_of_the_same_size_keeps_the_shapes(qtbot):
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.controller.use_frame(np.zeros((120, 160, 3), dtype=np.uint8))
    assert [s.name for s in tab.canvas.shapes] == ["arena", "object1", "object2"]


def test_saving_without_a_frame_rate_is_refused(qtbot, tmp_path):
    # I4: an unreadable FPS silently wrote FrameRate = 30.0.
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.frame_rate_box.setValue(0.0)
    tab.controller.build_zones()
    tab.controller.save(tmp_path / "nofps.mat")
    assert not (tmp_path / "nofps.mat").exists()
    assert "frame rate" in tab.status_label.text().lower()


def test_the_wall_width_is_one_number_for_both_arena_shapes(qtbot):
    # I6: 3 cm for a rectangle and 10 cm for an ellipse, hardcoded, so the same
    # arena gave a 19.5% or a 57.5% border band depending on the drawing tool.
    tab = _tab(qtbot)
    assert tab.wall_width_box.value() == pytest.approx(3.0)


def test_a_wider_wall_gives_a_wider_band(qtbot):
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.controller.build_zones()
    narrow = sum(int(z.maskfilled.sum()) for z in tab.controller.zones
                 if z.zone_class in ("wall", "corner"))
    tab.wall_width_box.setValue(6.0)
    tab.controller.build_zones()
    wide = sum(int(z.maskfilled.sum()) for z in tab.controller.zones
               if z.zone_class in ("wall", "corner"))
    assert wide > narrow


def test_the_wall_width_reaches_the_saved_options(qtbot, tmp_path):
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.wall_width_box.setValue(4.0)
    tab.controller.build_zones()
    target = tmp_path / "w.mat"
    tab.controller.save(target)
    assert float(read_preset(target).options.WallWidthCm) == pytest.approx(4.0)


def test_a_shape_marked_wall_becomes_a_wall_zone(qtbot):
    # I7: roles offered in the UI were silently dropped -- no zone, no note.
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.canvas.add_shape("nest", "rectangle", [(15, 90), (35, 105)])
    tab.set_shape_role("nest", "corner", False)
    tab.controller.build_zones()
    named = [z for z in tab.controller.zones if z.name == "nest"]
    assert len(named) == 1
    assert named[0].zone_class == "corner"


def _polygon_arena(tab):
    tab.canvas.add_shape("arena", "polygon",
                         [(20, 20), (140, 20), (140, 100), (20, 100)])
    tab.set_shape_role("arena", "arena", False)
    tab.pixels_per_cm_box.setValue(4.0)


def test_a_polygon_arena_under_auto_derives_nothing_and_says_why(qtbot):
    # I8: every polygon vertex was fed to classify_square as a corner seed, so
    # a 12-gon turned half its border band into "corner". Auto now resolves a
    # polygon to nothing and points at the strategy that would work.
    tab = _tab(qtbot)
    _polygon_arena(tab)
    tab.controller.build_zones()
    text = " ".join(str(r) for r in tab.warnings.rows).lower()
    assert "circle" in text
    assert "corner" not in {z.zone_class for z in tab.controller.zones}


def test_an_object_drawn_off_the_frame_is_reported(qtbot):
    # C1 (engine) seen from the tab: an empty mask must not become a zone.
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.canvas.add_shape("object3", "rectangle", [(400, 400), (450, 450)])
    tab.set_shape_role("object3", "object", False)
    tab.controller.build_zones()
    assert tab.controller.zones == []
    assert "object3" in tab.status_label.text()


def test_a_barnes_preset_with_one_target_validates_clean(qtbot):
    # I5 seen from the tab: one target hole yields three target zones, and the
    # "exactly one target" rule used to count all three.
    tab = _tab(qtbot, paradigm="Barnes")
    tab.canvas.add_shape("arena", "rectangle", [(10, 10), (150, 110)])
    tab.set_shape_role("arena", "arena", False)
    for index, (x, y) in enumerate([(40, 40), (100, 40), (70, 90)], start=1):
        tab.canvas.add_shape(f"hole{index}", "ellipse",
                             [(x, y), (x + 10, y + 10)])
        tab.set_shape_role(f"hole{index}", "hole", index == 1)
    tab.pixels_per_cm_box.setValue(4.0)
    tab.controller.build_zones()
    tab.controller.validate()
    errors = [r for r in tab.warnings.rows if r[1] == "error"]
    assert errors == [], errors


# --- zone strategies (S4g) -------------------------------------------------

def _classes(tab):
    counts = {}
    for zone in tab.controller.zones:
        counts[zone.zone_class] = counts.get(zone.zone_class, 0) + 1
    return counts


def test_auto_resolves_the_way_this_tab_always_behaved(qtbot):
    # No silent change for anyone who never touches the new box.
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    assert tab.controller.strategy() == "corners-walls-center"

    other = _tab(qtbot)
    other.canvas.add_shape("arena", "ellipse", [(10, 10), (150, 110)])
    other.set_shape_role("arena", "arena", False)
    assert other.controller.strategy() == "circle-rings"


def test_the_circle_strategy_gives_a_wall_and_a_centre(qtbot):
    # MATLAB's default strategy, which Python did not have at all: two zones,
    # not wall + middle1..N + centre.
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.strategy_box.setCurrentText("circle")
    tab.controller.build_zones()
    names = [z.name for z in tab.controller.zones]
    assert names.count("wall") == 1 and names.count("center") == 1
    assert not [n for n in names if n.startswith("middle")]


def test_circle_and_circle_rings_really_differ(qtbot):
    # The whole point of the finding: these are different sets of zones, so a
    # round arena was getting different numbers from MATLAB's default.
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.strategy_box.setCurrentText("circle")
    tab.controller.build_zones()
    plain = _classes(tab)

    tab.strategy_box.setCurrentText("circle-rings")
    tab.middle_width_box.setValue(3.0)
    tab.controller.build_zones()
    assert _classes(tab).get("middle", 0) > 0
    assert plain.get("middle", 0) == 0


def test_the_centre_strategy_builds_a_disc_of_the_stated_size(qtbot):
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.strategy_box.setCurrentText("circle-with-center")
    tab.center_diameter_box.setValue(10.0)
    tab.controller.build_zones()
    small = {z.name: np.asarray(z.maskfilled).sum()
             for z in tab.controller.zones}
    tab.center_diameter_box.setValue(20.0)
    tab.controller.build_zones()
    large = {z.name: np.asarray(z.maskfilled).sum()
             for z in tab.controller.zones}
    assert large["center"] > small["center"]


def test_a_polygon_arena_gets_zones_once_a_strategy_is_chosen(qtbot):
    # The distance-transform strategies are shape-agnostic, so choosing one
    # is what finally gives a polygon arena its wall and centre.
    tab = _tab(qtbot)
    _polygon_arena(tab)
    tab.strategy_box.setCurrentText("circle")
    tab.controller.build_zones()
    names = [z.name for z in tab.controller.zones]
    assert "wall" in names and "center" in names


def test_corners_on_a_polygon_is_refused_with_advice(qtbot):
    tab = _tab(qtbot)
    _polygon_arena(tab)
    tab.strategy_box.setCurrentText("corners-walls-center")
    tab.controller.build_zones()
    text = " ".join(str(r) for r in tab.warnings.rows).lower()
    assert "rectangular" in text
    assert "corner" not in {z.zone_class for z in tab.controller.zones}


def test_the_strips_strategy_builds_the_number_asked_for(qtbot):
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.strategy_box.setCurrentText("strips")
    tab.strips_box.setValue(4)
    tab.controller.build_zones()
    assert _classes(tab).get("strip", 0) == 4


def test_the_none_strategy_derives_nothing_and_warns_about_nothing(qtbot):
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.strategy_box.setCurrentText("none")
    tab.controller.build_zones()
    assert _classes(tab).get("wall", 0) == 0
    assert _classes(tab).get("center", 0) == 0
    # The objects are still built: 'none' is about the arena, not the preset.
    assert _classes(tab).get("object_area", 0) == 2
    geometry = [r for r in tab.warnings.rows if r[0] == "geometry"]
    assert geometry == []


def test_only_the_fields_a_strategy_reads_stay_live(qtbot):
    tab = _tab(qtbot)
    tab.strategy_box.setCurrentText("circle")
    assert tab.wall_width_box.isEnabled()
    assert not tab.center_diameter_box.isEnabled()
    assert not tab.strips_box.isEnabled()

    tab.strategy_box.setCurrentText("circle-with-center")
    assert tab.center_diameter_box.isEnabled()
    assert not tab.middle_width_box.isEnabled()

    tab.strategy_box.setCurrentText("strips")
    assert tab.strips_box.isEnabled() and tab.strip_direction_box.isEnabled()
    assert not tab.wall_width_box.isEnabled()


def test_the_saved_options_name_the_resolved_strategy_not_auto(qtbot, tmp_path):
    # A preset read back a year later should say which zones it holds.
    tab = _tab(qtbot)
    _draw_arena_and_objects(tab)
    tab.controller.build_zones()
    target = tmp_path / "auto.mat"
    tab.controller.save(target)
    assert str(read_preset(target).options.ZoneStrategy) == "corners-walls-center"
