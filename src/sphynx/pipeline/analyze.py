"""Main session pipeline: DLC + preset -> body-part traces + Acts + stats.

Port of sphynx.pipeline.analyzeSession (matlab/+sphynx/+pipeline/analyzeSession.m).
Behavioural parity, not bit-parity. The MATLAB fast-paths that are off the
analysis critical path are intentionally dropped for S1:
  - _Preprocessed.mat sibling fast-load,
  - VideoReader frame-count sanity check,
  - *_PreprocessSettings.mat auto-discovery (per-part settings come from
    per_part_default; an explicit settings file loader is deferred),
  - custom acts library from a .mat file (no .mat acts-set loader yet).
Everything on the OF built-in path (clean/interp/smooth, center, velocities,
speed acts, freezing, rear, bucket exclusivity, per-act stats) is ported.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import numpy as np

from sphynx.acts.builtins import freezing, rear
from sphynx.acts.speed import speed_acts
from sphynx.acts.stats import ActStats, act_stats
from sphynx.bodyparts.center import compute_center
from sphynx.bodyparts.identify import Point, identify_parts
from sphynx.config import Config
from sphynx.exceptions import SphynxError
from sphynx.io.dlc import read_dlc
from sphynx.io.preset import read_preset
from sphynx.logging_setup import get_logger
from sphynx.preprocess.orchestrator import apply_per_part_settings
from sphynx.preprocess.session import detect_session_start_frame
from sphynx.preprocess.settings import PartContext, per_part_default
from sphynx.preprocess.velocity import compute_velocity

_log = get_logger()


@dataclass
class SessionAct:
    name: str
    array: np.ndarray | None = None  # per-frame refine mask (0/1 float)
    category: str = "builtin"        # builtin | custom
    stats: ActStats | None = None


@dataclass
class BodyPartTrace:
    name: str
    x_smooth: np.ndarray
    y_smooth: np.ndarray
    x_original: np.ndarray
    y_original: np.ndarray
    x_interp: np.ndarray
    y_interp: np.ndarray
    velocity: np.ndarray | None
    average_speed: float
    average_distance: float
    status: str
    percent_nan: float
    percent_low_likelihood: float


@dataclass
class SessionResult:
    body_parts_names: list
    body_parts_traces: list
    point: Point
    acts: list
    options: object
    zones: object
    arena_and_objects: object
    n_frames: int
    config: Config
    selected_individual: str = ""
    all_individuals: list = field(default_factory=list)
    # --- filled in by the paradigm bridge (S4a); None when no paradigm ran ---
    validation: object | None = None      # ValidationReport
    metrics: object | None = None         # MetricResults
    event_streams: dict = field(default_factory=dict)   # family -> EventStream
    degraded: dict = field(default_factory=dict)        # act name -> reasons
    paradigm: str = ""
    paradigm_defaults: dict = field(default_factory=dict)


def _opt(options, name, default):
    """Attribute-access getOpt for a scipy mat_struct (or None)."""
    v = getattr(options, name, None) if options is not None else None
    return default if v is None else v


def _make_odd(w) -> int:
    w = int(round(w))
    if w < 3:
        w = 3
    if w % 2 == 0:
        w += 1
    return w


def _enforce_bucket_exclusivity(acts, priority_names):
    """Higher-priority acts win: lower-priority bucket-mates keep only the
    frames no higher-priority mate already claimed. Acts outside the bucket
    are untouched. Mirrors analyzeSession.enforceBucketExclusivity."""
    if not acts or not priority_names:
        return acts
    by_name = {a.name.lower(): a for a in acts}
    cum = None
    for nm in priority_names:
        a = by_name.get(nm.lower())
        if a is None or a.array is None:
            continue
        m = a.array.astype(bool)
        if cum is None:
            cum = m
        else:
            m = m & ~cum
            a.array = m.astype(float)
            cum = cum | m
    return acts


def _paradigm_defaults(paradigm) -> dict:
    """A paradigm's config defaults, resolved through its ancestors.

    These sit BETWEEN the preset and the Config: a paradigm supplies sensible
    values for an experiment type, and the preset that was actually drawn still
    overrides them."""
    if paradigm is None:
        return {}
    from sphynx.paradigms.registry import resolve_paradigm

    return dict(resolve_paradigm(paradigm).config_defaults)


def analyze_session(config: Config, paradigm=None) -> SessionResult:
    """Run the full single-session pipeline and return a SessionResult.

    Required: config.paths.dlc, config.paths.preset. When `paradigm` is given
    (a name or a Paradigm), its validation, composites, act families and named
    metrics are computed onto the result as well.
    """
    if not config.paths.dlc:
        raise SphynxError("config.paths.dlc is required")
    if not config.paths.preset:
        raise SphynxError("config.paths.preset is required")

    # --- 1. Load preset & DLC ---
    _log.info("Reading preset: %s", config.paths.preset)
    preset = read_preset(config.paths.preset)
    options, zones, arena = preset.options, preset.zones, preset.arena_and_objects

    individual = config.preprocess.individual or ""
    start = config.frames.start_frame
    if config.frames.auto_start and start == 1:
        dlc_full = read_dlc(
            config.paths.dlc, end_frame=config.frames.end_frame, individual=individual
        )
        detected, info = detect_session_start_frame(dlc_full)
        if not info.get("message") and detected > 1:
            _log.info("Auto-start: detected session start at frame %d", detected)
            start = detected

    _log.info("Reading DLC: %s", config.paths.dlc)
    dlc = read_dlc(
        config.paths.dlc, start_frame=start,
        end_frame=config.frames.end_frame, individual=individual,
    )
    if not individual and dlc.selected_individual:
        individual = dlc.selected_individual

    n_frames = dlc.n_frames
    n_parts = len(dlc.body_parts)
    frame_rate = float(_opt(options, "FrameRate", 30))
    pxl_per_cm = float(_opt(options, "pxl2sm", 1.0))
    # Parity with analyzeSession.m: only a positive scalar x_kcorr wins;
    # anything else (missing, zero, negative) falls back to 1 (isotropic).
    _xk = float(_opt(options, "x_kcorr", 1.0))
    x_kcorr = _xk if _xk > 0 else 1.0
    width = float(_opt(options, "Width", np.inf))
    height = float(_opt(options, "Height", np.inf))
    _log.info("Loaded %d frames, %d body parts", n_frames, n_parts)

    # Precedence: preset Options > paradigm config_defaults > Config.
    defaults = _paradigm_defaults(paradigm)
    rest_threshold = defaults.get("velocity_rest", config.acts.rest_threshold_cm_s)
    loc_threshold = defaults.get("velocity_locomotion",
                                 config.acts.loc_threshold_cm_s)
    min_run_seconds = defaults.get("min_run_seconds", config.acts.min_run_seconds)

    small_win = _make_odd(frame_rate * config.preprocess.smooth_window_small_sec)
    big_win = _make_odd(frame_rate * config.preprocess.smooth_window_big_sec)
    min_run_frames = int(round(frame_rate * min_run_seconds))

    # --- 3. Clean each body-part trace ---
    traces: list = []
    for part in range(n_parts):
        name = dlc.body_parts[part]
        settings = per_part_default(name, config)
        ctx = PartContext(
            frame_width=width, frame_height=height, frame_rate=frame_rate,
            pixels_per_cm=pxl_per_cm, x_kcorr=x_kcorr, part_name=name,
        )
        res = apply_per_part_settings(
            dlc.X[part, :], dlc.Y[part, :], dlc.likelihood[part, :], settings, ctx
        )
        if res.status == "NotFound":
            _log.warning('BodyPart "%s" status NotFound, skipping', name)
            continue
        traces.append(BodyPartTrace(
            name=name, x_smooth=res.x_smooth, y_smooth=res.y_smooth,
            x_original=np.asarray(dlc.X[part, :], float),
            y_original=np.asarray(dlc.Y[part, :], float),
            x_interp=res.x_interp, y_interp=res.y_interp, velocity=None,
            average_speed=0.0, average_distance=0.0, status=res.status,
            percent_nan=res.percent_nan,
            percent_low_likelihood=res.percent_low_likelihood,
        ))

    kept_names = [t.name for t in traces]
    bpx = np.array([t.x_smooth for t in traces], dtype=float)
    bpy = np.array([t.y_smooth for t in traces], dtype=float)

    # --- 4. Identify body parts and compute Center ---
    point = identify_parts(kept_names)
    center_x, center_y = compute_center(bpx, bpy, point)
    if point.center is None:
        bpx = np.vstack([bpx, center_x])
        bpy = np.vstack([bpy, center_y])
        point.center = bpx.shape[0] - 1
        traces.append(BodyPartTrace(
            name="synthetic_center", x_smooth=center_x, y_smooth=center_y,
            x_original=center_x, y_original=center_y,
            x_interp=center_x, y_interp=center_y, velocity=None,
            average_speed=0.0, average_distance=0.0, status="Synthetic",
            percent_nan=0.0, percent_low_likelihood=0.0,
        ))
        kept_names.append("synthetic_center")

    # --- 5. Per-part velocities ---
    big_parts = {b.lower() for b in config.preprocess.per_part.big_parts}
    for i, t in enumerate(traces):
        win = big_win if t.name.lower() in big_parts else small_win
        v = compute_velocity(
            bpx[i], bpy[i], frame_rate, pxl_per_cm,
            max_velocity_cm_s=config.preprocess.max_velocity_cm_s,
            smooth_window=win, x_kcorr=x_kcorr,
        )
        t.velocity = v
        t.average_speed = round(float(np.nanmean(v)), 2)
        t.average_distance = round(float(np.nansum(v)) / frame_rate, 2)

    # velocity used for speed acts
    bp = _opt(options, "BodyPart", None)
    vel_part_name = getattr(bp, "Velocity", None) if bp is not None else None
    vel_part_name = str(vel_part_name) if vel_part_name else "bodycenter"
    vel_idx = next(
        (i for i, nm in enumerate(kept_names) if nm.lower() == vel_part_name.lower()),
        None,
    )
    if vel_idx is None:
        velocity = compute_velocity(
            center_x, center_y, frame_rate, pxl_per_cm,
            max_velocity_cm_s=config.preprocess.max_velocity_cm_s,
            smooth_window=big_win, x_kcorr=x_kcorr,
        )
    else:
        velocity = traces[vel_idx].velocity

    # --- 6. Speed acts ---
    sa = speed_acts(
        velocity,
        _opt(options, "velocity_rest", rest_threshold),
        _opt(options, "velocity_locomotion", loc_threshold),
        min_run_frames,
    )
    acts: list = [
        SessionAct("rest", sa.rest.astype(float), "builtin"),
        SessionAct("walk", sa.walk.astype(float), "builtin"),
        SessionAct("locomotion", sa.locomotion.astype(float), "builtin"),
    ]

    # --- 7. Freezing ---
    bpv = np.array([t.velocity for t in traces], dtype=float)
    fz = freezing(
        bpv, point, config.acts.freezing_mode,
        _opt(options, "velocity_rest", rest_threshold),
        min_run_frames,
    )
    acts.append(SessionAct("freezing", fz.astype(float), "builtin"))

    # --- 8. Rear ---
    rear_ok = (
        point.tailbase is not None
        and point.left_hind_limb is not None
        and point.right_hind_limb is not None
    )
    if rear_ok or config.acts.rear_mode == "AllBodyParts":
        rear_mode = config.acts.rear_mode
        if rear_mode == "TailbasePaws" and not rear_ok:
            rear_mode = "AllBodyParts"
            _log.warning("Falling back to rear mode AllBodyParts (missing parts)")
        try:
            r = rear(
                bpx, bpy, point, rear_mode, pxl_per_cm,
                all_body_parts_threshold_pxl=config.acts.rear_threshold_all_body_parts_pxl,
                tailbase_paws_threshold_cm=config.acts.rear_threshold_tailbase_paws_cm,
                auto_threshold=config.acts.rear_auto_threshold,
                frame_rate=frame_rate, min_run_frames=min_run_frames, x_kcorr=x_kcorr,
            )
            acts.append(SessionAct("rear", r.astype(float), "builtin"))
        except SphynxError as e:
            _log.warning("Rear detection failed: %s", e)

    # --- 9c. Within-bucket mutual exclusivity ---
    acts = _enforce_bucket_exclusivity(acts, ["locomotion", "walk", "rest"])
    acts = _enforce_bucket_exclusivity(
        acts, ["corners", "walls", "walls_and_corners", "middle_zone", "center"]
    )

    # --- 10. Stats per act ---
    center_idx = point.center if (point.center is not None and point.center < len(traces)) else len(traces) - 1
    center_velocity = traces[center_idx].velocity
    for a in acts:
        a.stats = act_stats(a.array, frame_rate, velocity=center_velocity)

    # --- 11. Result ---
    result = SessionResult(
        body_parts_names=kept_names, body_parts_traces=traces, point=point,
        acts=acts, options=options, zones=zones, arena_and_objects=arena,
        n_frames=n_frames, config=config,
        selected_individual=dlc.selected_individual or "",
        all_individuals=list(dlc.individuals) if dlc.individuals else [],
    )
    if paradigm is not None:
        from sphynx.pipeline.paradigm_bridge import apply_paradigm

        apply_paradigm(result, paradigm)
    return result
