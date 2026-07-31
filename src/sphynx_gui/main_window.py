"""The application window: six tabs sharing one AppState (S4a)."""

from __future__ import annotations

from PySide6.QtWidgets import QMainWindow, QTabWidget

from sphynx_gui.analyze_tab import AnalyzeTab
from sphynx_gui.placeholder_tab import PlaceholderTab
from sphynx_gui.state import AppState

TAB_TITLES = (
    "Create Preset", "Preprocess Tracking", "Define Acts",
    "Analyze Session", "Batch Analysis", "Make Output",
)

_PLACEHOLDERS = {
    "Create Preset": ("S4d", "Draw zones, mark roles, calibrate, set the arena centre."),
    "Preprocess Tracking": ("S4e", "Per-body-part cleaning, interpolation and smoothing."),
    "Define Acts": ("S4b", "Two-panel act and metric constructor."),
    "Batch Analysis": ("S4c", "Run many sessions and aggregate them."),
    "Make Output": ("S4c", "Build the wide and tidy export tables."),
}


class MainWindow(QMainWindow):
    def __init__(self, state: AppState | None = None, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Sphynx")
        self.state = state if state is not None else AppState()

        self.tabs = QTabWidget()
        self.analyze_tab = AnalyzeTab(self.state)

        for title in TAB_TITLES:
            if title == "Analyze Session":
                self.tabs.addTab(self.analyze_tab, title)
            else:
                slice_name, detail = _PLACEHOLDERS[title]
                self.tabs.addTab(PlaceholderTab(title, slice_name, detail), title)

        self.tabs.setCurrentIndex(self.tabs.indexOf(self.analyze_tab))
        self.setCentralWidget(self.tabs)
        self.resize(1280, 860)

    def closeEvent(self, event):        # noqa: N802 - Qt naming
        """Let a running analysis finish before the window is destroyed.

        Qt aborts the whole process if a QThread is still running when it is
        destroyed, so closing mid-analysis would look like a crash."""
        self.analyze_tab.controller.shutdown()
        super().closeEvent(event)
