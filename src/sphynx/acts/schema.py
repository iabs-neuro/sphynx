"""Act schema + builders + evaluation context. Ports of emptyAct,
buildSimpleAct, buildComplexAct and the applyAct ctx struct."""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

_INF = float("inf")
_NAN = float("nan")


@dataclass
class Act:
    name: str = ""
    type: str = "simple"          # 'simple' | 'complex' | 'special'
    zones: list[str] = field(default_factory=list)
    zone_op: str = "OR"           # AND | OR | EXCLUDE
    body_part: str = ""
    body_parts: list[str] = field(default_factory=list)
    speed_min: float = 0.0
    speed_max: float = _INF
    components: list[str] = field(default_factory=list)
    operation: str = ""           # intersect | union | exclude | sequence
    seq_delay_sec: float = 0.0
    special_kind: str = ""        # freezing | rears | allinzone
    rear_mode: str = ""
    threshold_cm: float = _NAN
    threshold_pxl: float = _NAN
    rear_auto_threshold: bool = True
    min_duration_sec: float = 0.25
    max_gap_sec: float = 0.25
    required_parts: list[str] = field(default_factory=list)
    fallback: dict = field(default_factory=dict)
    median_window_sec: float = 0.0
    freezing_mode: str = ""
    # Expression tree (sphynx.acts.expr). When set it wins over the flat
    # components/operation fields, which are migrated on the fly otherwise.
    expr: object | None = None


def build_simple_act(
    name: str = "", zones=None, zone_op: str = "OR", body_part: str = "",
    speed_min: float = 0.0, speed_max: float = _INF,
    min_duration_sec: float = 0.25, max_gap_sec: float = 0.25,
) -> Act:
    if zones is None:
        zones = []
    elif isinstance(zones, str):
        zones = [zones]
    return Act(
        name=name, type="simple", zones=list(zones), zone_op=zone_op.upper(),
        body_part=body_part, speed_min=speed_min, speed_max=speed_max,
        min_duration_sec=min_duration_sec, max_gap_sec=max_gap_sec,
    )


def build_complex_act(
    name: str = "", components=None, operation: str = "intersect",
    seq_delay_sec: float = 0.0, min_duration_sec: float = 0.25, max_gap_sec: float = 0.25,
) -> Act:
    return Act(
        name=name, type="complex", components=list(components or []),
        operation=operation.lower(), seq_delay_sec=seq_delay_sec,
        min_duration_sec=min_duration_sec, max_gap_sec=max_gap_sec,
    )


def build_special_act(
    name: str = "", special_kind: str = "", body_parts=None, zones=None,
    freezing_mode: str = "", rear_mode: str = "",
    threshold_cm: float = _NAN, threshold_pxl: float = _NAN,
    rear_auto_threshold: bool = True, speed_max: float = _INF,
    min_duration_sec: float = 0.25, max_gap_sec: float = 0.25,
) -> Act:
    """Build a special act (freezing / rears / allinzone). Freezing and rear
    modes are act properties, not analysis-level config (S2 layer 4d)."""
    return Act(
        name=name, type="special", special_kind=special_kind.lower(),
        body_parts=list(body_parts or []), zones=list(zones or []),
        freezing_mode=freezing_mode, rear_mode=rear_mode,
        threshold_cm=threshold_cm, threshold_pxl=threshold_pxl,
        rear_auto_threshold=rear_auto_threshold, speed_max=speed_max,
        min_duration_sec=min_duration_sec, max_gap_sec=max_gap_sec,
    )


@dataclass
class ActContext:
    X: np.ndarray          # HxN smoothed x per body part
    Y: np.ndarray          # HxN
    velocity_cm_s: np.ndarray  # HxN cm/s
    body_parts: list[str]
    zones: list            # objects with .name and .maskfilled
    frame_rate: float
    pixels_per_cm: float = 1.0
    x_kcorr: float = 1.0
    all_acts: list = field(default_factory=list)
    results_by_name: dict = field(default_factory=dict)
    # act name -> list of degradation reasons recorded while evaluating it.
    # Populated by apply_act; never silently empty when something was missing.
    degraded: dict = field(default_factory=dict)
    # Act names currently being evaluated, so a reference cycle raises instead
    # of recursing forever.
    evaluating: set = field(default_factory=set)
