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

from sphynx.exceptions import SphynxError, SphynxValueError
from sphynx.io.preset_write import options_struct, save_preset
from sphynx.io.video import read_frame, video_info
from sphynx.paradigms import resolve_paradigm, validate_paradigm
from sphynx.preset.calibration import calibrate, points_needed
from sphynx.preset.detect import detect_objects as detect
from sphynx.preset.objects import build_object_zones
from sphynx.zones import (
    Zone, ZoneRoles, assign_zone_angles, classify_circle,
    classify_circle_center, classify_circle_wall, classify_square,
    resolve_arena_center,
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


# What to click, per mode. The order matters: the first pair measures the
# vertical scale and the second the horizontal one.
_CALIB_PROMPT = {
    "1 line": "Click the two ends of one diagonal reference line (20-70 deg "
              "from horizontal), then set its total length in 'cm Y'.",
    "2 lines": "Click the two ends of the VERTICAL reference line, then the "
               "two ends of the HORIZONTAL one.",
    "4 points": "Click the vertical pair (points 1 and 2), then the "
                "horizontal pair (points 3 and 4).",
}


AUTO_STRATEGY = "auto (by arena shape)"

# The MATLAB app's own list, plus AUTO for what this tab did before it had a
# choice at all: rectangle -> corners-walls-center, ellipse -> circle-rings.
ZONE_STRATEGIES = (
    AUTO_STRATEGY, "circle", "circle-rings", "circle-with-center",
    "corners-walls-center", "strips", "none",
)

# Which parameter each strategy actually reads, so the rest can be greyed out.
STRATEGY_FIELDS = {
    AUTO_STRATEGY: {"wall", "middle"},
    "circle": {"wall"},
    "circle-rings": {"wall", "middle"},
    "circle-with-center": {"wall", "center_diameter"},
    "corners-walls-center": {"wall"},
    "strips": {"strips"},
    "none": set(),
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
        self.calib_points: list = []     # clicks awaiting Compute
        self.calibration = None          # the last accepted measurement

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
    def begin_calibration(self) -> None:
        """Arm the canvas for the clicks the chosen mode needs."""
        if self.frame is None:
            self.tab.set_status("Open a video or load a frame first.")
            return
        mode = self.tab.calib_mode_box.currentText()
        try:
            wanted = points_needed(mode)
        except SphynxError as e:
            self.tab.set_status(str(e))
            return
        self.calib_points = []
        self.calibration = None
        self.tab.canvas.begin_points(wanted)
        self.tab.set_status(_CALIB_PROMPT[mode])

    def on_points_picked(self, points) -> None:
        self.calib_points = [(float(x), float(y)) for x, y in points]
        self.tab.set_status(
            f"{len(self.calib_points)} points picked; set the lengths in cm "
            "and press Compute.")

    def compute_calibration(self) -> None:
        """Turn the picked points into pixels-per-cm and, where the mode can
        measure it, the pixel anisotropy."""
        if not self.calib_points:
            self.tab.set_status("Press Choose and click the reference points "
                                "on the frame first.")
            return
        mode = self.tab.calib_mode_box.currentText()
        try:
            result = calibrate(mode, self.calib_points,
                               float(self.tab.distance_y_box.value()),
                               float(self.tab.distance_x_box.value()))
        except SphynxError as e:
            # A refused measurement leaves the previous calibration alone
            # rather than half-replacing it.
            self.calib_points = []
            self.tab.canvas.clear_points()
            self.tab.set_status(str(e))
            return
        self.calibration = result
        self.tab.pixels_per_cm_box.setValue(result.pixels_per_cm)
        self.tab.show_calibration(result)
        note = ("" if not result.is_anisotropic else
                f" The axes differ by {result.diff_pct:.1f}%, so the y-axis "
                f"scale is used and x is corrected by {result.x_kcorr:.3f}.")
        self.tab.set_status(
            f"Calibrated ({mode}): {result.pixels_per_cm:.3f} px/cm."
            + note + " Rebuild the zones to apply it.")

    def _active_calibration(self):
        """The last measurement, but only while it still describes the value
        in the box.

        Typing a pixels-per-cm by hand replaces the measurement without
        replacing the anisotropy that came with it. Shipping the old
        `x_kcorr` beside a new scale would stretch every zone against a
        measurement that was never made."""
        if self.calibration is None:
            return None
        if not math.isclose(self.calibration.pixels_per_cm,
                            float(self.tab.pixels_per_cm_box.value()),
                            rel_tol=1e-9, abs_tol=1e-9):
            return None
        return self.calibration

    def x_kcorr(self) -> float:
        active = self._active_calibration()
        return 1.0 if active is None else float(active.x_kcorr)

    # --- automatic detection ----------------------------------------------
    def detect_objects(self) -> None:
        """Propose the objects inside the arena as ordinary drawn shapes.

        The detections are added to the canvas, not to the preset: the
        experimenter sees each one, and deletes or redraws what is wrong,
        before any zone is built from it."""
        if self.frame is None:
            self.tab.set_status("Open a video or load a frame first.")
            return
        roles = self.tab.shape_roles()
        arenas = [s for s in self.tab.canvas.shapes
                  if roles.get(s.name, ("", False))[0] == "arena"]
        if len(arenas) != 1:
            self.tab.set_status(
                f"Auto-detect needs exactly one shape marked as the arena to "
                f"search inside; {len(arenas)} are.")
            return
        pixels_per_cm = float(self.tab.pixels_per_cm_box.value())
        if pixels_per_cm <= 0:
            self.tab.set_status(
                "Calibrate first: the area filters are in square centimetres.")
            return

        height, width = int(self.frame.shape[0]), int(self.frame.shape[1])
        arena_mask = self.tab.canvas.mask_for(arenas[0], height, width)
        try:
            found = detect(
                self.frame, arena_mask, pixels_per_cm=pixels_per_cm,
                mode=self.tab.detect_mode_box.currentText(),
                algorithm=self.tab.detect_algorithm_box.currentText(),
                sensitivity=float(self.tab.sensitivity_box.value()),
                min_area_cm2=float(self.tab.min_area_box.value()),
                max_area_cm2=float(self.tab.max_area_box.value()),
                neighborhood_cm=float(self.tab.neighborhood_box.value()),
                radius_range_cm=(float(self.tab.radius_min_box.value()),
                                 float(self.tab.radius_max_box.value())))
        except SphynxError as e:
            self.tab.set_status(str(e))
            return

        if not found:
            self.tab.set_status(
                "Auto-detect found nothing inside the arena. Try a higher "
                "sensitivity, or a wider area range.")
            return

        # Detections become polygons whatever shape they were fitted as: the
        # canvas stores a rectangle and an ellipse as two corners, which
        # cannot carry a rotated or free-form outline without losing it.
        added = []
        with self.tab.canvas.batch():
            for index, detection in enumerate(found, start=1):
                name = self._free_name(f"auto{index}")
                points = [(float(x), float(y))
                          for x, y in zip(detection.x, detection.y)]
                self.tab.canvas.add_shape(name, "polygon", points)
                self.tab.remember_role(name, "object", False)
                added.append(name)
        self.tab.refresh_shape_table()
        self.tab.set_status(
            f"Auto-detect proposed {len(added)} object(s) as "
            f"{', '.join(added)}. Check them on the frame, then build the "
            "zones; delete or redraw anything wrong first.")

    def _free_name(self, base: str) -> str:
        taken = {s.name for s in self.tab.canvas.shapes}
        if base not in taken:
            return base
        suffix = 2
        while f"{base}_{suffix}" in taken:
            suffix += 1
        return f"{base}_{suffix}"

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
        x_kcorr = self.x_kcorr()
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
                    zone_width_cm=ring_cm, x_kcorr=x_kcorr, kind=kind,
                    targets=targets))
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

    def strategy(self) -> str:
        """The chosen strategy, with AUTO already resolved to a real one."""
        chosen = self.tab.strategy_box.currentText()
        if chosen != AUTO_STRATEGY:
            return chosen
        arenas = [s for s in self.tab.canvas.shapes
                  if self.tab.shape_roles().get(s.name, ("", False))[0] == "arena"]
        kind = arenas[0].kind if arenas else ""
        # What this tab did before the choice existed. A polygon resolved to
        # nothing, which is why polygon arenas used to derive no zones at all;
        # picking 'circle' explicitly now gives them a wall and a centre.
        return {"rectangle": "corners-walls-center",
                "ellipse": "circle-rings"}.get(kind, "none")

    def _derived_zones(self, shape, mask, pixels_per_cm) -> list:
        """The zones the arena outline implies, per the chosen strategy.

        A failure here is recorded as a note and the rest of the preset still
        builds: losing the objects because the wall band did not fit would be
        worse, and the note says exactly what was not built."""
        strategy = self.strategy()
        wall_width_cm = float(self.tab.wall_width_box.value())
        try:
            if strategy == "none":
                if self.tab.strategy_box.currentText() == AUTO_STRATEGY:
                    self.build_notes.append((
                        "warning",
                        f"the arena {shape.name!r} is a {shape.kind}, which "
                        "'auto' cannot resolve, so no walls or centre were "
                        "derived; pick a strategy such as 'circle' to get them"))
                return []

            if strategy == "circle":
                built = classify_circle_wall(mask, pixels_per_cm,
                                             wall_width_cm=wall_width_cm)
            elif strategy == "circle-rings":
                built = classify_circle(
                    mask, pixels_per_cm, wall_width_cm=wall_width_cm,
                    middle_width_cm=float(self.tab.middle_width_box.value()))
            elif strategy == "circle-with-center":
                built = classify_circle_center(
                    mask, pixels_per_cm, wall_width_cm=wall_width_cm,
                    center_diameter_cm=float(
                        self.tab.center_diameter_box.value()))
            elif strategy == "strips":
                built = classify_square(
                    mask, "strips",
                    num_strips=int(self.tab.strips_box.value()),
                    strip_direction=self.tab.strip_direction_box.currentText())
                return [Zone(z.name, "area", z.maskfilled, zone_class="strip")
                        for z in built]
            elif strategy == "corners-walls-center":
                if shape.kind != "rectangle":
                    # classify_square seeds one corner per point given, so
                    # handing it every vertex of a polygon would turn most of
                    # the border band into "corner". Which vertices are corners
                    # is the experimenter's call, not something to guess.
                    self.build_notes.append((
                        "warning",
                        f"'corners-walls-center' needs a rectangular arena to "
                        f"know where the corners are, and {shape.name!r} is a "
                        f"{shape.kind}; nothing was derived. Use 'circle' for a "
                        "wall and a centre, or draw the corners yourself and "
                        "mark them 'corner'"))
                    return []
                # classify_square reads corner seeds in 1-based image coords.
                built = classify_square(
                    mask, "corners-walls-center", pixels_per_cm=pixels_per_cm,
                    wall_width_cm=wall_width_cm,
                    corner_points=shape_vertices(shape) + 1.0)
                return [Zone(z.name, "area", z.maskfilled,
                             zone_class=_SQUARE_CLASSES.get(z.name, "unknown"))
                        for z in built]
            else:
                raise SphynxValueError(
                    f"unknown zone strategy {strategy!r}; expected one of "
                    f"{ZONE_STRATEGIES}")

            return [Zone(z.name, "area", z.maskfilled,
                         zone_class=_circle_class(z.name)) for z in built]
        except SphynxError as e:
            self.build_notes.append(
                ("error", f"the arena's derived zones were not built: {e}"))
            return []

    # --- validation -------------------------------------------------------
    def options(self) -> dict:
        height, width = ((int(self.frame.shape[0]), int(self.frame.shape[1]))
                         if self.frame is not None else (0, 0))
        active = self._active_calibration()
        pixels_per_cm = float(self.tab.pixels_per_cm_box.value())
        return options_struct(
            frame_rate=float(self.tab.frame_rate_box.value()),
            pixels_per_cm=pixels_per_cm,
            width=width, height=height,
            x_kcorr=1.0 if active is None else float(active.x_kcorr),
            pxl_y=None if active is None else float(active.pxl_y),
            pxl_x=None if active is None else float(active.pxl_x),
            experiment_type=str(self.state.paradigm or ""),
            CalibrationMode="" if active is None else str(active.mode),
            # The resolved strategy, not the word "auto": a preset read back a
            # year later should say which zones it actually holds.
            ZoneStrategy=str(self.strategy()),
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
