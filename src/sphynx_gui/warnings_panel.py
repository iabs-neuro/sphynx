"""The section-10 surface: everything the engine refused to guess (S4a).

Three sources in one place -- paradigm validation, degraded acts and metric
failures. An empty panel is a real signal, not an absence of information, so it
says so explicitly.
"""

from __future__ import annotations

from PySide6.QtWidgets import QGroupBox, QListWidget, QVBoxLayout

_PREFIX = {"error": "[!]", "warning": "[?]", "info": "[i]"}


class WarningsPanel(QGroupBox):
    def __init__(self, parent=None):
        super().__init__("Warnings", parent)
        self.rows: list = []
        self.list_widget = QListWidget()
        layout = QVBoxLayout(self)
        layout.addWidget(self.list_widget)
        self._render()

    def clear(self) -> None:
        self.rows = []
        self._render()

    def show_rows(self, rows) -> None:
        """Show (source, level, text) rows straight, for callers that have no
        SessionResult -- marking a preset happens before any analysis."""
        self.rows = [(str(s), str(l), str(t)) for s, l, t in rows]
        self._render()

    def show_result(self, result) -> None:
        rows: list = []

        report = getattr(result, "validation", None)
        if report is not None:
            for issue in report.issues:
                rows.append(("validation", issue.level,
                             f"{issue.code}: {issue.message}"))

        for act_name, reasons in (getattr(result, "degraded", None) or {}).items():
            rows.append(("act", "warning",
                         f"{act_name}: " + "; ".join(reasons)))

        metrics = getattr(result, "metrics", None)
        if metrics is not None:
            for name, message in metrics.errors.items():
                rows.append(("metric", "error", f"{name}: {message}"))

        self.rows = rows
        self._render()

    def _render(self) -> None:
        self.list_widget.clear()
        if not self.rows:
            self.list_widget.addItem("No warnings: nothing was left unresolved.")
            return
        for source, level, text in self.rows:
            self.list_widget.addItem(
                f"{_PREFIX.get(level, '[i]')} {source}: {text}")
