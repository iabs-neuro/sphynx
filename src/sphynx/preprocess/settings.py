"""Per-part preprocessing settings + runtime context. Port of
sphynx.preprocess.perPartDefault (+ the ctx struct fields)."""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

from sphynx.config import Config


@dataclass
class PartSettings:
    likelihood_threshold: float = 0.95
    smooth_window_sec: float = 0.25
    interpolation_method: str = "pchip"
    smoothing_method: str = "sgolay"
    smoothing_poly_order: int = 3
    not_found_threshold_pct: float = 90


@dataclass
class PartContext:
    frame_width: float = np.inf
    frame_height: float = np.inf
    frame_rate: float = 30.0
    pixels_per_cm: float | None = None
    x_kcorr: float = 1.0
    part_name: str = ""
    outlier: dict | None = None
    manual_regions: list | None = None


def per_part_default(part_name, config: Config | None = None) -> PartSettings:
    if config is None:
        config = Config.default()
    pp = config.preprocess.per_part
    is_big = any(str(part_name).lower() == b.lower() for b in pp.big_parts)
    win_sec = (
        config.preprocess.smooth_window_big_sec
        if is_big else config.preprocess.smooth_window_small_sec
    )
    return PartSettings(
        likelihood_threshold=config.preprocess.likelihood_threshold,
        smooth_window_sec=win_sec,
        interpolation_method=config.preprocess.interpolation_method,
        smoothing_method=pp.smoothing_method,
        smoothing_poly_order=pp.smoothing_poly_order,
        not_found_threshold_pct=pp.not_found_threshold_pct,
    )
