"""Typed configuration. Defaults live here — the single source of truth.

Mirrors the engine subset of the MATLAB sphynx.pipeline.defaultConfig tree.
GUI-only knobs (createPreset/analyzeTab/... from sphynx_defaults.jsonc) are
out of scope for the engine and are not represented here.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field, fields, is_dataclass
from pathlib import Path
import tomllib

import tomli_w


@dataclass
class Paths:
    video: str = ""
    dlc: str = ""
    preset: str = ""
    out_dir: str = ""
    preprocess_settings: str = ""


@dataclass
class Frames:
    start_frame: int = 1
    end_frame: int = 0  # 0 = read all
    auto_start: bool = False


@dataclass
class PerPart:
    big_parts: list[str] = field(
        default_factory=lambda: [
            "mass centre", "mass center", "bodycenter", "body_center",
            "center", "mouse_center", "tailbase", "tail base", "tail_base", "tail1",
        ]
    )
    smoothing_method: str = "sgolay"
    smoothing_poly_order: int = 3
    not_found_threshold_pct: int = 90


@dataclass
class Preprocess:
    individual: str = ""
    likelihood_threshold: float = 0.95
    smooth_window_small_sec: float = 0.10
    smooth_window_big_sec: float = 0.25
    max_velocity_cm_s: float = 50.0
    interpolation_method: str = "pchip"
    per_part: PerPart = field(default_factory=PerPart)


@dataclass
class Acts:
    library_path: str = ""
    rest_threshold_cm_s: float = 1.0
    loc_threshold_cm_s: float = 5.0
    min_run_seconds: float = 0.25
    freezing_mode: str = "HeadAndCenter"
    rear_mode: str = "TailbasePaws"
    rear_threshold_all_body_parts_pxl: float = 170.0
    rear_threshold_tailbase_paws_cm: float = 2.8
    rear_auto_threshold: bool = True


@dataclass
class Io:
    save_workspace: bool = True
    session_name: str = ""


@dataclass
class Viz:
    enabled: bool = False
    headless: bool = True
    make_video: bool = False


@dataclass
class Config:
    paths: Paths = field(default_factory=Paths)
    frames: Frames = field(default_factory=Frames)
    preprocess: Preprocess = field(default_factory=Preprocess)
    acts: Acts = field(default_factory=Acts)
    io: Io = field(default_factory=Io)
    viz: Viz = field(default_factory=Viz)
    verbose: str = "info"  # debug | info | warn | error

    @classmethod
    def default(cls) -> "Config":
        return cls()

    @classmethod
    def from_toml(cls, path: str | Path) -> "Config":
        with open(path, "rb") as fh:
            data = tomllib.load(fh)
        cfg = cls.default()
        _overlay(cfg, data)
        return cfg

    def to_toml(self, path: str | Path) -> None:
        with open(path, "wb") as fh:
            tomli_w.dump(asdict(self), fh)


def _overlay(obj: object, data: dict) -> None:
    """Recursively set fields present in `data`; absent keys keep defaults."""
    for f in fields(obj):
        if f.name not in data:
            continue
        current = getattr(obj, f.name)
        value = data[f.name]
        if is_dataclass(current) and isinstance(value, dict):
            _overlay(current, value)
        else:
            setattr(obj, f.name, value)
