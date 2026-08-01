"""Batch controller (S4c).

Runs the project off the UI thread, one session at a time, and keeps going when
a session fails: an unreadable file should cost that row, not the run. Every
outcome lands somewhere visible -- a result, an error, or a blocked-row reason.
"""

from __future__ import annotations

from PySide6.QtCore import QObject, QThread, Signal, Slot

from sphynx.exceptions import SphynxError
from sphynx.project import load_project, save_project
from sphynx.project.presets import runnable_sessions
from sphynx.project.run import run_project
from sphynx.project.scan import scan_folder


class BatchWorker(QObject):
    """Runs one project. `run()` is synchronous so it is testable without a
    thread; the controller moves it onto one."""

    finished = Signal(object)
    failed = Signal(str)
    progress = Signal(int, int, str)

    def __init__(self, project, config=None, parent=None):
        super().__init__(parent)
        self._project = project
        self._config = config
        self._stop = False

    def stop(self) -> None:
        self._stop = True

    @Slot()
    def run(self) -> None:
        try:
            result = run_project(
                self._project, config=self._config,
                on_progress=lambda i, n, name: self.progress.emit(i, n, name),
                should_stop=lambda: self._stop)
        except SphynxError as e:
            self.failed.emit(str(e))
            return
        except Exception as e:              # noqa: BLE001 - a bug must not kill the app
            self.failed.emit(f"unexpected {type(e).__name__}: {e}")
            return
        self.finished.emit(result)


class BatchController(QObject):
    def __init__(self, state, tab, parent=None):
        super().__init__(parent)
        self.state = state
        self.tab = tab
        self._thread = None
        self._worker = None

    @property
    def is_running(self) -> bool:
        return self._thread is not None and self._thread.isRunning()

    # --- project ----------------------------------------------------------

    def refresh(self) -> None:
        self.tab.table.show_project(self.state.project)
        ready, blocked = runnable_sessions(self.state.project)
        self.tab.set_status(
            f"{len(ready)} session(s) ready, {len(blocked)} blocked.")

    def scan(self, folder) -> None:
        project = self.state.project
        try:
            sessions = scan_folder(folder, pattern=project.name_pattern,
                                   existing=project.sessions)
        except SphynxError as e:
            self.tab.set_status(f"Scan failed: {e}")
            return
        project.sessions = sessions
        self.state.project = project
        self.refresh()

    def assign_preset_to_selected(self, path) -> None:
        names = set(self.tab.table.selected_names())
        if not names:
            self.tab.set_status(
                "Select the rows first, or add a rule to cover them all.")
            return
        project = self.state.project
        for session in project.sessions:
            if session.name in names:
                session.preset_path = str(path)
        self.state.project = project
        self.refresh()

    def add_preset_rule(self, path, match) -> None:
        from sphynx.project import PresetRule

        project = self.state.project
        project.preset_rules.append(PresetRule(preset_path=str(path),
                                               match=dict(match or {})))
        self.state.project = project
        self.refresh()

    def open_project(self, path) -> None:
        try:
            self.state.project = load_project(path)
        except SphynxError as e:
            self.tab.set_status(f"Could not open: {e}")
            return
        # A project carries the paradigm and library the runs were made with.
        self.state.paradigm = self.state.project.paradigm or self.state.paradigm
        self.refresh()

    def save_project(self, path) -> None:
        self.tab.table.apply_edits(self.state.project)
        self.state.project.paradigm = self.state.paradigm
        try:
            written = save_project(self.state.project, path)
        except SphynxError as e:
            self.tab.set_status(f"Could not save: {e}")
            return
        self.tab.set_status(f"Project saved to {written}")

    # --- running ----------------------------------------------------------

    def run(self) -> None:
        if self.is_running:
            self.tab.set_status("A batch is already running.")
            return
        self.tab.table.apply_edits(self.state.project)
        ready, blocked = runnable_sessions(self.state.project)
        if not ready:
            reasons = "; ".join(f"{s.name}: {why}" for s, why in blocked[:3])
            self.tab.set_status(
                "Nothing to run. " + (reasons or "Add sessions first."))
            return

        self.tab.set_busy(True)
        self.tab.set_status(f"Running {len(ready)} session(s)...")

        self._worker = BatchWorker(self.state.project, self.state.build_config())
        self._thread = QThread()
        self._worker.moveToThread(self._thread)
        self._thread.started.connect(self._worker.run)
        self._worker.progress.connect(self.on_progress)
        self._worker.finished.connect(self.on_finished)
        self._worker.failed.connect(self.on_failed)
        self._worker.finished.connect(self._thread.quit)
        self._worker.failed.connect(self._thread.quit)
        self._thread.finished.connect(self._on_thread_finished)
        self._thread.start()

    def cancel(self) -> None:
        if self._worker is not None:
            self._worker.stop()
            self.tab.set_status("Stopping after the current session...")

    def shutdown(self, timeout_ms: int = 60_000) -> None:
        thread = self._thread
        if self._worker is not None:
            self._worker.stop()
        if thread is not None and thread.isRunning():
            thread.quit()
            thread.wait(timeout_ms)

    def _on_thread_finished(self) -> None:
        if self._worker is not None:
            self._worker.deleteLater()
            self._worker = None
        if self._thread is not None:
            self._thread.deleteLater()
            self._thread = None

    def on_progress(self, index, total, name) -> None:
        self.tab.set_progress(f"Session {index} of {total}: {name}")

    def on_finished(self, batch) -> None:
        self.tab.set_busy(False)
        self.tab.show_batch(batch)
        done = len(batch.results)
        failed = len(batch.errors)
        self.tab.set_status(
            f"Done: {done} session(s) analysed"
            + (f", {failed} failed (listed in the warnings)." if failed else "."))

    def on_failed(self, message: str) -> None:
        self.tab.set_busy(False)
        self.tab.clear_results()
        self.tab.set_status(f"Batch failed: {message}")
