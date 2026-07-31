from sphynx_gui.main_window import MainWindow
from sphynx_gui.placeholder_tab import PlaceholderTab
from sphynx_gui.state import AppState


def test_six_tabs_in_workflow_order(qtbot):
    window = MainWindow()
    qtbot.addWidget(window)
    titles = [window.tabs.tabText(i) for i in range(window.tabs.count())]
    assert titles == [
        "Create Preset", "Preprocess Tracking", "Define Acts",
        "Analyze Session", "Batch Analysis", "Make Output",
    ]


def test_five_tabs_are_placeholders_naming_their_slice(qtbot):
    window = MainWindow()
    qtbot.addWidget(window)
    placeholders = [window.tabs.widget(i) for i in range(window.tabs.count())
                    if isinstance(window.tabs.widget(i), PlaceholderTab)]
    assert len(placeholders) == 5
    for tab in placeholders:
        assert tab.slice_name.startswith("S4")


def test_analyze_tab_is_live_and_selected(qtbot):
    window = MainWindow()
    qtbot.addWidget(window)
    index = window.tabs.indexOf(window.analyze_tab)
    assert index >= 0
    assert not isinstance(window.analyze_tab, PlaceholderTab)
    assert window.tabs.currentIndex() == index


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
