"""Thin command-line entry: analyze one session and print act stats.

    python -m sphynx.pipeline.cli --dlc DLC.csv --preset PRESET.mat [--config cfg.toml]
"""

from __future__ import annotations

import argparse
import sys

from sphynx.config import Config
from sphynx.exceptions import SphynxError
from sphynx.pipeline.analyze import analyze_session


def build_config(args) -> Config:
    cfg = Config.from_toml(args.config) if args.config else Config.default()
    if args.dlc:
        cfg.paths.dlc = args.dlc
    if args.preset:
        cfg.paths.preset = args.preset
    if args.out_dir:
        cfg.paths.out_dir = args.out_dir
    if args.end_frame:
        cfg.frames.end_frame = args.end_frame
    cfg.io.save_workspace = bool(args.out_dir)
    return cfg


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="sphynx-analyze")
    parser.add_argument("--dlc", default="", help="DLC csv path")
    parser.add_argument("--preset", default="", help="Preset .mat path")
    parser.add_argument("--config", default="", help="Optional TOML config")
    parser.add_argument("--out-dir", dest="out_dir", default="", help="Output dir")
    parser.add_argument("--end-frame", dest="end_frame", type=int, default=0,
                        help="Last frame to analyze (0 = all)")
    args = parser.parse_args(argv)

    cfg = build_config(args)
    if not cfg.paths.dlc or not cfg.paths.preset:
        parser.error("both --dlc and --preset (or a config providing them) are required")

    try:
        result = analyze_session(cfg)
    except SphynxError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    print(f"Session: {result.n_frames} frames, {len(result.body_parts_names)} parts")
    print(f"{'act':14s} {'count':>6s} {'percent':>8s} {'duration_s':>11s} {'distance_cm':>12s}")
    for a in result.acts:
        s = a.stats
        print(f"{a.name:14s} {s.count:6d} {s.percent:8.2f} {s.duration_s:11.2f} {s.distance_cm:12.1f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
