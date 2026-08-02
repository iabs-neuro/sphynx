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
    Zone, ZoneRoles, assign_zone_angles, classify_circle,
    classify_square, resolve_arena_center,
)
from sphynx_gui.preset_canvas import shape_vertices

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
        self.built_options: dict | None = None   # what the masks were built for

    # --- the frame --------------------------------------------------------
    def use_frame(self, frame) -> None:
        """Show an image as the frame to draw on, whatever its source.

        Shapes are stored in pixel coordinates, so a frame of another size
        would silently move every one of them: an arena covering most of a
        small frame becomes a corner patch on a large one. Rather than keep
        coordinates that no longer mean anything, the shapes are dropped and
        the change is stated."""
        frame = np.asarray(frame)
        new_shape = (int(frame.shape[0]), int(frame.shape[1]))
        previous = self.tab.canvas.frame_shape
        if previous is not None and previous != new_shape and self.tab.canvas.shapes:
            self.tab.canvas.clear_shapes()
            self.tab.forget_roles()
            self.zones = []
            self.built_options = None
            self.tab.set_status(
                f"The frame size changed from {previous[1]}x{previous[0]} to "
                f"{new_shape[1]}x{new_shape[0]}; the shapes were drawn in the "
                "old pixels and have been cleared. Draw them again.")
        self.frame = frame
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
        readable_rate = info.frame_rate > 0 and math.isfinite(info.frame_rate)
        self.tab.frame_rate_box.setValue(info.frame_rate if readable_rate else 0.0)
        self.show_frame(0)
        if readable_rate:
            self.tab.set_status(
                f"{info.path}: {info.n_frames} frames, {info.frame_rate:.3g} fps, "
                f"{info.width}x{info.height}")
        else:
            # Writing 30 fps here would put every duration and speed in the
            # session out by whatever the real rate is.
            self.tab.set_status(
                f"{info.path}: {info.n_frames} frames, {info.width}x{info.height}. "
                f"The frame rate could not be read from the file (got "
                f"{info.frame_rate!r}); enter it before saving.")

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
        self.built_options = None
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

        # A shape marked wall or corner is a zone the experimenter drew by
        # hand -- typically because the arena outline could not imply it.
        # Dropping it silently would leave a preset that looks complete.
        for shape in self.tab.canvas.shapes:
            role = roles.get(shape.name, ("", False))[0]
            if role not in ("wall", "corner"):
                continue
            mask = self.tab.canvas.mask_for(shape, height, width)
            if not mask.any():
                self.tab.set_status(
                    f"{shape.name!r} covers no pixels of the frame.")
                self.zones = []
                return
            zones.append(Zone(shape.name, "area", mask, zone_class=role,
                              roles=ZoneRoles(
                                  is_target=roles[shape.name][1])))

        # Angles let the Barnes metrics say how far round the ring a hole is,
        # so they are assigned at draw time rather than guessed at analysis.
        try:
            assign_zone_angles(zones, resolve_arena_center(arena_mask))
        except SphynxError as e:
            self.build_notes.append(("warning", f"zone angles: {e}"))

        self.zones = zones
        # The options are pinned to the masks here. Reading them again at save
        # time would let a recalibration ship a pxl2sm the masks were never
        # built for -- a ring labelled 2.5 cm that is physically half that.
        self.built_options = self.options()
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
        wall_width_cm = float(self.tab.wall_width_box.value())
        try:
            if shape.kind == "ellipse":
                built = classify_circle(mask, pixels_per_cm,
                                        wall_width_cm=wall_width_cm)
                return [Zone(z.name, "area", z.maskfilled,
                             zone_class=_circle_class(z.name)) for z in built]
            if shape.kind != "rectangle":
                # classify_square seeds one corner per point given, so handing
                # it every vertex of a polygon would turn most of the border
                # band into "corner". Which vertices are corners is the
                # experimenter's call, not something to guess.
                self.build_notes.append((
                    "warning",
                    f"the arena {shape.name!r} is a polygon, so its walls, "
                    "corners and centre were not derived; draw the corners as "
                    "their own shapes and mark them 'corner'"))
                return []
            # classify_square reads corner seeds in 1-based image coordinates.
            corner_points = shape_vertices(shape) + 1.0
            built = classify_square(
                mask, "corners-walls-center", pixels_per_cm=pixels_per_cm,
                wall_width_cm=wall_width_cm,
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
            experiment_type=str(self.state.paradigm or ""),
            WallWidthCm=float(self.tab.wall_width_box.value()),
            RingWidthCm=float(self.tab.ring_width_box.value()))

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
        report = validate_paradigm(
            paradigm, self.zones,
            SimpleNamespace(**(self.built_options or self.options())))
        rows = [("validation", issue.level, f"{issue.code}: {issue.message}")
                for issue in report.issues]
        rows.extend(("geometry", level, text) for level, text in self.build_notes)
        self.tab.warnings.show_rows(rows)

    # --- saving -----------------------------------------------------------
    def save(self, path) -> None:
        if not self.zones or self.built_options is None:
            self.tab.set_status("Build the zones before saving the preset.")
            return

        changed = [key for key, value in self.options().items()
                   if self.built_options.get(key) != value]
        if changed:
            self.tab.set_status(
                f"{', '.join(sorted(changed))} changed since the zones were "
                "built, so the masks no longer match them. Rebuild the zones, "
                "then save.")
            return

        if not float(self.built_options.get("FrameRate", 0.0)) > 0:
            self.tab.set_status(
                "The frame rate is not set, so every duration and speed read "
                "from this preset would be wrong. Enter it and rebuild.")
            return

        try:
            written = save_preset(self.zones, self.built_options, path)
        except SphynxError as e:
            self.tab.set_status(f"Save failed: {e}")
            return
        self.state.preset_path = written
        self.tab.set_status(f"Preset written to {written}.")
