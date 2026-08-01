"""Make Output controller (S4c2).

Reads the last batch, offers what it actually produced, and writes the two
tables out. Nothing here invents a column: the lists come from the run, and a
metric that failed keeps its row with the reason attached.
"""

from __future__ import annotations

from PySide6.QtCore import QObject

from sphynx.exceptions import SphynxError
from sphynx.pipeline.output import (
    OutputSelection,
    available_columns,
    export_tables,
    filter_tidy,
    wide_column_count,
)

_KEYS = ("acts", "act_stats", "named_metrics")


class OutputController(QObject):
    def __init__(self, state, tab, parent=None):
        super().__init__(parent)
        self.state = state
        self.tab = tab
        self.available: dict = {key: [] for key in _KEYS}

    # --- reading the run --------------------------------------------------

    def _tidy(self):
        batch = self.state.batch
        return None if batch is None else batch.tidy

    def refresh(self) -> None:
        tidy = self._tidy()
        if tidy is None:
            self.available = {key: [] for key in _KEYS}
            self.tab.show_available(self.available, {})
            self.tab.set_status(
                "Run a batch first: the columns on offer come from what the "
                "run measured.")
            self.tab.set_count("")
            return

        self.available = available_columns(tidy)
        stored = dict(getattr(self.state.project, "output_selection", {}) or {})
        self.tab.show_available(self.available, stored)
        self.tab.set_status("")
        self.preview()

    def selection(self) -> OutputSelection:
        chosen = self.tab.checked_names()
        return OutputSelection(
            acts=list(chosen.get("acts", [])),
            act_stats=list(chosen.get("act_stats", [])),
            named_metrics=list(chosen.get("named_metrics", [])),
        )

    def remember_selection(self) -> None:
        """Keep the ticks in the project so they survive the next open.

        Names the current run did not offer are kept rather than pruned: a
        selection narrowed for a Barnes project would otherwise be emptied by
        one Open Field run, and an empty selection means EVERYTHING -- so the
        next export would quietly widen instead of staying narrow."""
        ticked = self.tab.checked_names()
        stored = dict(getattr(self.state.project, "output_selection", {}) or {})
        merged = {}
        for key in _KEYS:
            offered = set(self.available.get(key, []))
            kept = [n for n in stored.get(key, []) or [] if n not in offered]
            merged[key] = list(ticked.get(key, [])) + kept
        self.state.project.output_selection = merged

    # --- preview and export ----------------------------------------------

    def preview(self) -> None:
        tidy = self._tidy()
        if tidy is None:
            self.tab.set_status("Nothing to preview until a batch has run.")
            return
        selection = self.selection()
        self.remember_selection()
        kept = filter_tidy(tidy, selection)
        columns = wide_column_count(tidy, selection)
        total = wide_column_count(tidy, OutputSelection())
        empty = not any(self.tab.checked_names().values())
        self.tab.set_count(
            f"{columns} value column(s) in the wide table, of {total} available"
            + (" (nothing ticked means everything)" if empty else ""))
        self.tab.show_tables(kept, self._wide(kept))

    def _wide(self, tidy):
        from sphynx.pipeline.batch import _tidy_to_wide

        return _tidy_to_wide(tidy)

    def export(self, path, fmt: str = "csv") -> None:
        tidy = self._tidy()
        if tidy is None:
            self.tab.set_status("Nothing to export until a batch has run.")
            return
        kept = filter_tidy(tidy, self.selection())
        try:
            written = export_tables(kept, self._wide(kept), path, fmt=fmt)
        except SphynxError as e:
            self.tab.set_status(f"Export failed: {e}")
            return
        self.tab.set_status("Written: " + ", ".join(written))
