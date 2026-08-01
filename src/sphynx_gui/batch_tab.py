"""Batch Analysis tab: the project's sessions, the run, and its results (S4c)."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QFileDialog, QGroupBox, QHBoxLayout, QLabel, QPushButton, QSplitter,
    QTableWidget, QTableWidgetItem, QVBoxLayout, QWidget,
)

from sphynx_gui.batch_controller import BatchController
from sphynx_gui.sessions_table import SessionsTable
from sphynx_gui.warnings_panel import WarningsPanel

_RESULT_COLUMNS = ("Session", "Status", "Acts", "Warnings")


class BatchTab(QWidget):
    def __init__(self, state, parent=None):
        super().__init__(parent)
        self.state = state
        self.controller = BatchController(state, self)
        self._build_ui()
        self._connect()
        self.controller.refresh()

    # --- construction -----------------------------------------------------
    def _build_ui(self) -> None:
        self.new_project_button = QPushButton("New project")
        self.open_button = QPushButton("Open project...")
        self.save_button = QPushButton("Save project...")
        self.scan_button = QPushButton("Scan folder...")
        self.assign_preset_button = QPushButton("Preset for selected...")
        self.add_rule_button = QPushButton("Preset for all...")

        buttons = QWidget()
        buttons_layout = QHBoxLayout(buttons)
        buttons_layout.setContentsMargins(0, 0, 0, 0)
        for button in (self.new_project_button, self.open_button,
                       self.save_button, self.scan_button,
                       self.assign_preset_button, self.add_rule_button):
            buttons_layout.addWidget(button)
        buttons_layout.addStretch(1)

        self.table = SessionsTable()
        sessions = QGroupBox("Sessions")
        sessions_layout = QVBoxLayout(sessions)
        sessions_layout.addWidget(buttons)
        sessions_layout.addWidget(self.table)

        self.run_button = QPushButton("Run batch")
        self.cancel_button = QPushButton("Cancel")
        self.cancel_button.setEnabled(False)
        self.progress_label = QLabel("")
        self.status_label = QLabel("")
        self.status_label.setWordWrap(True)

        run_row = QWidget()
        run_layout = QHBoxLayout(run_row)
        run_layout.setContentsMargins(0, 0, 0, 0)
        run_layout.addWidget(self.run_button)
        run_layout.addWidget(self.cancel_button)
        run_layout.addWidget(self.progress_label, 1)

        self.results_table = QTableWidget(0, len(_RESULT_COLUMNS))
        self.results_table.setHorizontalHeaderLabels(list(_RESULT_COLUMNS))
        self.warnings = WarningsPanel()

        results = QGroupBox("Results")
        results_layout = QVBoxLayout(results)
        results_layout.addWidget(run_row)
        results_layout.addWidget(self.status_label)
        results_layout.addWidget(self.results_table, 2)
        results_layout.addWidget(self.warnings, 1)

        splitter = QSplitter(Qt.Vertical)
        splitter.addWidget(sessions)
        splitter.addWidget(results)
        splitter.setSizes([420, 420])

        layout = QVBoxLayout(self)
        layout.addWidget(splitter)

    def _connect(self) -> None:
        self.new_project_button.clicked.connect(self._new_project)
        self.open_button.clicked.connect(self._pick_open)
        self.save_button.clicked.connect(self._pick_save)
        self.scan_button.clicked.connect(self._pick_scan)
        self.assign_preset_button.clicked.connect(self._pick_preset_for_selected)
        self.add_rule_button.clicked.connect(self._pick_preset_for_all)
        self.run_button.clicked.connect(self.controller.run)
        self.cancel_button.clicked.connect(self.controller.cancel)
        self.state.project_changed.connect(self.controller.refresh)
        self.results_table.currentCellChanged.connect(self._on_result_row)

    # --- controller callbacks --------------------------------------------
    def set_status(self, text: str) -> None:
        self.status_label.setText(text)

    def set_progress(self, text: str) -> None:
        self.progress_label.setText(text)

    def set_busy(self, busy: bool) -> None:
        self.run_button.setEnabled(not busy)
        self.cancel_button.setEnabled(busy)
        if not busy:
            self.progress_label.setText("")

    def clear_results(self) -> None:
        self.results_table.setRowCount(0)
        self.warnings.clear()
        self._results = []

    def show_batch(self, batch) -> None:
        """One row per session, whether it produced a result or an error."""
        self._results = list(getattr(batch, "results", []) or [])
        errors = dict(getattr(batch, "errors", {}) or {})
        # Names recorded alongside the results, not derived from the tidy
        # table: a session that produced no acts contributes no tidy rows and
        # would drop out, shifting every later row onto the wrong result.
        names = list(getattr(batch, "session_names", []) or [])
        if len(names) != len(self._results):
            names = names[:len(self._results)]
            names += [f"session {i + 1}"
                      for i in range(len(names), len(self._results))]

        rows = []
        for index, name in enumerate(names):
            result = self._results[index]
            warnings = 0
            if result is not None:
                report = getattr(result, "validation", None)
                warnings = len(report.issues) if report is not None else 0
                warnings += len(getattr(result, "degraded", {}) or {})
            rows.append((name, "done",
                         len(getattr(result, "acts", []) or []) if result else 0,
                         warnings, result))
        for name, message in errors.items():
            rows.append((name, f"error: {message}", 0, 0, None))

        self.results_table.setRowCount(len(rows))
        self._row_results = []
        for row, (name, status, acts, warnings, result) in enumerate(rows):
            for column, value in enumerate((name, status, acts, warnings)):
                self.results_table.setItem(row, column,
                                           QTableWidgetItem(str(value)))
            self._row_results.append(result)

        # Failures belong on the warnings surface too, not only in a cell.
        if errors:
            self.warnings.rows = [("session", "error", f"{name}: {message}")
                                  for name, message in errors.items()]
            self.warnings._render()
        else:
            self.warnings.clear()

    # --- slots ------------------------------------------------------------
    def _on_result_row(self, row, _column=-1, *_args) -> None:
        results = getattr(self, "_row_results", [])
        if 0 <= row < len(results) and results[row] is not None:
            self.warnings.show_result(results[row])

    def _new_project(self) -> None:
        from sphynx.project import Project

        self.state.project = Project()
        self.clear_results()

    def _pick_scan(self) -> None:
        folder = QFileDialog.getExistingDirectory(self, "Scan folder for DLC csv")
        if folder:
            self.controller.scan(folder)

    def _pick_preset_for_selected(self) -> None:
        path, _ = QFileDialog.getOpenFileName(self, "Preset for the selected rows",
                                              "", "MAT files (*.mat)")
        if path:
            self.controller.assign_preset_to_selected(path)

    def _pick_preset_for_all(self) -> None:
        path, _ = QFileDialog.getOpenFileName(self, "Preset for every session",
                                              "", "MAT files (*.mat)")
        if path:
            self.controller.add_preset_rule(path, {})

    def _pick_open(self) -> None:
        path, _ = QFileDialog.getOpenFileName(self, "Open project", "",
                                              "JSON files (*.json)")
        if path:
            self.controller.open_project(path)

    def _pick_save(self) -> None:
        path, _ = QFileDialog.getSaveFileName(self, "Save project", "",
                                              "JSON files (*.json)")
        if path:
            self.controller.save_project(path)
