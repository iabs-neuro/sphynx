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

    @property
    def is_running(self) -> bool:
        return self._thread is not None and self._thread.isRunning()

    def run(self) -> None:
        if self.is_running:
            # Starting a second run would drop the only reference to the first
            # worker and kill it mid-analysis.
            self.tab.set_status("An analysis is already running.")
            return
        if not self.state.dlc_path:
            self.tab.set_status("Choose a DLC csv first.")
            return
        if not self.state.preset_path:
            self.tab.set_status("Choose a preset .mat first.")
            return

        self.tab.set_busy(True)
        self.tab.set_status("Analysing session...")

        config = self.state.build_config()
        self._worker = AnalysisWorker(config, paradigm=self.state.paradigm or None,
                                      library=self.state.library)
        self._thread = QThread()
        self._worker.moveToThread(self._thread)
        self._thread.started.connect(self._worker.run)
        self._worker.progress.connect(self.tab.set_status)
        self._worker.finished.connect(self.on_finished)
        self._worker.failed.connect(self.on_failed)
        self._worker.finished.connect(self._thread.quit)
        self._worker.failed.connect(self._thread.quit)
        self._thread.finished.connect(self._on_thread_finished)
        self._thread.start()

    def _on_thread_finished(self) -> None:
        """Release the finished thread and worker once Qt is done with them."""
        if self._worker is not None:
            self._worker.deleteLater()
            self._worker = None
        if self._thread is not None:
            self._thread.deleteLater()
            self._thread = None

    def shutdown(self, timeout_ms: int = 30_000) -> None:
        """Wait for a running analysis before the window goes away.

        Letting Qt destroy a running QThread aborts the whole process, so the
        window calls this from closeEvent."""
        thread = self._thread
        if thread is not None and thread.isRunning():
            thread.quit()
            thread.wait(timeout_ms)

    def on_finished(self, result) -> None:
        self.tab.set_busy(False)
        self.state.result = result
        self.tab.show_result(result)
        acts = len(getattr(result, "acts", []) or [])
        self.tab.set_status(f"Done: {acts} acts over "
                            f"{getattr(result, 'n_frames', 0)} frames.")

    def on_failed(self, message: str) -> None:
        self.tab.set_busy(False)
        # Never leave the previous session's tables and plots on screen under
        # the new paths: a stale result read as a fresh one is a wrong answer.
        self.tab.clear_result()
        self.state.result = None
        self.tab.set_status(f"Failed: {message}")
