from sphynx_gui.main_window import MainWindow
from sphynx_gui.placeholder_tab import PlaceholderTab
from sphynx_gui.state import AppState


def test_seven_tabs_in_workflow_order(qtbot):
    # Left to right is the order the data travels.
    window = MainWindow()
    qtbot.addWidget(window)
    titles = [window.tabs.tabText(i) for i in range(window.tabs.count())]
    assert titles == [
        "Project", "Create Preset", "Preprocess Tracking", "Define Acts",
        "Analyze Session", "Batch Analysis", "Make Output",
    ]


def test_four_tabs_are_placeholders_naming_their_slice(qtbot):
    window = MainWindow()
    qtbot.addWidget(window)
    placeholders = [window.tabs.widget(i) for i in range(window.tabs.count())
                    if isinstance(window.tabs.widget(i), PlaceholderTab)]
    assert len(placeholders) == 1
    for tab in placeholders:
        assert tab.slice_name.startswith("S4")


def test_the_project_tab_is_the_one_that_opens(qtbot):
    # Nothing else can be done well until a project is open, so that is where
    # the window starts.
    window = MainWindow()
    qtbot.addWidget(window)
    assert window.tabs.currentIndex() == window.tabs.indexOf(window.project_tab)


def test_analyze_tab_is_live(qtbot):
    window = MainWindow()
    qtbot.addWidget(window)
    assert window.tabs.indexOf(window.analyze_tab) >= 0
    assert not isinstance(window.analyze_tab, PlaceholderTab)


def test_state_is_shared_with_the_analyze_tab(qtbot):
    state = AppState()
    window = MainWindow(state=state)
    qtbot.addWidget(window)
    assert window.state is state
    assert window.analyze_tab.state is state


def test_window_has_a_title(qtbot):
    window = MainWindow()
    qtbot.addWidget(window)
    assert "Sphynx" in window.windowTitle()


def test_define_acts_tab_is_live(qtbot):
    from sphynx_gui.acts_tab import ActsTab

    window = MainWindow()
    qtbot.addWidget(window)
    assert isinstance(window.acts_tab, ActsTab)
    assert window.acts_tab.state is window.state


def test_four_tabs_remain_placeholders(qtbot):
    window = MainWindow()
    qtbot.addWidget(window)
    placeholders = [window.tabs.widget(i) for i in range(window.tabs.count())
                    if isinstance(window.tabs.widget(i), PlaceholderTab)]
    assert len(placeholders) == 1


def test_batch_tab_is_live(qtbot):
    from sphynx_gui.batch_tab import BatchTab

    window = MainWindow()
    qtbot.addWidget(window)
    assert isinstance(window.batch_tab, BatchTab)
    assert window.batch_tab.state is window.state


def test_output_tab_is_live(qtbot):
    from sphynx_gui.output_tab import OutputTab

    window = MainWindow()
    qtbot.addWidget(window)
    assert isinstance(window.output_tab, OutputTab)
    assert window.output_tab.state is window.state


def test_create_preset_tab_is_live(qtbot):
    from sphynx_gui.preset_tab import PresetTab

    window = MainWindow()
    qtbot.addWidget(window)
    assert isinstance(window.preset_tab, PresetTab)
    assert window.preset_tab.state is window.state
    assert window.tabs.indexOf(window.preset_tab) == 1


def test_only_preprocess_is_still_a_placeholder(qtbot):
    window = MainWindow()
    qtbot.addWidget(window)
    left = [window.tabs.tabText(i) for i in range(window.tabs.count())
            if isinstance(window.tabs.widget(i), PlaceholderTab)]
    assert left == ["Preprocess Tracking"]


# --- the project drives the tabs (S4f) -------------------------------------

def test_the_project_tab_is_live(qtbot):
    from sphynx_gui.project_tab import ProjectTab

    window = MainWindow()
    qtbot.addWidget(window)
    assert isinstance(window.project_tab, ProjectTab)
    assert window.project_tab.state is window.state
    assert window.tabs.indexOf(window.project_tab) == 0


def test_unsaved_project_changes_show_in_the_title(qtbot):
    # The Project tab is not on screen while the user works in the others.
    window = MainWindow()
    qtbot.addWidget(window)
    assert "*" not in window.windowTitle()
    window.state.paradigm = "EOF"
    assert "*" in window.windowTitle()


def test_the_title_names_the_open_project(qtbot, tmp_path):
    window = MainWindow()
    qtbot.addWidget(window)
    window.project_tab.controller.new_project(tmp_path / "Barnes2026")
    assert "Barnes2026" in window.windowTitle()


def test_the_batch_tab_no_longer_owns_the_project(qtbot):
    window = MainWindow()
    qtbot.addWidget(window)
    for gone in ("new_project_button", "open_button", "save_button"):
        assert not hasattr(window.batch_tab, gone), gone


def test_opening_a_project_points_a_single_run_at_temp(qtbot, tmp_path):
    from pathlib import Path

    window = MainWindow()
    qtbot.addWidget(window)
    window.project_tab.controller.new_project(tmp_path / "p")
    assert window.state.out_dir == str(Path(tmp_path) / "p" / "temp")


def test_without_a_project_the_single_run_folder_is_not_invented(qtbot):
    window = MainWindow()
    qtbot.addWidget(window)
    assert window.analyze_tab.default_out_dir() == ""
