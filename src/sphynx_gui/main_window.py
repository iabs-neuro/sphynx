"""The application window: seven tabs sharing one AppState (S4a; Project S4f)."""

from __future__ import annotations

from PySide6.QtWidgets import QMainWindow, QTabWidget

from sphynx_gui.acts_tab import ActsTab
from sphynx_gui.analyze_tab import AnalyzeTab
from sphynx_gui.batch_tab import BatchTab
from sphynx_gui.output_tab import OutputTab
from sphynx_gui.placeholder_tab import PlaceholderTab
from sphynx_gui.preset_tab import PresetTab
from sphynx_gui.project_tab import ProjectTab
from sphynx_gui.state import AppState

# Left to right is the order the data travels: set the project up, mark the
# arena, clean the tracking, define what counts as an act, try one session,
# run them all, export.
TAB_TITLES = (
    "Project", "Create Preset", "Preprocess Tracking", "Define Acts",
    "Analyze Session", "Batch Analysis", "Make Output",
)

_PLACEHOLDERS = {
    "Preprocess Tracking": ("S4e", "Per-body-part cleaning, interpolation and smoothing."),
}


class MainWindow(QMainWindow):
    def __init__(self, state: AppState | None = None, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Sphynx")
        self.state = state if state is not None else AppState()

        self.tabs = QTabWidget()
        self.project_tab = ProjectTab(self.state)
        self.analyze_tab = AnalyzeTab(self.state)
        self.acts_tab = ActsTab(self.state)
        self.batch_tab = BatchTab(self.state)
        self.output_tab = OutputTab(self.state)
        self.preset_tab = PresetTab(self.state)

        by_title = {
            "Project": self.project_tab,
            "Create Preset": self.preset_tab,
            "Define Acts": self.acts_tab,
            "Analyze Session": self.analyze_tab,
            "Batch Analysis": self.batch_tab,
            "Make Output": self.output_tab,
        }
        for title in TAB_TITLES:
            if title in by_title:
                self.tabs.addTab(by_title[title], title)
            else:
                slice_name, detail = _PLACEHOLDERS[title]
                self.tabs.addTab(PlaceholderTab(title, slice_name, detail), title)

        self.tabs.setCurrentIndex(self.tabs.indexOf(self.project_tab))
        self.setCentralWidget(self.tabs)
        self.resize(1280, 860)
        self.state.project_dirty_changed.connect(self._show_title)
        self.state.project_changed.connect(self._show_title)
        self._show_title()

    def _show_title(self) -> None:
        """Unsaved project changes belong in the title bar: the Project tab is
        not on screen while the user works in the others."""
        name = self.state.project.name or "no project"
        mark = " *" if self.state.project_dirty else ""
        self.setWindowTitle(f"Sphynx - {name}{mark}")

    def closeEvent(self, event):        # noqa: N802 - Qt naming
        """Let a running analysis finish before the window is destroyed.

        Qt aborts the whole process if a QThread is still running when it is
        destroyed, so closing mid-analysis would look like a crash."""
        self.analyze_tab.controller.shutdown()
        self.batch_tab.controller.shutdown()
        super().closeEvent(event)
