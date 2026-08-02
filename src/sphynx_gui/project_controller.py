"""Create, open and configure a project (S4f).

The project is a folder with a fixed layout, and it is the one place the
paradigm, the acts library and the working folders live. Everything here is
engine calls: the widget holds no path logic.
"""

from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import QObject

from sphynx.exceptions import SphynxError
from sphynx.project import Project, save_project
from sphynx.project.io import load_project_detailed
from sphynx.project.model import folder
from sphynx.project.paths import LAYOUT, create_layout, import_file, is_external, resolve_path
from sphynx.project.scan import parse_session_name, session_name_from_file
from sphynx.project.model import ProjectSession

PROJECT_FILE = "project.json"

# What each kind of imported file is, in the terms the user picked them by.
_KINDS = {"tracking": "tracking", "raw_videos": "video"}


class ProjectController(QObject):
    def __init__(self, state, tab, parent=None):
        super().__init__(parent)
        self.state = state
        self.tab = tab

    # --- the project file -------------------------------------------------
    def new_project(self, root) -> None:
        """Make the folder layout and a project file inside `root`."""
        base = Path(root).expanduser()
        target = base / PROJECT_FILE
        if target.exists():
            # Overwriting would throw away someone's sessions and rules with
            # no way back. Opening it is what they almost certainly meant.
            self.tab.set_status(
                f"{target} already exists. Use Open to load that project, or "
                "choose an empty folder.")
            return
        try:
            states = create_layout(base)
            project = Project(name=base.name, root=str(base.resolve()))
            save_project(project, target)
        except SphynxError as e:
            self.tab.set_status(str(e))
            return
        self.state.project = project
        made = [name for name, how in states.items() if how == "created"]
        self.tab.set_status(
            f"Created {target}" + (f"; folders: {', '.join(made)}" if made
                                   else "; the folders were already there"))

    def open_project(self, path) -> None:
        """Open a project.json, or a folder that holds one."""
        source = Path(path).expanduser()
        if source.is_dir():
            source = source / PROJECT_FILE
        if not source.is_file():
            self.tab.set_status(f"No {PROJECT_FILE} at {source}.")
            return
        try:
            loaded = load_project_detailed(source)
            states = create_layout(Path(loaded.project.root))
        except SphynxError as e:
            self.tab.set_status(str(e))
            return

        self.state.project = loaded.project
        made = [name for name, how in states.items() if how == "created"]
        note = f" Missing folders were created: {', '.join(made)}." if made else ""
        if loaded.upgraded_from is not None:
            # The file on disk is untouched. Saying so, and marking the
            # project unsaved, leaves the rewrite to the user.
            self.state.mark_project_dirty()
            self.tab.set_status(
                f"Opened {source}, written by an older version "
                f"(schema {loaded.upgraded_from}). It was upgraded in memory "
                "only; its paths all count as outside the project until you "
                "save it here." + note)
        else:
            self.tab.set_status(f"Opened {source}.{note}")

    def save(self) -> None:
        project = self.state.project
        if not project.root:
            self.tab.set_status(
                "This project has no folder yet. Use 'Save as...' to choose one.")
            return
        try:
            written = save_project(project, Path(project.root) / PROJECT_FILE)
        except SphynxError as e:
            self.tab.set_status(str(e))
            return
        self.state.clear_project_dirty()
        self.tab.set_status(f"Saved {written}.")

    def save_as(self, root) -> None:
        """Move the project to another folder, keeping its contents.

        Paths stored relative to the OLD root are resolved before the move and
        stored again against the new one, so a Save as does not silently
        repoint every session at a folder that has none of the files."""
        base = Path(root).expanduser()
        project = self.state.project
        old_root = project.root
        try:
            create_layout(base)
        except SphynxError as e:
            self.tab.set_status(str(e))
            return
        for session in project.sessions:
            session.dlc_path = resolve_path(session.dlc_path, old_root)
            session.preset_path = resolve_path(session.preset_path, old_root)
            session.video_path = resolve_path(session.video_path, old_root)
        for rule in project.preset_rules:
            rule.preset_path = resolve_path(rule.preset_path, old_root)
        if project.library_path:
            project.library_path = resolve_path(project.library_path, old_root)
        project.root = str(base.resolve())
        self.state.project = project
        self.save()

    # --- settings ---------------------------------------------------------
    def set_paradigm(self, name: str) -> None:
        self.state.paradigm = str(name or "")

    def set_library(self, path: str) -> None:
        self.state.library_path = str(path or "")

    def set_name(self, name: str) -> None:
        if str(name) != self.state.project.name:
            self.state.project.name = str(name)
            self.state.mark_project_dirty()

    # --- data -------------------------------------------------------------
    def add_files(self, paths, kind: str, copy: bool) -> None:
        """Bring videos or tracking files into the project.

        Copying puts the file in the project's folder and stores it relative;
        linking leaves it where it is and stores it absolute, which is what
        marks the row as outside the project."""
        if kind not in _KINDS:
            self.tab.set_status(
                f"Unknown kind of file {kind!r}; expected one of {tuple(_KINDS)}.")
            return
        project = self.state.project
        if not project.root:
            self.tab.set_status("Create or open a project first.")
            return

        added, failed, external = [], [], 0
        for path in paths:
            try:
                stored = import_file(path, project.root, kind, copy=copy)
            except SphynxError as e:
                failed.append(str(e))
                continue
            if is_external(stored):
                external += 1
            if kind == "tracking":
                self._add_session(project, stored)
            else:
                self._attach_video(project, stored)
            added.append(stored)

        if added:
            self.state.project = project
            self.state.mark_project_dirty()
        outside = f", {external} left outside the project" if external else ""
        trouble = f"; {len(failed)} failed: {failed[0]}" if failed else ""
        self.tab.set_status(
            f"Added {len(added)} {_KINDS[kind]} file(s){outside}{trouble}.")

    def _add_session(self, project, stored) -> None:
        name = session_name_from_file(Path(stored).stem)
        known = {s.name for s in project.sessions}
        if any(s.dlc_path == stored for s in project.sessions):
            return                    # already in the project
        unique, suffix = name, 2
        while unique in known:
            unique = f"{name} ({suffix})"
            suffix += 1
        project.sessions.append(ProjectSession(
            name=unique, dlc_path=stored,
            metadata=parse_session_name(name, project.name_pattern)))

    def _attach_video(self, project, stored) -> None:
        """Give the clip to the session it belongs to, if there is one.

        A video with no matching session is not dropped: the file is in the
        project folder either way, and Create Preset will find it there."""
        stem = session_name_from_file(Path(stored).stem)
        for session in project.sessions:
            if session.name == stem and not session.video_path:
                session.video_path = stored
                return

    def create_library(self) -> None:
        """An empty acts library in the project root, so there is one to fill."""
        from sphynx.acts.library_io import ActLibrary, save_library

        project = self.state.project
        if not project.root:
            self.tab.set_status("Create or open a project first.")
            return
        target = Path(project.root) / "acts_library.json"
        if target.exists():
            self.tab.set_status(f"{target} already exists; pointing at it.")
        else:
            try:
                save_library(ActLibrary(), target)
            except SphynxError as e:
                self.tab.set_status(str(e))
                return
            self.tab.set_status(f"Created {target}.")
        self.set_library(str(target))

    # --- what the tab shows ----------------------------------------------
    def folders(self) -> list:
        """(name, path, state) per project folder."""
        rows = []
        project = self.state.project
        for name in LAYOUT:
            path = folder(project, name)
            if not path:
                state = "no project"
            elif Path(path).is_dir():
                state = "ok"
            elif Path(path).exists():
                state = "not a folder"
            else:
                state = "missing"
            rows.append((name, path, state))
        return rows

    def report(self) -> list:
        """Warning rows: what about this project would not survive a move."""
        project = self.state.project
        if not project.root:
            return [("project", "warning",
                     "No project is open, so the tabs will ask for every path.")]
        rows = []
        missing, external = [], 0
        for session in project.sessions:
            for label in ("dlc_path", "preset_path", "video_path"):
                stored = getattr(session, label, "")
                if not stored:
                    continue
                if is_external(stored):
                    external += 1
                if not Path(resolve_path(stored, project.root)).exists():
                    missing.append(f"{session.name}: {label}")
        if missing:
            rows.append(("sessions", "error",
                         f"{len(missing)} file(s) named by the project are not "
                         f"there, e.g. {missing[0]}"))
        if external:
            rows.append(("sessions", "warning",
                         f"{external} path(s) point outside the project folder, "
                         "so copying the folder elsewhere will not bring them"))
        for name, path, state in self.folders():
            if state not in ("ok", "no project"):
                rows.append(("folders", "error", f"{name}: {path} is {state}"))
        if not project.sessions:
            rows.append(("sessions", "warning",
                         "The project has no sessions yet: add tracking files, "
                         "or scan a folder from the Batch tab."))
        return rows
