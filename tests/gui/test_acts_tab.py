"""Define Acts tab: list of acts from three sources, editor, preview (S4b)."""

import numpy as np
import pytest

from sphynx.acts import Act, ActFamily
from sphynx.acts.library_io import ActLibrary, save_library
from sphynx.bodyparts.identify import Point
from sphynx.paradigms import PARADIGMS, register_builtin_paradigms
from sphynx.pipeline.analyze import SessionAct
from sphynx.zones import Zone, ZoneSelector
from sphynx_gui.acts_tab import ActsTab
from sphynx_gui.state import AppState

N = 100
FPS = 10.0


@pytest.fixture(autouse=True)
def _builtins():
    saved = dict(PARADIGMS)
    PARADIGMS.clear()
    register_builtin_paradigms()
    yield
    PARADIGMS.clear()
    PARADIGMS.update(saved)


class _Options:
    FrameRate = FPS
    pxl2sm = 10.0
    Width = 100
    Height = 100


class _Trace:
    def __init__(self, name, x, y):
        self.name = name
        self.x_smooth = x
        self.y_smooth = y
        self.velocity = np.zeros(N)


def _zones():
    mask = np.zeros((100, 100), dtype=bool)
    mask[17:23, 17:23] = True
    other = np.zeros((100, 100), dtype=bool)
    other[17:23, 77:83] = True
    return [Zone("Object1RealOut", "area", mask, zone_class="object_area", index=1),
            Zone("Object2RealOut", "area", other, zone_class="object_area", index=2)]


class _Result:
    """A session where the animal sits in Object1RealOut for frames 10..29."""

    def __init__(self):
        x = np.full(N, 90.0)
        y = np.full(N, 90.0)
        x[10:30] = 20.0
        y[10:30] = 20.0
        self.body_parts_names = ["nose", "bodycenter"]
        self.body_parts_traces = [_Trace("nose", x, y), _Trace("bodycenter", x, y)]
        self.point = Point(nose=0, center=1)
        self.options = _Options()
        self.zones = _zones()
        self.n_frames = N
        self.acts = [SessionAct("rest", np.ones(N), "builtin")]
        self.config = None


def _tab(qtbot, with_session=True):
    state = AppState()
    state.paradigm = "EOF"
    if with_session:
        state.result = _Result()
    tab = ActsTab(state)
    qtbot.addWidget(tab)
    return tab


# --- the act list ----------------------------------------------------------

def test_list_shows_builtin_and_paradigm_acts(qtbot):
    tab = _tab(qtbot)
    sources = {name: source for name, source, _ in tab.controller.rows}
    assert sources.get("rest") == "builtin"
    assert sources.get("nose_at_object") == "paradigm"


def test_library_acts_are_listed_as_library(qtbot):
    tab = _tab(qtbot)
    tab.state.library = ActLibrary(acts=[Act(name="my_act", type="simple",
                                             body_part="nose")])
    tab.controller.refresh_list()
    sources = {name: source for name, source, _ in tab.controller.rows}
    assert sources["my_act"] == "library"


def test_same_name_library_act_marks_the_paradigm_row_overridden(qtbot):
    tab = _tab(qtbot)
    tab.state.library = ActLibrary(families=[ActFamily(
        name="nose_at_object", selector=ZoneSelector(zone_class="object_area"),
        template=Act(name="nose_at_object", type="simple", body_part="nose"))])
    tab.controller.refresh_list()
    row = next(r for r in tab.controller.rows if r[0] == "nose_at_object"
               and r[1] == "paradigm")
    assert row[2] == "library"


def test_list_widget_has_a_row_per_act(qtbot):
    tab = _tab(qtbot)
    assert tab.list_widget.count() == len(tab.controller.rows)


# --- editing ---------------------------------------------------------------

def test_add_act_puts_it_in_the_library(qtbot):
    tab = _tab(qtbot)
    tab.editor.name_box.setText("nose_here")
    tab.editor.body_part_box.setCurrentText("nose")
    tab.controller.add_act()
    assert [a.name for a in tab.state.library.acts] == ["nose_here"]


def test_added_act_carries_required_parts_from_the_body_part(qtbot):
    tab = _tab(qtbot)
    tab.editor.name_box.setText("nose_here")
    tab.editor.body_part_box.setCurrentText("nose")
    tab.controller.add_act()
    act = tab.state.library.acts[0]
    assert act.required_parts == ["nose"]
    assert act.fallback == {}


def test_adding_a_family_binding_creates_a_family(qtbot):
    tab = _tab(qtbot)
    tab.editor.name_box.setText("sniff_object")
    tab.editor.body_part_box.setCurrentText("nose")
    tab.editor.binding.setCurrentText("zone class")
    tab.editor.zone_box.setCurrentText("object_area")
    tab.controller.add_act()
    assert [f.name for f in tab.state.library.families] == ["sniff_object"]
    assert tab.state.library.families[0].selector.zone_class == "object_area"


def test_unnamed_act_is_refused_with_a_message(qtbot):
    tab = _tab(qtbot)
    tab.editor.name_box.setText("   ")
    tab.controller.add_act()
    assert tab.state.library.acts == []
    assert "name" in tab.status_label.text().lower()


def test_delete_removes_the_selected_library_act(qtbot):
    tab = _tab(qtbot)
    tab.state.library = ActLibrary(acts=[Act(name="doomed", type="simple",
                                             body_part="nose")])
    tab.controller.refresh_list()
    tab.controller.select("doomed")
    tab.controller.delete_selected()
    assert tab.state.library.acts == []


def test_deleting_a_paradigm_act_is_refused(qtbot):
    tab = _tab(qtbot)
    tab.controller.select("nose_at_object")
    tab.controller.delete_selected()
    assert "library" in tab.status_label.text().lower()


# --- preview ---------------------------------------------------------------

def test_preview_without_a_session_says_so(qtbot):
    tab = _tab(qtbot, with_session=False)
    tab.editor.name_box.setText("nose_here")
    tab.editor.body_part_box.setCurrentText("nose")
    tab.controller.preview()
    assert "session" in tab.preview_label.text().lower()


def test_preview_reports_episodes_and_the_frame_range(qtbot):
    tab = _tab(qtbot)
    tab.editor.name_box.setText("nose_in_object1")
    tab.editor.body_part_box.setCurrentText("nose")
    tab.editor.binding.setCurrentText("single zone")
    tab.editor.zone_box.setCurrentText("Object1RealOut")
    tab.controller.preview()
    text = tab.preview_label.text()
    assert "1 episode" in text or "episodes: 1" in text
    assert "100" in text                      # the frame count it ran over


def test_preview_draws_the_etogram(qtbot):
    tab = _tab(qtbot)
    tab.editor.name_box.setText("nose_in_object1")
    tab.editor.body_part_box.setCurrentText("nose")
    tab.editor.zone_box.setCurrentText("Object1RealOut")
    tab.controller.preview()
    assert tab.preview_canvas.figure.axes


# --- library files ---------------------------------------------------------

def test_save_and_load_round_trip(qtbot, tmp_path):
    tab = _tab(qtbot)
    tab.state.library = ActLibrary(acts=[Act(name="kept", type="simple",
                                             body_part="nose")])
    path = tmp_path / "acts.json"
    tab.controller.save_library(path)

    other = _tab(qtbot)
    other.controller.load_library(path)
    assert [a.name for a in other.state.library.acts] == ["kept"]


def test_loading_a_missing_file_reports_instead_of_raising(qtbot, tmp_path):
    tab = _tab(qtbot)
    tab.controller.load_library(tmp_path / "nope.json")
    assert "not found" in tab.status_label.text().lower()


# --- S4b review regressions ---

def test_act_without_a_body_part_is_refused(qtbot):
    # I5: before a session loads the combos are empty, and an act with no body
    # part and no zone used to be saved with a success message.
    tab = _tab(qtbot, with_session=False)
    tab.editor.name_box.setText("empty_act")
    tab.controller.add_act()
    assert tab.state.library.acts == []
    assert "body part" in tab.status_label.text().lower()


def test_selecting_a_paradigm_act_loads_it_into_the_editor(qtbot):
    # I6: the form used to keep showing the previous act, so Preview described
    # something other than the highlighted row.
    tab = _tab(qtbot)
    tab.controller.select("nose_at_object")
    assert tab.editor.name_box.text() == "nose_at_object"


def test_selecting_a_builtin_act_loads_it_too(qtbot):
    tab = _tab(qtbot)
    tab.controller.select("rest")
    assert tab.editor.name_box.text() == "rest"
