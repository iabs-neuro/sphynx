"""Define Acts tab: the act list on the left, the editor and preview on the
right (S4b)."""

from __future__ import annotations

from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure
from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QFileDialog, QGroupBox, QHBoxLayout, QLabel, QListWidget, QListWidgetItem,
    QPushButton, QSplitter, QVBoxLayout, QWidget,
)

from sphynx_gui.act_editor import ActEditor
from sphynx_gui.acts_controller import ActsController, draw_preview_etogram


class ActsTab(QWidget):
    def __init__(self, state, parent=None):
        super().__init__(parent)
        self.state = state
        self.controller = ActsController(state, self)
        self._build_ui()
        self._connect()
        self.controller.refresh_list()
        self._refresh_from_session()

    # --- construction -----------------------------------------------------
    def _build_ui(self) -> None:
        self.list_widget = QListWidget()
        left = QGroupBox("Acts")
        left_layout = QVBoxLayout(left)
        left_layout.addWidget(self.list_widget)

        self.new_button = QPushButton("Save as new / update")
        self.delete_button = QPushButton("Delete")
        self.save_button = QPushButton("Save library...")
        self.load_button = QPushButton("Load library...")
        for button in (self.new_button, self.delete_button, self.save_button,
                       self.load_button):
            left_layout.addWidget(button)

        self.editor = ActEditor()
        self.preview_button = QPushButton("Preview on the loaded session")
        self.preview_label = QLabel("No preview yet.")
        self.preview_label.setWordWrap(True)
        self.preview_canvas = FigureCanvas(Figure(figsize=(5, 1.6)))
        self.status_label = QLabel("")
        self.status_label.setWordWrap(True)

        right = QWidget()
        right_layout = QVBoxLayout(right)
        right_layout.addWidget(self.editor)
        right_layout.addWidget(self.preview_button)
        right_layout.addWidget(self.preview_label)
        right_layout.addWidget(self.preview_canvas, 1)
        right_layout.addWidget(self.status_label)

        splitter = QSplitter(Qt.Horizontal)
        splitter.addWidget(left)
        splitter.addWidget(right)
        splitter.setSizes([320, 900])

        layout = QVBoxLayout(self)
        layout.addWidget(splitter)

    def _connect(self) -> None:
        self.list_widget.currentItemChanged.connect(self._on_selection)
        self.new_button.clicked.connect(self.controller.add_act)
        self.delete_button.clicked.connect(self.controller.delete_selected)
        self.save_button.clicked.connect(self._pick_save)
        self.load_button.clicked.connect(self._pick_load)
        self.preview_button.clicked.connect(self.controller.preview)
        self.state.result_changed.connect(self._refresh_from_session)
        self.state.paradigm_changed.connect(self.controller.refresh_list)

    # --- session-derived choices -----------------------------------------
    def _refresh_from_session(self) -> None:
        result = self.state.result
        if result is None:
            return
        self.editor.set_zones(list(getattr(result, "zones", None) or []))
        self.editor.set_body_parts(getattr(result, "body_parts_names", []) or [])

    # --- controller callbacks --------------------------------------------
    def show_rows(self, rows) -> None:
        self.list_widget.clear()
        for name, source, overridden_by in rows:
            label = f"{name}  [{source}]"
            item = QListWidgetItem(label)
            if overridden_by:
                # Same name in the library. Whether it actually replaces this
                # act depends on the preset the run expands over, so the label
                # states the collision rather than asserting the outcome; the
                # warnings panel reports what a run really replaced.
                font = item.font()
                font.setStrikeOut(True)
                item.setFont(font)
                item.setText(f"{label}  your {overridden_by} defines this name")
            item.setData(Qt.UserRole, name)
            self.list_widget.addItem(item)

    def set_status(self, text: str) -> None:
        self.status_label.setText(text)

    def set_preview(self, text, named_mask, frame_rate) -> None:
        self.preview_label.setText(text)
        figure = self.preview_canvas.figure
        figure.clear()
        if named_mask is not None:
            draw_preview_etogram(figure.add_subplot(111), named_mask, frame_rate)
        self.preview_canvas.draw_idle()

    # --- slots ------------------------------------------------------------
    def _on_selection(self, current, _previous=None) -> None:
        if current is not None:
            self.controller.select(current.data(Qt.UserRole))

    def _pick_save(self) -> None:
        path, _ = QFileDialog.getSaveFileName(self, "Save act library", "",
                                              "JSON files (*.json)")
        if path:
            self.controller.save_library(path)

    def _pick_load(self) -> None:
        path, _ = QFileDialog.getOpenFileName(self, "Load act library", "",
                                              "JSON files (*.json)")
        if path:
            self.controller.load_library(path)
