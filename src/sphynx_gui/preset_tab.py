"""Create Preset tab: draw the arena and the objects, save a preset (S4d).

Left: the video frame with the shapes drawn on it. Right: what was drawn, what
role each shape plays, and what the chosen paradigm still complains about.
"""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QAbstractItemView, QCheckBox, QComboBox, QDoubleSpinBox, QFileDialog,
    QFormLayout, QGroupBox, QHBoxLayout, QHeaderView, QInputDialog, QLabel,
    QPushButton, QSpinBox, QSplitter, QTableWidget, QTableWidgetItem,
    QVBoxLayout, QWidget,
)

from sphynx.paradigms import PARADIGMS, register_builtin_paradigms
from sphynx.preset.calibration import MODES as CALIBRATION_MODES
from sphynx_gui.preset_canvas import KINDS, PresetCanvas
from sphynx_gui.preset_controller import PresetController
from sphynx_gui.warnings_panel import WarningsPanel

ROLES = ("arena", "object", "hole", "wall", "corner", "unused")
_SHAPE_COLUMNS = ("Name", "Shape", "Role", "Target")


class PresetTab(QWidget):
    def __init__(self, state, parent=None):
        super().__init__(parent)
        self.state = state
        if not PARADIGMS:
            register_builtin_paradigms()
        self._roles: dict = {}          # shape name -> (role, is_target)
        self._loading = False
        self._build_ui()
        self.controller = PresetController(state, self)
        self._connect()

    # --- construction -----------------------------------------------------
    def _build_ui(self) -> None:
        self.canvas = PresetCanvas()

        self.video_button = QPushButton("Open video...")
        self.frame_spin = QSpinBox()
        self.frame_spin.setRange(0, 0)
        self.frame_rate_box = QDoubleSpinBox()
        self.frame_rate_box.setRange(0.0, 10_000.0)
        self.frame_rate_box.setDecimals(3)
        self.frame_rate_box.setValue(30.0)

        self.calib_mode_box = QComboBox()
        self.calib_mode_box.addItems(CALIBRATION_MODES)
        self.calib_mode_box.setCurrentText("1 line")
        self.choose_button = QPushButton("Choose")
        self.compute_button = QPushButton("Compute")
        # The MATLAB app's defaults; the arena these presets were built for is
        # 92 cm across, and starting anywhere else would make the common case
        # a retype.
        self.distance_y_box = QDoubleSpinBox()
        self.distance_y_box.setRange(0.1, 10_000.0)
        self.distance_y_box.setDecimals(2)
        self.distance_y_box.setValue(92.0)
        self.distance_x_box = QDoubleSpinBox()
        self.distance_x_box.setRange(0.1, 10_000.0)
        self.distance_x_box.setDecimals(2)
        self.distance_x_box.setValue(92.0)

        self.pixels_per_cm_box = QDoubleSpinBox()
        self.pixels_per_cm_box.setRange(0.0, 10_000.0)
        self.pixels_per_cm_box.setDecimals(4)
        self.pixels_per_cm_box.setValue(0.0)
        self.calib_label = QLabel("Y: ?   X: ?   avg: ?   kcorr: ?")
        self.calib_label.setWordWrap(True)

        self.wall_width_box = QDoubleSpinBox()
        self.wall_width_box.setRange(0.0, 100.0)
        self.wall_width_box.setDecimals(2)
        self.wall_width_box.setSingleStep(0.5)
        self.wall_width_box.setValue(3.0)

        self.ring_width_box = QDoubleSpinBox()
        self.ring_width_box.setRange(0.0, 100.0)
        self.ring_width_box.setDecimals(2)
        self.ring_width_box.setSingleStep(0.5)
        self.ring_width_box.setValue(2.5)

        self.tool_box = QComboBox()
        self.tool_box.addItems(KINDS)
        self.draw_button = QPushButton("Draw shape...")
        self.remove_button = QPushButton("Remove shape")
        self.build_button = QPushButton("Build zones")
        self.save_button = QPushButton("Save preset...")

        self.shapes_table = QTableWidget(0, len(_SHAPE_COLUMNS))
        self.shapes_table.setHorizontalHeaderLabels(_SHAPE_COLUMNS)
        self.shapes_table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.shapes_table.horizontalHeader().setSectionResizeMode(
            QHeaderView.ResizeToContents)

        self.zones_label = QLabel("No zones built yet.")
        self.zones_label.setWordWrap(True)
        self.warnings = WarningsPanel()
        self.status_label = QLabel("")
        self.status_label.setWordWrap(True)

        video_row = QWidget()
        video_layout = QHBoxLayout(video_row)
        video_layout.setContentsMargins(0, 0, 0, 0)
        video_layout.addWidget(self.video_button)
        video_layout.addWidget(QLabel("Frame"))
        video_layout.addWidget(self.frame_spin)
        video_layout.addStretch(1)

        calib_row = QWidget()
        calib_layout = QHBoxLayout(calib_row)
        calib_layout.setContentsMargins(0, 0, 0, 0)
        calib_layout.addWidget(self.calib_mode_box)
        calib_layout.addWidget(self.choose_button)
        calib_layout.addWidget(self.compute_button)

        distance_row = QWidget()
        distance_layout = QHBoxLayout(distance_row)
        distance_layout.setContentsMargins(0, 0, 0, 0)
        distance_layout.addWidget(QLabel("cm Y"))
        distance_layout.addWidget(self.distance_y_box)
        distance_layout.addWidget(QLabel("cm X"))
        distance_layout.addWidget(self.distance_x_box)

        form = QGroupBox("Calibration and geometry")
        form_layout = QFormLayout(form)
        form_layout.addRow("Frame rate, fps", self.frame_rate_box)
        form_layout.addRow("Calibration", calib_row)
        form_layout.addRow(distance_row)
        form_layout.addRow(self.calib_label)
        form_layout.addRow("Pixels per cm", self.pixels_per_cm_box)
        form_layout.addRow("Ring width, cm", self.ring_width_box)
        form_layout.addRow("Wall band, cm", self.wall_width_box)

        draw_row = QWidget()
        draw_layout = QHBoxLayout(draw_row)
        draw_layout.setContentsMargins(0, 0, 0, 0)
        draw_layout.addWidget(self.tool_box)
        draw_layout.addWidget(self.draw_button)
        draw_layout.addWidget(self.remove_button)

        actions = QWidget()
        actions_layout = QHBoxLayout(actions)
        actions_layout.setContentsMargins(0, 0, 0, 0)
        actions_layout.addWidget(self.build_button)
        actions_layout.addWidget(self.save_button)

        left = QWidget()
        left_layout = QVBoxLayout(left)
        left_layout.addWidget(video_row)
        left_layout.addWidget(self.canvas, 1)

        right = QWidget()
        right_layout = QVBoxLayout(right)
        right_layout.addWidget(form)
        right_layout.addWidget(draw_row)
        right_layout.addWidget(self.shapes_table, 1)
        right_layout.addWidget(actions)
        right_layout.addWidget(self.zones_label)
        right_layout.addWidget(self.warnings, 1)
        right_layout.addWidget(self.status_label)

        splitter = QSplitter(Qt.Horizontal)
        splitter.addWidget(left)
        splitter.addWidget(right)
        splitter.setSizes([760, 520])

        layout = QVBoxLayout(self)
        layout.addWidget(splitter)

    def _connect(self) -> None:
        self.video_button.clicked.connect(self._pick_video)
        self.frame_spin.valueChanged.connect(self._on_frame)
        self.choose_button.clicked.connect(self.controller.begin_calibration)
        self.compute_button.clicked.connect(
            self.controller.compute_calibration)
        self.canvas.points_picked.connect(self.controller.on_points_picked)
        self.calib_mode_box.currentTextChanged.connect(self._on_calib_mode)
        self._on_calib_mode(self.calib_mode_box.currentText())
        self.tool_box.currentTextChanged.connect(self.canvas.set_tool)
        self.draw_button.clicked.connect(self._ask_shape)
        self.remove_button.clicked.connect(self._remove_selected)
        self.build_button.clicked.connect(self.controller.build_zones)
        self.save_button.clicked.connect(self._pick_save)
        self.canvas.shape_drawn.connect(self._on_shape_drawn)
        self.state.paradigm_changed.connect(self.controller.validate)

    # --- roles ------------------------------------------------------------
    def shape_roles(self) -> dict:
        """Name -> (role, is_target), read from the table so what is shown is
        what is built."""
        out: dict = {}
        for row in range(self.shapes_table.rowCount()):
            name = self.shapes_table.item(row, 0).text()
            role = self.shapes_table.cellWidget(row, 2).currentText()
            target = self.shapes_table.cellWidget(row, 3).isChecked()
            out[name] = (role, target)
        return out

    def set_shape_role(self, name: str, role: str, is_target: bool = False) -> None:
        self._roles[name] = (role, bool(is_target))
        self._refresh_table()

    def forget_roles(self) -> None:
        """Drop every remembered role; used when the shapes themselves go."""
        self._roles = {}
        self._refresh_table()

    def remove_selected_shape(self, name: str) -> None:
        self.canvas.remove_shape(name)
        self._roles.pop(name, None)
        self._refresh_table()

    def _default_role(self, name: str) -> tuple:
        return self._roles.get(name, ("object", False))

    def _refresh_table(self) -> None:
        self._loading = True
        try:
            shapes = self.canvas.shapes
            self.shapes_table.setRowCount(len(shapes))
            for row, shape in enumerate(shapes):
                role, target = self._default_role(shape.name)
                name_item = QTableWidgetItem(shape.name)
                name_item.setFlags(name_item.flags() & ~Qt.ItemIsEditable)
                self.shapes_table.setItem(row, 0, name_item)
                kind_item = QTableWidgetItem(shape.kind)
                kind_item.setFlags(kind_item.flags() & ~Qt.ItemIsEditable)
                self.shapes_table.setItem(row, 1, kind_item)

                role_box = QComboBox()
                role_box.addItems(ROLES)
                role_box.setCurrentText(role if role in ROLES else "unused")
                role_box.currentTextChanged.connect(self._on_role_edited)
                self.shapes_table.setCellWidget(row, 2, role_box)

                target_box = QCheckBox()
                target_box.setChecked(bool(target))
                target_box.toggled.connect(self._on_role_edited)
                self.shapes_table.setCellWidget(row, 3, target_box)
        finally:
            self._loading = False

    def _on_role_edited(self, *_args) -> None:
        if self._loading:
            return
        self._roles = dict(self.shape_roles())

    # --- zones ------------------------------------------------------------
    def show_zones(self, zones) -> None:
        counts: dict = {}
        for zone in zones:
            counts[zone.zone_class] = counts.get(zone.zone_class, 0) + 1
        self.zones_label.setText(
            "Zones: " + ", ".join(f"{k} x{v}" for k, v in sorted(counts.items())))

    def set_status(self, text: str) -> None:
        self.status_label.setText(str(text))

    # --- slots ------------------------------------------------------------
    def _on_shape_drawn(self, name: str) -> None:
        self._roles.setdefault(name, ("object", False))
        self._refresh_table()

    def _on_frame(self, index: int) -> None:
        if self.controller.video is not None:
            self.controller.show_frame(int(index))

    def _pick_video(self) -> None:
        path, _ = QFileDialog.getOpenFileName(
            self, "Open video", self.state.project_folder("raw_videos"),
            "Video files (*.mp4 *.avi *.mov *.mkv)")
        if path:
            self.controller.open_video(path)

    def _ask_shape(self) -> None:
        name, ok = QInputDialog.getText(self, "Draw shape", "Shape name")
        if ok and name:
            self.canvas.set_tool(self.tool_box.currentText())
            self.canvas.begin_shape(name)
            self.set_status(
                f"Drag on the frame to draw {name!r} as a "
                f"{self.tool_box.currentText()}.")

    def _remove_selected(self) -> None:
        row = self.shapes_table.currentRow()
        if row < 0:
            self.set_status("Select a shape in the table to remove it.")
            return
        self.remove_selected_shape(self.shapes_table.item(row, 0).text())

    def _on_calib_mode(self, mode: str) -> None:
        # One line measures a single length, so there is no separate
        # horizontal distance to enter.
        self.distance_x_box.setEnabled(mode != "1 line")

    def show_calibration(self, result) -> None:
        self.calib_label.setText(
            f"Y: {result.pxl_y:.2f}   X: {result.pxl_x:.2f}   "
            f"avg: {result.pixels_per_cm:.2f}   kcorr: {result.x_kcorr:.3f}")

    def _pick_save(self) -> None:
        path, _ = QFileDialog.getSaveFileName(
            self, "Save preset", self.state.project_folder("presets"),
            "Preset files (*.mat)")
        if path:
            self.controller.save(path)
