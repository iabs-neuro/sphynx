"""Choose what goes into the output tables and write them out (S4c2).

An empty selection list means EVERYTHING rather than nothing -- a fresh project
should export what it measured, not an empty file. The three lists are
independent, so narrowing the acts never removes the paradigm's named metrics.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import pandas as pd

from sphynx.exceptions import SphynxIOError

ACT_STAT, NAMED = "act_stat", "named"


@dataclass
class OutputSelection:
    acts: list = field(default_factory=list)            # empty = all
    act_stats: list = field(default_factory=list)       # empty = all
    named_metrics: list = field(default_factory=list)   # empty = all


def available_columns(tidy) -> dict:
    if tidy is None or tidy.empty:
        return {"acts": [], "act_stats": [], "named_metrics": []}
    stats = tidy[tidy["metric_kind"] == ACT_STAT]
    named = tidy[tidy["metric_kind"] == NAMED]
    return {
        "acts": sorted(set(stats["act_name"])),
        "act_stats": sorted(set(stats["metric"])),
        "named_metrics": sorted(set(named["metric"])),
    }


def filter_tidy(tidy, selection: OutputSelection):
    if tidy is None or tidy.empty:
        return tidy
    is_stat = tidy["metric_kind"] == ACT_STAT
    keep_stat = is_stat.copy()
    if selection.acts:
        keep_stat &= tidy["act_name"].isin(selection.acts)
    if selection.act_stats:
        keep_stat &= tidy["metric"].isin(selection.act_stats)

    keep_named = tidy["metric_kind"] == NAMED
    if selection.named_metrics:
        keep_named &= tidy["metric"].isin(selection.named_metrics)

    return tidy[keep_stat | keep_named].reset_index(drop=True)


def wide_column_count(tidy, selection: OutputSelection) -> int:
    """How many value columns the wide table would carry."""
    kept = filter_tidy(tidy, selection)
    if kept is None or kept.empty:
        return 0
    keys = kept.apply(
        lambda r: (f"{r['act_name']}_{r['metric']}" if r["act_name"]
                   else str(r["metric"])), axis=1)
    if (kept["trial"] != "").any():
        keys = keys + "_" + kept["trial"]
    return len(set(keys))


def _excel_writer_available() -> bool:
    try:
        import openpyxl  # noqa: F401
    except ImportError:
        return False
    return True


def export_tables(tidy, wide, path, fmt: str = "csv") -> list:
    """Write both tables. Returns the paths written."""
    target = Path(path)
    fmt = str(fmt).lower()
    if fmt not in ("csv", "excel"):
        raise SphynxIOError(f"unknown export format {fmt!r}; use csv or excel")

    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        if fmt == "csv":
            tidy_path = target.with_name(f"{target.stem}_tidy.csv")
            wide_path = target.with_name(f"{target.stem}_wide.csv")
            (tidy if tidy is not None else pd.DataFrame()).to_csv(
                tidy_path, index=False)
            (wide if wide is not None else pd.DataFrame()).to_csv(
                wide_path, index=False)
            return [str(tidy_path), str(wide_path)]

        if not _excel_writer_available():
            # Writing a CSV under an .xlsx name instead would be a quiet
            # substitution of one format for another.
            raise SphynxIOError(
                "writing Excel needs the openpyxl package; install it or "
                "export CSV instead")
        with pd.ExcelWriter(target) as writer:
            (tidy if tidy is not None else pd.DataFrame()).to_excel(
                writer, sheet_name="tidy", index=False)
            (wide if wide is not None else pd.DataFrame()).to_excel(
                writer, sheet_name="wide", index=False)
        return [str(target)]
    except OSError as e:
        raise SphynxIOError(f"cannot write {target}: {e}") from e
