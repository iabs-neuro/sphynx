"""Make Output tab: pick the columns, see both tables, write them out (S4c2)."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QFileDialog, QGroupBox, QHBoxLayout, QLabel, QListWidget, QListWidgetItem,
    QPushButton, QSplitter, QTabWidget, QTableWidget, QTableWidgetItem,
    QVBoxLayout, QWidget,
)

from sphynx_gui.output_controller import OutputController

_PREVIEW_ROWS = 200
_LIST_TITLES = {"acts": "Acts", "act_stats": "Act statistics",
                "named_metrics": "Named metrics"}


class OutputTab(QWidget):
    def __init__(self, state, parent=None):
        super().__init__(parent)
        self.state = state
        self.controller = OutputController(state, self)
        self._build_ui()
        self._connect()
        self.controller.refresh()

    # --- construction -----------------------------------------------------
    def _build_ui(self) -> None:
        self.acts_list = QListWidget()
        self.stats_list = QListWidget()
        self.metrics_list = QListWidget()
        self._lists = {"acts": self.acts_list, "act_stats": self.stats_list,
                       "named_metrics": self.metrics_list}

        picks = QWidget()
        picks_layout = QHBoxLayout(picks)
        picks_layout.setContentsMargins(0, 0, 0, 0)
        for key, widget in self._lists.items():
            box = QGroupBox(_LIST_TITLES[key])
            box_layout = QVBoxLayout(box)
            box_layout.addWidget(widget)
            picks_layout.addWidget(box)

        self.count_label = QLabel("")
        self.count_label.setWordWrap(True)
        self.status_label = QLabel("")
        self.status_label.setWordWrap(True)
        self.export_csv_button = QPushButton("Export CSV...")
        self.export_excel_button = QPushButton("Export Excel...")

        actions = QWidget()
        actions_layout = QHBoxLayout(actions)
        actions_layout.setContentsMargins(0, 0, 0, 0)
        actions_layout.addWidget(self.export_csv_button)
        actions_layout.addWidget(self.export_excel_button)
        actions_layout.addWidget(self.count_label, 1)

        self.tidy_preview = QTableWidget(0, 0)
        self.wide_preview = QTableWidget(0, 0)
        previews = QTabWidget()
        previews.addTab(self.tidy_preview, "Long (tidy)")
        previews.addTab(self.wide_preview, "Wide")

        top = QWidget()
        top_layout = QVBoxLayout(top)
        top_layout.addWidget(picks)
        top_layout.addWidget(actions)
        top_layout.addWidget(self.status_label)

        splitter = QSplitter(Qt.Vertical)
        splitter.addWidget(top)
        splitter.addWidget(previews)
        splitter.setSizes([300, 520])

        layout = QVBoxLayout(self)
        layout.addWidget(splitter)

    def _connect(self) -> None:
        for widget in self._lists.values():
            widget.itemChanged.connect(self._on_tick)
        self.export_csv_button.clicked.connect(lambda: self._pick_export("csv"))
        self.export_excel_button.clicked.connect(
            lambda: self._pick_export("excel"))
        self.state.batch_changed.connect(self.controller.refresh)
        # Opening another project must not leave the previous project's
        # ticks on screen, ready to be written over the new one.
        self.state.project_changed.connect(self.controller.refresh)

    # --- controller callbacks --------------------------------------------
    def show_available(self, available, stored) -> None:
        self._loading = True
        for key, widget in self._lists.items():
            widget.clear()
            ticked = set(stored.get(key, []) or [])
            for name in available.get(key, []):
                item = QListWidgetItem(str(name))
                item.setFlags(item.flags() | Qt.ItemIsUserCheckable)
                item.setCheckState(Qt.Checked if name in ticked else Qt.Unchecked)
                widget.addItem(item)
        self._loading = False

    def checked_names(self) -> dict:
        out = {}
        for key, widget in self._lists.items():
            out[key] = [widget.item(i).text() for i in range(widget.count())
                        if widget.item(i).checkState() == Qt.Checked]
        return out

    def set_count(self, text: str) -> None:
        self.count_label.setText(text)

    def set_status(self, text: str) -> None:
        self.status_label.setText(text)

    def show_tables(self, tidy, wide) -> None:
        self._fill(self.tidy_preview, tidy)
        self._fill(self.wide_preview, wide)

    @staticmethod
    def _fill(table, frame) -> None:
        if frame is None or getattr(frame, "empty", True):
            table.setRowCount(0)
            table.setColumnCount(0)
            return
        shown = frame.head(_PREVIEW_ROWS)
        table.setColumnCount(len(shown.columns))
        table.setHorizontalHeaderLabels([str(c) for c in shown.columns])
        table.setRowCount(len(shown))
        for row in range(len(shown)):
            for column in range(len(shown.columns)):
                value = shown.iat[row, column]
                table.setItem(row, column, QTableWidgetItem(str(value)))

    # --- slots ------------------------------------------------------------
    def _on_tick(self, _item=None) -> None:
        if getattr(self, "_loading", False):
            return
        self.controller.preview()

    def _pick_export(self, fmt: str) -> None:
        if fmt == "excel":
            path, _ = QFileDialog.getSaveFileName(self, "Export Excel", "",
                                                  "Excel files (*.xlsx)")
        else:
            path, _ = QFileDialog.getSaveFileName(self, "Export CSV", "",
                                                  "CSV files (*.csv)")
        if path:
            self.controller.export(path, fmt)
