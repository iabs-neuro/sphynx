"""Create Preset controller (S4d).

Turns the shapes drawn on the canvas into zones, checks them against the chosen
paradigm, and writes the preset. The widget holds no geometry: everything here
is engine calls.
"""

from __future__ import annotations

import math
from types import SimpleNamespace

import numpy as np
from PySide6.QtCore import QObject

from sphynx.exceptions import SphynxError
from sphynx.io.preset_write import options_struct, save_preset
from sphynx.io.video import read_frame, video_info
from sphynx.paradigms import resolve_paradigm, validate_paradigm
from sphynx.preset.objects import build_object_zones
from sphynx.zones import (
    Zone, assign_zone_angles, classify_circle, classify_square,
    resolve_arena_center,
)
from sphynx_gui.preset_canvas import shape_vertices

DEFAULT_WALL_WIDTH_CM = 3.0

# What classify_square calls its zones -> the zone class the engine selects on.
_SQUARE_CLASSES = {
    "corners": "corner",
    "walls": "wall",
    "center": "center",
    "walls_and_corners": "legacy_aggregate",
    "arena_realout": "arena_area",
    "corners_realout": "corner_area",
    "walls_realout": "wall_area",
    "walls_and_corners_realout": "legacy_aggregate",
}


def _circle_class(name: str) -> str:
    if name.startswith("middle"):
        return "middle"
    return {"wall": "wall", "center": "center"}.get(name, "unknown")


class PresetController(QObject):
    def __init__(self, state, tab, parent=None):
        super().__init__(parent)
        self.state = state
        self.tab = tab
        self.video = None
        self.frame = None
        self.zones: list = []
        self.build_notes: list = []      # (level, text) shown beside validation

    # --- the frame --------------------------------------------------------
    def use_frame(self, frame) -> None:
        """Show an image as the frame to draw on, whatever its source."""
        self.frame = np.asarray(frame)
        self.tab.canvas.show_frame(self.frame)

    def open_video(self, path) -> None:
        try:
            info = video_info(path)
        except SphynxError as e:
            self.tab.set_status(str(e))
            return
        self.video = info
        self.tab.frame_spin.setMaximum(max(info.n_frames - 1, 0))
        self.tab.frame_spin.setValue(0)
        if info.frame_rate > 0:
            self.tab.frame_rate_box.setValue(info.frame_rate)
        self.tab.set_status(
            f"{info.path}: {info.n_frames} frames, {info.frame_rate:.3g} fps, "
            f"{info.width}x{info.height}")
        self.show_frame(0)

    def show_frame(self, index: int) -> None:
        if self.video is None:
            self.tab.set_status("Open a video first.")
            return
        try:
            frame = read_frame(self.video.path, int(index))
        except SphynxError as e:
            self.tab.set_status(str(e))
            return
        self.use_frame(frame)

    # --- calibration ------------------------------------------------------
    def calibrate(self, points, distance_cm) -> None:
        """Pixels-per-cm from two points a known distance apart."""
        try:
            (x0, y0), (x1, y1) = [(float(x), float(y)) for x, y in points]
        except (TypeError, ValueError):
            self.tab.set_status("Calibration needs exactly two points.")
            return
        distance_cm = float(distance_cm)
        if not distance_cm > 0:
            self.tab.set_status(
                f"The calibration distance must be greater than zero; "
                f"got {distance_cm:g}.")
            return
        pixels = math.hypot(x1 - x0, y1 - y0)
        if pixels <= 0:
            self.tab.set_status(
                "The two calibration points are the same point; "
                "click two ends of a known length.")
            return
        self.tab.pixels_per_cm_box.setValue(pixels / distance_cm)
        self.tab.set_status(
            f"{pixels:.1f} px over {distance_cm:g} cm = "
            f"{pixels / distance_cm:.3f} px/cm.")

    # --- zones ------------------------------------------------------------
    def build_zones(self) -> None:
        self.zones = []
        self.build_notes = []
        if self.frame is None:
            self.tab.set_status("Open a video or load a frame first.")
            return
        height, width = int(self.frame.shape[0]), int(self.frame.shape[1])

        roles = self.tab.shape_roles()
        arenas = [s for s in self.tab.canvas.shapes
                  if roles.get(s.name, ("", False))[0] == "arena"]
        if len(arenas) != 1:
            self.tab.set_status(
                f"A preset needs exactly one shape marked as the arena; "
                f"{len(arenas)} are.")
            return

        pixels_per_cm = float(self.tab.pixels_per_cm_box.value())
        if pixels_per_cm <= 0:
            self.tab.set_status(
                "Calibrate first: without pixels-per-cm the ring width in "
                "centimetres and every distance are meaningless.")
            return

        arena_shape = arenas[0]
        arena_mask = self.tab.canvas.mask_for(arena_shape, height, width)
        if not arena_mask.any():
            self.tab.set_status(
                f"The arena {arena_shape.name!r} covers no pixels of the frame.")
            return

        zones = [Zone("arena", "area", arena_mask, zone_class="arena")]
        zones.extend(self._derived_zones(arena_shape, arena_mask, pixels_per_cm))

        ring_cm = float(self.tab.ring_width_box.value())
        for kind in ("object", "hole"):
            drawn = [s for s in self.tab.canvas.shapes
                     if roles.get(s.name, ("", False))[0] == kind]
            if not drawn:
                continue
            targets = [s.name for s in drawn if roles[s.name][1]]
            try:
                zones.extend(build_object_zones(
                    [(s.name, self.tab.canvas.mask_for(s, height, width))
                     for s in drawn],
                    height, width, pixels_per_cm=pixels_per_cm,
                    zone_width_cm=ring_cm, kind=kind, targets=targets))
            except SphynxError as e:
                self.tab.set_status(str(e))
                self.zones = []
                return

        # Angles let the Barnes metrics say how far round the ring a hole is,
        # so they are assigned at draw time rather than guessed at analysis.
        try:
            assign_zone_angles(zones, resolve_arena_center(arena_mask))
        except SphynxError as e:
            self.build_notes.append(("warning", f"zone angles: {e}"))

        self.zones = zones
        counts: dict = {}
        for zone in zones:
            counts[zone.zone_class] = counts.get(zone.zone_class, 0) + 1
        self.tab.set_status(
            f"Built {len(zones)} zones: "
            + ", ".join(f"{k} x{v}" for k, v in sorted(counts.items())))
        self.tab.show_zones(zones)
        self.validate()

    def _derived_zones(self, shape, mask, pixels_per_cm) -> list:
        """Walls, corners and centre implied by the arena outline.

        A failure here is recorded as a note and the rest of the preset still
        builds: losing the objects because the wall band did not fit would be
        worse, and the note says exactly what was not built."""
        try:
            if shape.kind == "ellipse":
                built = classify_circle(mask, pixels_per_cm)
                return [Zone(z.name, "area", z.maskfilled,
                             zone_class=_circle_class(z.name)) for z in built]
            # classify_square reads corner seeds in 1-based image coordinates.
            corner_points = shape_vertices(shape) + 1.0
            built = classify_square(
                mask, "corners-walls-center", pixels_per_cm=pixels_per_cm,
                wall_width_cm=DEFAULT_WALL_WIDTH_CM,
                corner_points=corner_points)
            return [Zone(z.name, "area", z.maskfilled,
                         zone_class=_SQUARE_CLASSES.get(z.name, "unknown"))
                    for z in built]
        except SphynxError as e:
            self.build_notes.append(
                ("error", f"the arena's walls/corners/centre were not built: {e}"))
            return []

    # --- validation -------------------------------------------------------
    def options(self) -> dict:
        height, width = ((int(self.frame.shape[0]), int(self.frame.shape[1]))
                         if self.frame is not None else (0, 0))
        return options_struct(
            frame_rate=float(self.tab.frame_rate_box.value()),
            pixels_per_cm=float(self.tab.pixels_per_cm_box.value()),
            width=width, height=height,
            experiment_type=str(self.state.paradigm or ""))

    def validate(self) -> None:
        if not self.zones:
            self.tab.set_status("Build the zones before validating them.")
            self.tab.warnings.clear()
            return
        try:
            paradigm = resolve_paradigm(self.state.paradigm)
        except SphynxError as e:
            self.tab.warnings.show_rows([("paradigm", "error", str(e))])
            return
        report = validate_paradigm(paradigm, self.zones,
                                   SimpleNamespace(**self.options()))
        rows = [("validation", issue.level, f"{issue.code}: {issue.message}")
                for issue in report.issues]
        rows.extend(("geometry", level, text) for level, text in self.build_notes)
        self.tab.warnings.show_rows(rows)

    # --- saving -----------------------------------------------------------
    def save(self, path) -> None:
        if not self.zones:
            self.tab.set_status("Build the zones before saving the preset.")
            return
        try:
            written = save_preset(self.zones, self.options(), path)
        except SphynxError as e:
            self.tab.set_status(f"Save failed: {e}")
            return
        self.state.preset_path = written
        self.tab.set_status(f"Preset written to {written}.")
