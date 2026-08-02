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
from sphynx.preset.detect import ALGORITHMS as DETECT_ALGORITHMS
from sphynx.preset.detect import MODES as DETECT_MODES
from sphynx_gui.preset_canvas import KINDS, PresetCanvas
from sphynx_gui.preset_controller import (
    AUTO_STRATEGY, STRATEGY_FIELDS, ZONE_STRATEGIES, PresetController,
)
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

        # Which zones the arena outline implies. This used to be inferred from
        # the shape drawn, so a round arena silently got 'circle-rings' where
        # MATLAB's default builds 'circle' -- a different set of zones, and a
        # different set of numbers. AUTO keeps the inferred behaviour, but it
        # is now one named choice among the app's own.
        self.strategy_box = QComboBox()
        self.strategy_box.addItems(ZONE_STRATEGIES)
        self.strategy_box.setCurrentText(AUTO_STRATEGY)

        self.middle_width_box = QDoubleSpinBox()      # circle-rings
        self.middle_width_box.setRange(0.1, 1000.0)
        self.middle_width_box.setDecimals(2)
        self.middle_width_box.setValue(20.0)

        self.center_diameter_box = QDoubleSpinBox()   # circle-with-center
        self.center_diameter_box.setRange(0.1, 1000.0)
        self.center_diameter_box.setDecimals(2)
        self.center_diameter_box.setValue(20.0)

        self.strips_box = QSpinBox()                  # strips
        self.strips_box.setRange(1, 50)
        self.strips_box.setValue(3)
        self.strip_direction_box = QComboBox()
        self.strip_direction_box.addItems(("horizontal", "vertical"))

        self.detect_mode_box = QComboBox()
        self.detect_mode_box.addItems(DETECT_MODES)
        self.detect_algorithm_box = QComboBox()
        self.detect_algorithm_box.addItems(DETECT_ALGORITHMS)
        self.sensitivity_box = QDoubleSpinBox()
        self.sensitivity_box.setRange(0.0, 1.0)
        self.sensitivity_box.setSingleStep(0.05)
        self.sensitivity_box.setDecimals(2)
        self.sensitivity_box.setValue(0.75)
        self.min_area_box = QDoubleSpinBox()
        self.min_area_box.setRange(0.0, 100_000.0)
        self.min_area_box.setValue(1.0)
        self.max_area_box = QDoubleSpinBox()
        self.max_area_box.setRange(0.1, 100_000.0)
        self.max_area_box.setValue(200.0)
        self.neighborhood_box = QDoubleSpinBox()
        self.neighborhood_box.setRange(0.0, 1000.0)
        self.neighborhood_box.setValue(0.0)      # 0 = the default neighbourhood
        self.radius_min_box = QDoubleSpinBox()
        self.radius_min_box.setRange(0.1, 1000.0)
        self.radius_min_box.setValue(1.0)
        self.radius_max_box = QDoubleSpinBox()
        self.radius_max_box.setRange(0.2, 1000.0)
        self.radius_max_box.setValue(10.0)
        self.detect_button = QPushButton("Auto-detect objects")

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

        strips_row = QWidget()
        strips_layout = QHBoxLayout(strips_row)
        strips_layout.setContentsMargins(0, 0, 0, 0)
        strips_layout.addWidget(self.strips_box)
        strips_layout.addWidget(self.strip_direction_box)

        zones = QGroupBox("Arena zones")
        zones_layout = QFormLayout(zones)
        zones_layout.addRow("Strategy", self.strategy_box)
        zones_layout.addRow("Wall band, cm", self.wall_width_box)
        zones_layout.addRow("Middle width, cm", self.middle_width_box)
        zones_layout.addRow("Centre diameter, cm", self.center_diameter_box)
        zones_layout.addRow("Strips", strips_row)

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
        area_row = QWidget()
        area_layout = QHBoxLayout(area_row)
        area_layout.setContentsMargins(0, 0, 0, 0)
        area_layout.addWidget(QLabel("min"))
        area_layout.addWidget(self.min_area_box)
        area_layout.addWidget(QLabel("max"))
        area_layout.addWidget(self.max_area_box)

        radius_row = QWidget()
        radius_layout = QHBoxLayout(radius_row)
        radius_layout.setContentsMargins(0, 0, 0, 0)
        radius_layout.addWidget(QLabel("min"))
        radius_layout.addWidget(self.radius_min_box)
        radius_layout.addWidget(QLabel("max"))
        radius_layout.addWidget(self.radius_max_box)

        detect = QGroupBox("Find objects automatically")
        detect_layout = QFormLayout(detect)
        detect_layout.addRow("Shape", self.detect_mode_box)
        detect_layout.addRow("Algorithm", self.detect_algorithm_box)
        detect_layout.addRow("Sensitivity", self.sensitivity_box)
        detect_layout.addRow("Area, cm2", area_row)
        detect_layout.addRow("Radius, cm", radius_row)
        detect_layout.addRow("Neighbourhood, cm", self.neighborhood_box)
        detect_layout.addRow(self.detect_button)

        right_layout = QVBoxLayout(right)
        right_layout.addWidget(form)
        right_layout.addWidget(zones)
        right_layout.addWidget(detect)
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
        self.strategy_box.currentTextChanged.connect(self._on_strategy)
        self._on_strategy(self.strategy_box.currentText())
        self.detect_button.clicked.connect(self.controller.detect_objects)
        self.detect_mode_box.currentTextChanged.connect(self._on_detect_mode)
        self.detect_algorithm_box.currentTextChanged.connect(
            lambda _: self._on_detect_mode(self.detect_mode_box.currentText()))
        self._on_detect_mode(self.detect_mode_box.currentText())
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
        self.remember_role(name, role, is_target)
        self._refresh_table()

    def remember_role(self, name: str, role: str, is_target: bool = False) -> None:
        """Record a role WITHOUT rebuilding the table.

        Rebuilding it constructs a combo box and a checkbox per row, so doing
        it once per shape while adding a dozen at a time is quadratic."""
        self._roles[name] = (role, bool(is_target))

    def refresh_shape_table(self) -> None:
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

    def _on_strategy(self, strategy: str) -> None:
        """Only the fields the chosen strategy reads stay live.

        A greyed-out box is how the user sees that changing it would do
        nothing -- the same guard MATLAB's onZoneStrategyChanged applies."""
        uses = STRATEGY_FIELDS.get(strategy, set())
        self.wall_width_box.setEnabled("wall" in uses)
        self.middle_width_box.setEnabled("middle" in uses)
        self.center_diameter_box.setEnabled("center_diameter" in uses)
        self.strips_box.setEnabled("strips" in uses)
        self.strip_direction_box.setEnabled("strips" in uses)

    def _on_detect_mode(self, mode: str) -> None:
        """The radius range belongs to the Hough circle search alone.

        MATLAB offers Hough only for the circle mode; leaving the radius boxes
        live elsewhere would suggest they do something."""
        hough = (mode == "all-circles"
                 and self.detect_algorithm_box.currentText() == "hough")
        self.radius_min_box.setEnabled(hough)
        self.radius_max_box.setEnabled(hough)
        self.neighborhood_box.setEnabled(not hough)
        self.detect_algorithm_box.setEnabled(mode == "all-circles")

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
