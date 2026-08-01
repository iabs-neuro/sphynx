"""The project's sessions as an editable table (S4c).

Two columns exist purely so nothing is decided invisibly: `From` says where a
session's preset came from -- a rule, a hand-typed path, or nowhere -- and
`Status` says whether the row can run at all. A preset chosen by a rule the user
cannot see would be the silent substitution the engine refuses everywhere else.
"""

from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import Qt
from PySide6.QtWidgets import QAbstractItemView, QTableWidget, QTableWidgetItem

from sphynx.project.presets import resolve_preset
from sphynx.project.scan import session_is_parsed

COLUMNS = ("Session", "Mouse", "Group", "Line", "Day", "Preset", "From", "Status")
_EDITABLE = {"Mouse": "mouse", "Group": "group", "Line": "line", "Day": "day"}


class SessionsTable(QTableWidget):
    def __init__(self, parent=None):
        super().__init__(0, len(COLUMNS), parent)
        self.setHorizontalHeaderLabels(list(COLUMNS))
        self.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.rows: list = []

    # --- filling ----------------------------------------------------------
    def show_project(self, project) -> None:
        sessions = list(getattr(project, "sessions", []) or [])
        rules = list(getattr(project, "preset_rules", []) or [])
        self.rows = []
        self.setRowCount(len(sessions))

        for row, session in enumerate(sessions):
            assignment = resolve_preset(session, rules)
            metadata = session.metadata or {}
            status = self._status(session, assignment)
            self.rows.append({
                "name": session.name,
                "preset": assignment.preset_path,
                "source": assignment.source,
                "status": status,
            })
            values = (
                session.name,
                metadata.get("mouse", ""),
                metadata.get("group", ""),
                metadata.get("line", ""),
                metadata.get("day", ""),
                assignment.preset_path,
                assignment.source,
                status,
            )
            for column, value in enumerate(values):
                item = QTableWidgetItem(str(value))
                if COLUMNS[column] not in _EDITABLE:
                    item.setFlags(item.flags() & ~Qt.ItemIsEditable)
                self.setItem(row, column, item)

    @staticmethod
    def _status(session, assignment) -> str:
        if not session.dlc_path:
            return "no DLC file"
        if not Path(session.dlc_path).is_file():
            # A stored path goes stale when files move; saying "ready" for a
            # file that is not there would only fail at run time.
            return "DLC file missing"
        if not assignment.preset_path:
            return "no preset assigned"
        if not session_is_parsed(session):
            return "name not parsed"
        return "ready"

    # --- reading back -----------------------------------------------------
    def selected_names(self) -> list:
        names = []
        for index in self.selectionModel().selectedRows():
            item = self.item(index.row(), 0)
            if item is not None:
                names.append(item.text())
        return names

    def apply_edits(self, project) -> None:
        """Write the editable metadata cells back into the project."""
        by_name = {s.name: s for s in getattr(project, "sessions", []) or []}
        for row in range(self.rowCount()):
            name_item = self.item(row, 0)
            if name_item is None:
                continue
            session = by_name.get(name_item.text())
            if session is None:
                continue
            for column, title in enumerate(COLUMNS):
                key = _EDITABLE.get(title)
                if key is None:
                    continue
                item = self.item(row, column)
                text = item.text().strip() if item is not None else ""
                if text:
                    session.metadata[key] = text
                else:
                    session.metadata.pop(key, None)
