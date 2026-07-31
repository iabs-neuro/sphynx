"""Stub for a tab that a later slice fills in (S4a)."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import QLabel, QVBoxLayout, QWidget


class PlaceholderTab(QWidget):
    def __init__(self, title: str, slice_name: str, detail: str = "", parent=None):
        super().__init__(parent)
        self.title = title
        self.slice_name = slice_name

        heading = QLabel(title)
        heading.setAlignment(Qt.AlignCenter)
        font = heading.font()
        font.setPointSize(font.pointSize() + 4)
        font.setBold(True)
        heading.setFont(font)

        note = QLabel(f"Arrives in slice {slice_name}." + (f"\n{detail}" if detail else ""))
        note.setAlignment(Qt.AlignCenter)
        note.setWordWrap(True)

        layout = QVBoxLayout(self)
        layout.addStretch(1)
        layout.addWidget(heading)
        layout.addWidget(note)
        layout.addStretch(1)
