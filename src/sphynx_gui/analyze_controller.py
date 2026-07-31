"""Analyze tab controller (S4a).

The widget holds no engine logic: this object reads AppState, starts the worker
on a thread, and pushes the result into the widget.
"""

from __future__ import annotations

import math

from PySide6.QtCore import QObject, QThread

from sphynx_gui.worker import AnalysisWorker

_ACT_COLUMNS = ("Act", "%", "Episodes", "Duration, s", "Distance, cm", "Speed, cm/s")


def _format(value) -> str:
    if value is None:
        return ""
    if isinstance(value, float):
        return "n/a" if math.isnan(value) else f"{value:.2f}"
    return str(value)


class AnalyzeController(QObject):
    def __init__(self, state, tab, parent=None):
        super().__init__(parent)
        self.state = state
        self.tab = tab
        self._thread = None
        self._worker = None

    def run(self) -> None:
        if not self.state.dlc_path:
            self.tab.set_status("Choose a DLC csv first.")
            return
        if not self.state.preset_path:
            self.tab.set_status("Choose a preset .mat first.")
            return

        self.tab.set_busy(True)
        self.tab.set_status("Analysing session...")

        config = self.state.build_config()
        self._worker = AnalysisWorker(config, paradigm=self.state.paradigm or None)
        self._thread = QThread()
        self._worker.moveToThread(self._thread)
        self._thread.started.connect(self._worker.run)
        self._worker.progress.connect(self.tab.set_status)
        self._worker.finished.connect(self.on_finished)
        self._worker.failed.connect(self.on_failed)
        self._worker.finished.connect(self._thread.quit)
        self._worker.failed.connect(self._thread.quit)
        self._thread.start()

    def on_finished(self, result) -> None:
        self.tab.set_busy(False)
        self.state.result = result
        self.tab.show_result(result)
        acts = len(getattr(result, "acts", []) or [])
        self.tab.set_status(f"Done: {acts} acts over "
                            f"{getattr(result, 'n_frames', 0)} frames.")

    def on_failed(self, message: str) -> None:
        self.tab.set_busy(False)
        self.tab.set_status(f"Failed: {message}")
