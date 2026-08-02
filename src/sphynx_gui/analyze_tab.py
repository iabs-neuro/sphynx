"""Analyze Session tab (S4a)."""

from __future__ import annotations

from PySide6.QtWidgets import (
    QComboBox, QDoubleSpinBox, QFileDialog, QFormLayout, QGroupBox, QHBoxLayout,
    QLabel, QPushButton, QSpinBox, QSplitter, QTableWidget, QTableWidgetItem,
    QVBoxLayout, QWidget,
)
from PySide6.QtCore import Qt

from sphynx.paradigms import PARADIGMS, register_builtin_paradigms
from sphynx_gui.analyze_controller import _ACT_COLUMNS, AnalyzeController, _format
from sphynx_gui.plot_grid import PlotGrid
from sphynx_gui.warnings_panel import WarningsPanel


class AnalyzeTab(QWidget):
    def __init__(self, state, parent=None):
        super().__init__(parent)
        self.state = state
        if not PARADIGMS:
            register_builtin_paradigms()

        self.controller = AnalyzeController(state, self)
        self._build_ui()
        self._connect()

    # --- construction ---
    def _build_ui(self) -> None:
        self.dlc_label = QLabel("(none)")
        self.preset_label = QLabel("(none)")
        self.out_label = QLabel("(none)")
        for label in (self.dlc_label, self.preset_label, self.out_label):
            label.setWordWrap(True)

        self.dlc_button = QPushButton("DLC csv...")
        self.preset_button = QPushButton("Preset .mat...")
        self.out_button = QPushButton("Output dir...")

        self.paradigm_box = QComboBox()
        self.paradigm_box.addItems(sorted(PARADIGMS))
        if self.state.paradigm in PARADIGMS:
            self.paradigm_box.setCurrentText(self.state.paradigm)

        self.end_frame_box = QSpinBox()
        self.end_frame_box.setRange(0, 10_000_000)
        self.end_frame_box.setSpecialValueText("all")
        self.heatmap_bin_box = QDoubleSpinBox()
        self.heatmap_bin_box.setRange(0.5, 50.0)
        self.heatmap_bin_box.setValue(self.state.heatmap_bin_cm)

        self.run_button = QPushButton("Run analyze")
        self.status_label = QLabel("Ready.")
        self.status_label.setWordWrap(True)
        self.warnings = WarningsPanel()

        paths = QGroupBox("Session")
        paths_form = QFormLayout(paths)
        paths_form.addRow(self.dlc_button, self.dlc_label)
        paths_form.addRow(self.preset_button, self.preset_label)
        paths_form.addRow(self.out_button, self.out_label)

        options = QGroupBox("Options")
        options_form = QFormLayout(options)
        options_form.addRow("Paradigm", self.paradigm_box)
        options_form.addRow("Last frame", self.end_frame_box)
        options_form.addRow("Heatmap bin, cm", self.heatmap_bin_box)

        left = QWidget()
        left_layout = QVBoxLayout(left)
        left_layout.addWidget(paths)
        left_layout.addWidget(options)
        left_layout.addWidget(self.run_button)
        left_layout.addWidget(self.status_label)
        left_layout.addWidget(self.warnings, 1)

        self.plots = PlotGrid()
        self.acts_table = QTableWidget(0, len(_ACT_COLUMNS))
        self.acts_table.setHorizontalHeaderLabels(list(_ACT_COLUMNS))
        self.metrics_table = QTableWidget(0, 2)
        self.metrics_table.setHorizontalHeaderLabels(["Metric", "Value"])
        self.metrics_note = QLabel("")
        self.metrics_note.setWordWrap(True)

        metrics_side = QWidget()
        metrics_layout = QVBoxLayout(metrics_side)
        metrics_layout.setContentsMargins(0, 0, 0, 0)
        metrics_layout.addWidget(self.metrics_table)
        metrics_layout.addWidget(self.metrics_note)

        tables = QWidget()
        tables_layout = QHBoxLayout(tables)
        tables_layout.addWidget(self.acts_table, 2)
        tables_layout.addWidget(metrics_side, 1)

        right = QSplitter(Qt.Vertical)
        right.addWidget(self.plots)
        right.addWidget(tables)
        right.setSizes([600, 260])

        splitter = QSplitter(Qt.Horizontal)
        splitter.addWidget(left)
        splitter.addWidget(right)
        splitter.setSizes([330, 950])

        layout = QVBoxLayout(self)
        layout.addWidget(splitter)

    def _connect(self) -> None:
        self.dlc_button.clicked.connect(self._pick_dlc)
        self.preset_button.clicked.connect(self._pick_preset)
        self.out_button.clicked.connect(self._pick_out_dir)
        self.paradigm_box.currentTextChanged.connect(self._on_paradigm)
        self.end_frame_box.valueChanged.connect(self._on_end_frame)
        self.heatmap_bin_box.valueChanged.connect(self._on_heatmap_bin)
        self.run_button.clicked.connect(self.controller.run)
        self.state.paths_changed.connect(self._refresh_paths)
        self.state.project_changed.connect(self._on_project)
        self._on_project()

    def _on_project(self) -> None:
        """Point a single run at the newly opened project's temp folder.

        Opening a project is an explicit act, so following it is expected; the
        folder stays editable afterwards."""
        temp = self.default_out_dir()
        if temp:
            self.state.out_dir = temp

    # --- slots ---
    def _pick_dlc(self) -> None:
        path, _ = QFileDialog.getOpenFileName(
            self, "Choose DLC csv", self.state.project_folder("tracking"),
            "CSV files (*.csv)")
        if path:
            self.state.dlc_path = path

    def _pick_preset(self) -> None:
        path, _ = QFileDialog.getOpenFileName(
            self, "Choose preset", self.state.project_folder("presets"),
            "MAT files (*.mat)")
        if path:
            self.state.preset_path = path

    def _pick_out_dir(self) -> None:
        path = QFileDialog.getExistingDirectory(
            self, "Choose output directory", self.default_out_dir())
        if path:
            self.state.out_dir = path

    def default_out_dir(self) -> str:
        """Where a single run writes: temp/, not the results folder.

        A run here is setup -- pick the preset, the paradigm and the acts on
        one session. Batch re-analyses that same session for real, and mixing
        the two makes it impossible to tell later which numbers were final."""
        return self.state.project_folder("temp")

    def _on_paradigm(self, name: str) -> None:
        self.state.paradigm = name

    def _on_end_frame(self, value: int) -> None:
        self.state.end_frame = int(value)

    def _on_heatmap_bin(self, value: float) -> None:
        self.state.heatmap_bin_cm = float(value)

    def _refresh_paths(self) -> None:
        self.dlc_label.setText(self.state.dlc_path or "(none)")
        self.preset_label.setText(self.state.preset_path or "(none)")
        self.out_label.setText(self.state.out_dir or "(none)")

    # --- controller callbacks ---
    def set_status(self, text: str) -> None:
        self.status_label.setText(text)

    def set_busy(self, busy: bool) -> None:
        self.run_button.setEnabled(not busy)

    def show_result(self, result) -> None:
        self.warnings.show_result(result)
        self.plots.show_result(result, heatmap_bin_cm=self.state.heatmap_bin_cm)
        self._fill_acts(result)
        self._fill_metrics(result)

    def clear_result(self) -> None:
        """Drop everything the previous run put on screen."""
        self.warnings.clear()
        self.plots.clear()
        self.acts_table.setRowCount(0)
        self.metrics_table.setRowCount(0)
        self.metrics_note.setText("")

    def _fill_acts(self, result) -> None:
        acts = [a for a in (getattr(result, "acts", []) or []) if a.stats is not None]
        self.acts_table.setRowCount(len(acts))
        for row, act in enumerate(acts):
            stats = act.stats
            values = (act.name, _format(stats.percent), _format(stats.count),
                      _format(stats.duration_s), _format(stats.distance_cm),
                      _format(stats.mean_velocity))
            for column, value in enumerate(values):
                self.acts_table.setItem(row, column, QTableWidgetItem(value))

    def _fill_metrics(self, result) -> None:
        metrics = getattr(result, "metrics", None)
        rows = []
        if metrics is not None:
            rows.extend((name, _format(value))
                        for name, value in metrics.values.items())
            # A metric that could not be computed is a result too, not a blank.
            rows.extend((name, f"error: {message}")
                        for name, message in metrics.errors.items())
        self.metrics_table.setRowCount(len(rows))
        for row, (name, value) in enumerate(rows):
            self.metrics_table.setItem(row, 0, QTableWidgetItem(name))
            self.metrics_table.setItem(row, 1, QTableWidgetItem(value))

        # An empty table must not read as "computed nothing wrong": say why.
        if rows:
            self.metrics_note.setText("")
        elif metrics is None:
            self.metrics_note.setText("No paradigm was applied to this run.")
        else:
            paradigm = getattr(result, "paradigm", "") or "this paradigm"
            self.metrics_note.setText(
                f"{paradigm} declares no named metrics; the act table above is "
                "the whole result.")
