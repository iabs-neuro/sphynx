"""Application-wide state (S4a).

One object holds the paths, the chosen paradigm and the last result, and every
tab subscribes to it. In the MATLAB app each tab loaded its own paths, which is
the "app-wide state" complaint in docs/TODO.md.
"""

from __future__ import annotations

import copy
import tomllib
from pathlib import Path

import tomli_w
from PySide6.QtCore import QObject, Signal

from sphynx.acts.library_io import ActLibrary
from sphynx.config import Config
from sphynx.project import Project
from sphynx.project.model import folder
from sphynx.exceptions import SphynxIOError


class AppState(QObject):
    paths_changed = Signal()
    paradigm_changed = Signal()
    result_changed = Signal()
    library_changed = Signal()
    project_changed = Signal()
    project_dirty_changed = Signal()
    batch_changed = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._dlc_path = ""
        self._preset_path = ""
        self._out_dir = ""
        self._result = None
        self._library = ActLibrary()
        self._project = Project()
        self._project_dirty = False
        self._batch = None
        self._config = Config.default()
        self.end_frame = 0
        self.heatmap_bin_cm = 4.0

    # --- paths ---
    @property
    def dlc_path(self) -> str:
        return self._dlc_path

    @dlc_path.setter
    def dlc_path(self, value: str) -> None:
        value = str(value or "")
        if value != self._dlc_path:
            self._dlc_path = value
            self.paths_changed.emit()

    @property
    def preset_path(self) -> str:
        return self._preset_path

    @preset_path.setter
    def preset_path(self, value: str) -> None:
        value = str(value or "")
        if value != self._preset_path:
            self._preset_path = value
            self.paths_changed.emit()

    @property
    def out_dir(self) -> str:
        return self._out_dir

    @out_dir.setter
    def out_dir(self, value: str) -> None:
        value = str(value or "")
        if value != self._out_dir:
            self._out_dir = value
            self.paths_changed.emit()

    # --- settings the project owns ---
    # These used to be fields here as well as on the project, so the same
    # setting had two values and which one reached the analysis depended on
    # which tab started it. The project is the only copy now.
    @property
    def paradigm(self) -> str:
        return self._project.paradigm

    @paradigm.setter
    def paradigm(self, value: str) -> None:
        value = str(value or "")
        if value != self._project.paradigm:
            self._project.paradigm = value
            self.mark_project_dirty()
            self.paradigm_changed.emit()

    @property
    def library_path(self) -> str:
        return self._project.library_path

    @library_path.setter
    def library_path(self, value: str) -> None:
        value = str(value or "")
        if value != self._project.library_path:
            self._project.library_path = value
            self.mark_project_dirty()
            self.library_changed.emit()

    def project_folder(self, which: str) -> str:
        """One of the project's folders, or "" when there is no project.

        Empty is a state the tabs handle: without a project they behave as
        they did before, starting their dialogs wherever the OS last was."""
        return folder(self._project, which)

    # --- unsaved changes ---
    @property
    def project_dirty(self) -> bool:
        return self._project_dirty

    def mark_project_dirty(self) -> None:
        if not self._project_dirty:
            self._project_dirty = True
            self.project_dirty_changed.emit()

    def clear_project_dirty(self) -> None:
        if self._project_dirty:
            self._project_dirty = False
            self.project_dirty_changed.emit()

    # --- result ---
    @property
    def result(self):
        return self._result

    @result.setter
    def result(self, value) -> None:
        self._result = value
        self.result_changed.emit()

    @property
    def library(self):
        return self._library

    @library.setter
    def library(self, value) -> None:
        self._library = value if value is not None else ActLibrary()
        self.library_changed.emit()

    @property
    def project(self):
        return self._project

    @project.setter
    def project(self, value) -> None:
        self._project = value if value is not None else Project()
        # A project that has just been loaded or created matches its file.
        self.clear_project_dirty()
        self.project_changed.emit()
        self.paradigm_changed.emit()
        self.library_changed.emit()

    @property
    def batch(self):
        return self._batch

    @batch.setter
    def batch(self, value) -> None:
        self._batch = value
        self.batch_changed.emit()

    def build_config(self) -> Config:
        """A fresh Config for one run; the state's own config is never handed out."""
        config = copy.deepcopy(self._config)
        config.paths.dlc = self._dlc_path
        config.paths.preset = self._preset_path
        config.paths.out_dir = self._out_dir
        config.frames.end_frame = int(self.end_frame or 0)
        config.io.save_workspace = False
        return config

    # --- settings ---
    def save_settings(self, path) -> str:
        """Write paths, paradigm and view options to one TOML file."""
        data = {
            "paths": {"dlc": self._dlc_path, "preset": self._preset_path,
                      "out_dir": self._out_dir},
            "analysis": {"paradigm": self.paradigm,
                         "end_frame": int(self.end_frame or 0),
                         "heatmap_bin_cm": float(self.heatmap_bin_cm)},
        }
        target = Path(path)
        try:
            target.parent.mkdir(parents=True, exist_ok=True)
            with open(target, "wb") as handle:
                tomli_w.dump(data, handle)
        except OSError as e:
            raise SphynxIOError(f"cannot write settings to {target}: {e}") from e
        return str(target)

    def load_settings(self, path) -> None:
        source = Path(path)
        if not source.is_file():
            raise SphynxIOError(f"settings file not found: {source}")
        try:
            with open(source, "rb") as handle:
                data = tomllib.load(handle)
        except tomllib.TOMLDecodeError as e:
            raise SphynxIOError(f"malformed settings TOML in {source}: {e}") from e
        except OSError as e:
            raise SphynxIOError(f"cannot read settings from {source}: {e}") from e

        paths = data.get("paths", {})
        analysis = data.get("analysis", {})
        self.dlc_path = paths.get("dlc", "")
        self.preset_path = paths.get("preset", "")
        self.out_dir = paths.get("out_dir", "")
        self.paradigm = analysis.get("paradigm", "OF")
        self.end_frame = int(analysis.get("end_frame", 0))
        self.heatmap_bin_cm = float(analysis.get("heatmap_bin_cm", 4.0))
