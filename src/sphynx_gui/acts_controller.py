"""Define Acts controller (S4b).

Holds the three sources of acts apart -- the built-in speed acts, the acts the
paradigm declares, and the user's library -- so the tab can show where each act
came from and which ones the library replaces. Only library acts are editable;
the other two are shown so the user can see the whole picture and copy from it.
"""

from __future__ import annotations

import numpy as np
from PySide6.QtCore import QObject

from sphynx.acts.apply import apply_act
from sphynx.acts.families import ActFamily
from sphynx.acts.library import acts_library_defaults
from sphynx.acts.library_io import ActLibrary, load_library, save_library
from sphynx.acts.schema import ActContext
from sphynx.acts.stats import act_stats
from sphynx.exceptions import SphynxError
from sphynx.paradigms.registry import resolve_paradigm
from sphynx.plot.etogram import draw_etogram
from sphynx.zones.select import ZoneSelector

BUILTIN, PARADIGM, LIBRARY = "builtin", "paradigm", "library"


def _opt(options, name, default):
    value = getattr(options, name, None) if options is not None else None
    return default if value is None else value


class ActsController(QObject):
    def __init__(self, state, tab, parent=None):
        super().__init__(parent)
        self.state = state
        self.tab = tab
        self.rows: list = []          # (name, source, overridden_by)
        self._selected: str | None = None

    # --- the list ---------------------------------------------------------

    def _library_names(self) -> set:
        library = self.state.library or ActLibrary()
        return ({a.name for a in library.acts}
                | {f.name for f in library.families})

    def refresh_list(self) -> None:
        library_names = self._library_names()
        rows: list = []

        for act in acts_library_defaults():
            rows.append((act.name, BUILTIN,
                         LIBRARY if act.name in library_names else ""))

        try:
            resolved = resolve_paradigm(self.state.paradigm)
        except SphynxError:
            resolved = None
        if resolved is not None:
            for item in list(resolved.families) + list(resolved.acts):
                rows.append((item.name, PARADIGM,
                             LIBRARY if item.name in library_names else ""))

        library = self.state.library or ActLibrary()
        for item in list(library.families) + list(library.acts):
            rows.append((item.name, LIBRARY, ""))

        self.rows = rows
        self.tab.show_rows(rows)

    def select(self, name: str) -> None:
        """Load the selected act into the editor, whatever its source.

        Built-in and paradigm acts are loaded to be read and copied from; only
        library acts can be deleted. Leaving the form showing the PREVIOUS act
        while a different row is highlighted is how a preview ends up
        describing something other than what the user is looking at."""
        self._selected = name
        entry = self._library_entry(name) or self._readonly_entry(name)
        if entry is None:
            return
        act = entry.template if isinstance(entry, ActFamily) else entry
        self.tab.editor.load_act(act)
        if isinstance(entry, ActFamily):
            self.tab.editor.binding.setCurrentText("zone class")
            self.tab.editor.zone_box.setCurrentText(entry.selector.zone_class or "")
        if self.tab.editor.missing:
            self.tab.set_status(
                "This act refers to " + ", ".join(self.tab.editor.missing)
                + ", which the loaded session does not have.")

    def _readonly_entry(self, name):
        """A built-in or paradigm act, so the editor can show it."""
        for act in acts_library_defaults():
            if act.name == name:
                return act
        try:
            resolved = resolve_paradigm(self.state.paradigm)
        except SphynxError:
            return None
        for item in list(resolved.families) + list(resolved.acts):
            if item.name == name:
                return item
        return None

    def _library_entry(self, name):
        library = self.state.library or ActLibrary()
        for item in list(library.acts) + list(library.families):
            if item.name == name:
                return item
        return None

    # --- editing ----------------------------------------------------------

    def add_act(self) -> None:
        act = self.tab.editor.to_act()
        if not act.name:
            self.tab.set_status("Give the act a name before adding it.")
            return
        if not act.body_part:
            self.tab.set_status(
                "Choose a body part. Load a session in Analyze first if the "
                "list is empty -- the choices come from its tracking.")
            return
        if not self.tab.editor.is_family() and not (act.zones and act.zones[0]):
            self.tab.set_status("Choose the zone this act is scored in.")
            return

        library = self.state.library or ActLibrary()
        acts = [a for a in library.acts if a.name != act.name]
        families = [f for f in library.families if f.name != act.name]

        if self.tab.editor.is_family():
            zone_class = self.tab.editor.family_zone_class()
            if not zone_class:
                self.tab.set_status("Choose a zone class for the family.")
                return
            families.append(ActFamily(
                name=act.name, selector=ZoneSelector(zone_class=zone_class),
                template=act))
        else:
            acts.append(act)

        self.state.library = ActLibrary(acts=acts, families=families)
        self.refresh_list()
        self.tab.set_status(f'Act "{act.name}" saved into the library.')

    def delete_selected(self) -> None:
        name = self._selected
        if not name or self._library_entry(name) is None:
            self.tab.set_status(
                "Only acts from your library can be deleted; built-in and "
                "paradigm acts come from elsewhere.")
            return
        library = self.state.library
        self.state.library = ActLibrary(
            acts=[a for a in library.acts if a.name != name],
            families=[f for f in library.families if f.name != name])
        self._selected = None
        self.refresh_list()
        self.tab.set_status(f'Act "{name}" removed from the library.')

    # --- preview ----------------------------------------------------------

    def preview(self) -> None:
        result = self.state.result
        if result is None:
            self.tab.set_preview(
                "Run a session in Analyze first: the preview scores the act on "
                "the loaded session.", None, 0.0)
            return

        act = self.tab.editor.to_act()
        if not act.name:
            self.tab.set_preview("Give the act a name first.", None, 0.0)
            return
        if self.tab.editor.is_family():
            self.tab.set_preview(
                "Preview scores a single zone; pick one to check the act, then "
                "switch back to the zone class.", None, 0.0)
            return

        frame_rate = float(_opt(result.options, "FrameRate", 30.0))
        traces = result.body_parts_traces
        ctx = ActContext(
            X=np.array([t.x_smooth for t in traces], dtype=float),
            Y=np.array([t.y_smooth for t in traces], dtype=float),
            velocity_cm_s=np.array(
                [t.velocity if t.velocity is not None
                 else np.zeros(result.n_frames) for t in traces], dtype=float),
            body_parts=list(result.body_parts_names),
            zones=list(getattr(result, "zones_effective", None)
                       or result.zones or []),
            frame_rate=frame_rate,
            pixels_per_cm=float(_opt(result.options, "pxl2sm", 1.0)),
        )
        try:
            mask = apply_act(act, ctx)
        except SphynxError as e:
            self.tab.set_preview(f"Cannot score this act: {e}", None, 0.0)
            return

        stats = act_stats(mask, frame_rate)
        degraded = ctx.degraded.get(act.name)
        # The preview scores the frames that are loaded, not the whole file:
        # saying so keeps it from disagreeing with the Analyze table.
        text = (f"{stats.percent:.2f}% | episodes: {stats.count} | "
                f"{stats.duration_s:.1f} s "
                f"(preview over {result.n_frames} loaded frames)")
        if degraded:
            text += "\ndegraded: " + "; ".join(degraded)
        self.tab.set_preview(text, (act.name, mask), frame_rate)

    # --- library files ----------------------------------------------------

    def save_library(self, path) -> None:
        try:
            written = save_library(self.state.library or ActLibrary(), path)
        except SphynxError as e:
            self.tab.set_status(f"Could not save: {e}")
            return
        self.tab.set_status(f"Library saved to {written}")

    def load_library(self, path) -> None:
        try:
            self.state.library = load_library(path)
        except SphynxError as e:
            self.tab.set_status(f"Could not load: {e}")
            return
        self.refresh_list()
        self.tab.set_status(f"Library loaded from {path}")


def draw_preview_etogram(axes, named_mask, frame_rate) -> None:
    """One-row etogram for the previewed act."""
    if named_mask is None:
        axes.clear()
        return
    name, mask = named_mask

    class _One:
        pass

    act = _One()
    act.name = name
    act.array = np.asarray(mask, dtype=float)
    draw_etogram(axes, [act], frame_rate)
