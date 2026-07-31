"""Entry point: `python -m sphynx_gui.app` (S4a)."""

from __future__ import annotations

import sys

from PySide6.QtWidgets import QApplication

from sphynx.paradigms import PARADIGMS, register_builtin_paradigms
from sphynx_gui.main_window import MainWindow


def main(argv=None) -> int:
    if not PARADIGMS:
        register_builtin_paradigms()
    app = QApplication(argv if argv is not None else sys.argv)
    window = MainWindow()
    window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
