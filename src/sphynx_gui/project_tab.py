"""Project tab: create, open and configure the project (S4f).

First tab in the window. Everything the other tabs need to stop asking for
paths lives here: where the project is, what its folders are, which paradigm
and acts library it uses, and which files belong to it.
"""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QAbstractItemView, QComboBox, QFileDialog, QFormLayout, QGroupBox,
    QHBoxLayout, QHeaderView, QLabel, QLineEdit, QPushButton, QTableWidget,
    QTableWidgetItem, QVBoxLayout, QWidget,
)

from sphynx.paradigms import PARADIGMS, register_builtin_paradigms
from sphynx_gui.project_controller import ProjectController
from sphynx_gui.warnings_panel import WarningsPanel

_FOLDER_COLUMNS = ("Folder", "Path", "State")
COPY_CHOICES = ("Copy into the project", "Leave in place (link)")
_VIDEO_FILTER = "Video files (*.mp4 *.avi *.mov *.mkv)"
_TRACKING_FILTER = "Tracking files (*.csv)"


class ProjectTab(QWidget):
    def __init__(self, state, parent=None):
        super().__init__(parent)
        self.state = state
        if not PARADIGMS:
            register_builtin_paradigms()
        self._loading = False
        self._build_ui()
        self.controller = ProjectController(state, self)
        self._connect()
        self.refresh()

    # --- construction -----------------------------------------------------
    def _build_ui(self) -> None:
        self.new_button = QPushButton("New project...")
        self.open_button = QPushButton("Open project...")
        self.save_button = QPushButton("Save project")
        self.save_as_button = QPushButton("Save as...")

        self.name_box = QLineEdit()
        self.root_label = QLabel("(no project)")
        self.root_label.setWordWrap(True)
        self.dirty_label = QLabel("")

        self.paradigm_box = QComboBox()
        self.paradigm_box.addItems(sorted(PARADIGMS))
        self.library_box = QLineEdit()
        self.library_browse_button = QPushButton("Browse...")
        self.library_new_button = QPushButton("Create empty")

        self.folders_table = QTableWidget(0, len(_FOLDER_COLUMNS))
        self.folders_table.setHorizontalHeaderLabels(_FOLDER_COLUMNS)
        self.folders_table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.folders_table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.folders_table.horizontalHeader().setSectionResizeMode(
            QHeaderView.ResizeToContents)

        self.copy_box = QComboBox()
        self.copy_box.addItems(COPY_CHOICES)
        self.add_video_button = QPushButton("Add videos...")
        self.add_tracking_button = QPushButton("Add tracking...")

        self.warnings = WarningsPanel()
        self.status_label = QLabel("")
        self.status_label.setWordWrap(True)

        buttons = QWidget()
        button_layout = QHBoxLayout(buttons)
        button_layout.setContentsMargins(0, 0, 0, 0)
        for button in (self.new_button, self.open_button, self.save_button,
                       self.save_as_button):
            button_layout.addWidget(button)
        button_layout.addStretch(1)

        about = QGroupBox("Project")
        about_layout = QFormLayout(about)
        about_layout.addRow("Name", self.name_box)
        about_layout.addRow("Folder", self.root_label)
        about_layout.addRow("", self.dirty_label)

        library_row = QWidget()
        library_layout = QHBoxLayout(library_row)
        library_layout.setContentsMargins(0, 0, 0, 0)
        library_layout.addWidget(self.library_box, 1)
        library_layout.addWidget(self.library_browse_button)
        library_layout.addWidget(self.library_new_button)

        settings = QGroupBox("Settings")
        settings_layout = QFormLayout(settings)
        settings_layout.addRow("Paradigm", self.paradigm_box)
        settings_layout.addRow("Acts library", library_row)

        add_row = QWidget()
        add_layout = QHBoxLayout(add_row)
        add_layout.setContentsMargins(0, 0, 0, 0)
        add_layout.addWidget(self.copy_box)
        add_layout.addWidget(self.add_video_button)
        add_layout.addWidget(self.add_tracking_button)
        add_layout.addStretch(1)

        data = QGroupBox("Data")
        data_layout = QVBoxLayout(data)
        data_layout.addWidget(self.folders_table, 1)
        data_layout.addWidget(add_row)

        layout = QVBoxLayout(self)
        layout.addWidget(buttons)
        layout.addWidget(about)
        layout.addWidget(settings)
        layout.addWidget(data, 1)
        layout.addWidget(self.warnings, 1)
        layout.addWidget(self.status_label)

    def _connect(self) -> None:
        self.new_button.clicked.connect(self._pick_new)
        self.open_button.clicked.connect(self._pick_open)
        self.save_button.clicked.connect(self.controller.save)
        self.save_as_button.clicked.connect(self._pick_save_as)
        self.name_box.editingFinished.connect(self._on_name)
        self.paradigm_box.currentTextChanged.connect(self._on_paradigm)
        self.library_box.editingFinished.connect(self._on_library)
        self.library_browse_button.clicked.connect(self._pick_library)
        self.library_new_button.clicked.connect(self.controller.create_library)
        self.add_video_button.clicked.connect(
            lambda: self._pick_files("raw_videos", _VIDEO_FILTER))
        self.add_tracking_button.clicked.connect(
            lambda: self._pick_files("tracking", _TRACKING_FILTER))
        self.state.project_changed.connect(self.refresh)
        self.state.project_dirty_changed.connect(self._show_dirty)

    # --- showing the project ---------------------------------------------
    def refresh(self) -> None:
        self._loading = True
        try:
            project = self.state.project
            self.name_box.setText(project.name)
            self.root_label.setText(project.root or "(no project)")
            self.library_box.setText(project.library_path)
            if project.paradigm and project.paradigm in PARADIGMS:
                self.paradigm_box.setCurrentText(project.paradigm)
            self._show_folders()
        finally:
            self._loading = False
        self._show_dirty()
        self.warnings.show_rows(self.controller.report())

    def _show_folders(self) -> None:
        rows = self.controller.folders()
        self.folders_table.setRowCount(len(rows))
        for index, (name, path, state) in enumerate(rows):
            for column, text in enumerate((name, path, state)):
                self.folders_table.setItem(index, column,
                                           QTableWidgetItem(str(text)))

    def _show_dirty(self) -> None:
        self.dirty_label.setText(
            "Unsaved changes" if self.state.project_dirty else "")

    def set_status(self, text: str) -> None:
        self.status_label.setText(str(text))
        self.warnings.show_rows(self.controller.report())

    # --- slots ------------------------------------------------------------
    def copy_selected(self) -> bool:
        return self.copy_box.currentText() == COPY_CHOICES[0]

    def _on_name(self) -> None:
        if not self._loading:
            self.controller.set_name(self.name_box.text())

    def _on_paradigm(self, name: str) -> None:
        if not self._loading:
            self.controller.set_paradigm(name)

    def _on_library(self) -> None:
        if not self._loading:
            self.controller.set_library(self.library_box.text())

    def _pick_new(self) -> None:
        folder = QFileDialog.getExistingDirectory(self, "New project folder")
        if folder:
            self.controller.new_project(folder)

    def _pick_open(self) -> None:
        path, _ = QFileDialog.getOpenFileName(
            self, "Open project", "", "Project files (project.json)")
        if path:
            self.controller.open_project(path)

    def _pick_save_as(self) -> None:
        folder = QFileDialog.getExistingDirectory(self, "Project folder")
        if folder:
            self.controller.save_as(folder)

    def _pick_library(self) -> None:
        path, _ = QFileDialog.getOpenFileName(
            self, "Acts library", self.state.project.root or "",
            "Acts library (*.json)")
        if path:
            self.library_box.setText(path)
            self.controller.set_library(path)

    def _pick_files(self, kind: str, file_filter: str) -> None:
        start = self.state.project_folder(kind)
        paths, _ = QFileDialog.getOpenFileNames(
            self, f"Add {kind}", start, file_filter)
        if paths:
            self.controller.add_files(paths, kind, self.copy_selected())
