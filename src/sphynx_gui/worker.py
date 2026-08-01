"""Run one analysis off the UI thread (S4a).

`run()` is an ordinary synchronous method, so it is testable without a thread;
the window moves the worker into a QThread and calls it there.
"""

from __future__ import annotations

from PySide6.QtCore import QObject, Signal, Slot

from sphynx.exceptions import SphynxError
from sphynx.pipeline.analyze import analyze_session


class AnalysisWorker(QObject):
    finished = Signal(object)     # SessionResult
    failed = Signal(str)
    progress = Signal(str)

    def __init__(self, config, paradigm=None, library=None, parent=None):
        super().__init__(parent)
        self._config = config
        self._paradigm = paradigm
        self._library = library

    @Slot()
    def run(self) -> None:
        self.progress.emit("Analysing session...")
        try:
            result = analyze_session(self._config, paradigm=self._paradigm,
                                     library=self._library)
        except SphynxError as e:
            # An engine refusal is a message for the user, not a crash.
            self.failed.emit(str(e))
            return
        except Exception as e:      # noqa: BLE001 - a bug must not kill the app
            self.failed.emit(f"unexpected {type(e).__name__}: {e}")
            return
        self.finished.emit(result)
