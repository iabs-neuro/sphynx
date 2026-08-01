"""Editor for one act: a form over the Act dataclass (S4b).

Deliberately absent: the body-part fallback chain. Choosing an arbitrary proxy
for a missing part is the silent substitution the engine exists to prevent, so
it is a curated decision rather than a control. The form sets `body_part`, and
`required_parts` follows from it.
"""

from __future__ import annotations

from PySide6.QtCore import Signal
from PySide6.QtWidgets import (
    QComboBox, QDoubleSpinBox, QFormLayout, QLineEdit, QWidget,
)

from sphynx.acts.schema import Act

SINGLE_ZONE = "single zone"
ZONE_CLASS = "zone class"


class ActEditor(QWidget):
    changed = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._zones: list = []
        self.missing: list = []      # choices the loaded session does not offer

        self.name_box = QLineEdit()
        self.binding = QComboBox()
        self.binding.addItems([SINGLE_ZONE, ZONE_CLASS])
        self.zone_box = QComboBox()
        self.body_part_box = QComboBox()

        self.speed_min_box = QDoubleSpinBox()
        self.speed_min_box.setRange(0.0, 1000.0)
        self.speed_max_box = QDoubleSpinBox()
        self.speed_max_box.setRange(0.0, 1000.0)
        self.speed_max_box.setSpecialValueText("no limit")

        self.min_duration_box = QDoubleSpinBox()
        self.min_duration_box.setRange(0.0, 60.0)
        self.min_duration_box.setSingleStep(0.05)
        self.max_gap_box = QDoubleSpinBox()
        self.max_gap_box.setRange(0.0, 60.0)
        self.max_gap_box.setSingleStep(0.05)
        self.median_window_box = QDoubleSpinBox()
        self.median_window_box.setRange(0.0, 60.0)
        self.median_window_box.setSingleStep(0.05)

        form = QFormLayout(self)
        form.addRow("Name", self.name_box)
        form.addRow("Binding", self.binding)
        form.addRow("Zone / class", self.zone_box)
        form.addRow("Body part", self.body_part_box)
        form.addRow("Speed min, cm/s", self.speed_min_box)
        form.addRow("Speed max, cm/s", self.speed_max_box)
        form.addRow("Min duration, s", self.min_duration_box)
        form.addRow("Bridge gaps up to, s", self.max_gap_box)
        form.addRow("Median window, s", self.median_window_box)

        self.binding.currentTextChanged.connect(self._refill_zone_box)
        for widget in (self.name_box,):
            widget.textChanged.connect(self.changed)
        for widget in (self.binding, self.zone_box, self.body_part_box):
            widget.currentTextChanged.connect(self.changed)
        for widget in (self.speed_min_box, self.speed_max_box,
                       self.min_duration_box, self.max_gap_box,
                       self.median_window_box):
            widget.valueChanged.connect(self.changed)

    # --- inputs from the session ---
    def set_zones(self, zones) -> None:
        self._zones = list(zones or [])
        self._refill_zone_box()

    def set_body_parts(self, names) -> None:
        current = self.body_part_box.currentText()
        self.body_part_box.clear()
        self.body_part_box.addItems([str(n) for n in (names or [])])
        if current:
            self.body_part_box.setCurrentText(current)

    def _refill_zone_box(self) -> None:
        current = self.zone_box.currentText()
        self.zone_box.clear()
        if self.binding.currentText() == ZONE_CLASS:
            classes = []
            for zone in self._zones:
                zone_class = str(getattr(zone, "zone_class", "") or "")
                if zone_class and zone_class not in classes:
                    classes.append(zone_class)
            self.zone_box.addItems(classes)
        else:
            self.zone_box.addItems([str(getattr(z, "name", "")) for z in self._zones])
        if current:
            self.zone_box.setCurrentText(current)

    # --- model <-> form ---
    def is_family(self) -> bool:
        return self.binding.currentText() == ZONE_CLASS

    def family_zone_class(self) -> str:
        return self.zone_box.currentText() if self.is_family() else ""

    @staticmethod
    def _select(box, value) -> bool:
        """Select `value`, adding it if the session does not offer it.

        `setCurrentText` is a no-op for an absent item, which would silently
        swap the act's body part or zone for whatever was selected before and
        then save that under the original name. Keeping the value instead makes
        the mismatch visible."""
        value = str(value or "")
        if not value:
            return True
        if box.findText(value) < 0:
            box.addItem(value)
            box.setCurrentText(value)
            return False
        box.setCurrentText(value)
        return True

    def load_act(self, act) -> None:
        self.missing: list = []
        self.name_box.setText(act.name)
        self.binding.setCurrentText(SINGLE_ZONE)
        self._refill_zone_box()
        if act.zones and not self._select(self.zone_box, act.zones[0]):
            self.missing.append(f'zone "{act.zones[0]}"')
        if act.body_part and not self._select(self.body_part_box, act.body_part):
            self.missing.append(f'body part "{act.body_part}"')
        self.speed_min_box.setValue(float(act.speed_min))
        self.speed_max_box.setValue(
            0.0 if act.speed_max == float("inf") else float(act.speed_max))
        self.min_duration_box.setValue(float(act.min_duration_sec))
        self.max_gap_box.setValue(float(act.max_gap_sec))
        self.median_window_box.setValue(float(act.median_window_sec))

    def to_act(self) -> Act:
        body_part = self.body_part_box.currentText()
        speed_max = self.speed_max_box.value()
        return Act(
            name=self.name_box.text().strip(),
            type="simple",
            zones=[] if self.is_family() else [self.zone_box.currentText()],
            body_part=body_part,
            required_parts=[body_part] if body_part else [],
            speed_min=self.speed_min_box.value(),
            speed_max=float("inf") if speed_max == 0.0 else speed_max,
            min_duration_sec=self.min_duration_box.value(),
            max_gap_sec=self.max_gap_box.value(),
            median_window_sec=self.median_window_box.value(),
        )
