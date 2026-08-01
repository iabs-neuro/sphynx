"""Run analyze_session over many sessions and aggregate into tidy/wide tables.

Port of sphynx.pipeline.runBatch (matlab/+sphynx/+pipeline/runBatch.m). Tidy-first:
one row per (session, act, metric); the wide pivot is one row per mouse with
one column per (act, metric[, trial]).
"""

from __future__ import annotations

import copy
from dataclasses import dataclass, field

import numpy as np
import pandas as pd

from sphynx.config import Config
from sphynx.exceptions import SphynxError, SphynxValueError
from sphynx.logging_setup import get_logger
from sphynx.pipeline.analyze import analyze_session

_log = get_logger()

# MATLAB metric label -> ActStats attribute.
_METRIC_ATTR = {
    "ActPercent": "percent",
    "ActNumber": "count",
    "ActMeanTime": "mean_time",
    "ActMedianTime": "median_time",
    "ActDuration": "duration_s",
    "ActVelocity": "velocity",
    "Distance": "distance_cm",
    "ActMeanDistance": "mean_distance_cm",
}


@dataclass
class BatchResult:
    results: list
    tidy: pd.DataFrame
    wide: pd.DataFrame
    errors: dict = field(default_factory=dict)


def _spec_get(spec, name, default=""):
    v = spec.get(name, default)
    return default if v is None else v


def _build_tidy(specs, results) -> pd.DataFrame:
    rows = []
    for spec, result in zip(specs, results):
        for act in result.acts:
            for label, attr in _METRIC_ATTR.items():
                value = getattr(act.stats, attr, None) if act.stats is not None else None
                rows.append({
                    "session_name": str(_spec_get(spec, "session_name")),
                    "mouse": str(_spec_get(spec, "mouse")),
                    "group": str(_spec_get(spec, "group")),
                    "line": str(_spec_get(spec, "line")),
                    "trial": str(_spec_get(spec, "trial")),
                    "act_name": str(act.name),
                    "metric": label,
                    "value": np.nan if value is None else value,
                })
    return pd.DataFrame(rows, columns=[
        "session_name", "mouse", "group", "line", "trial",
        "act_name", "metric", "value",
    ])


def _tidy_to_wide(tidy: pd.DataFrame) -> pd.DataFrame:
    if tidy.empty:
        return pd.DataFrame()
    keys = tidy["act_name"] + "_" + tidy["metric"]
    if (tidy["trial"] != "").any():
        keys = keys + "_" + tidy["trial"]
    t = tidy.assign(col_key=keys)
    mice = list(dict.fromkeys(t["mouse"]))
    cols = list(dict.fromkeys(t["col_key"]))
    data = {c: [np.nan] * len(mice) for c in cols}
    mouse_idx = {m: i for i, m in enumerate(mice)}
    for r in t.itertuples():
        data[r.col_key][mouse_idx[r.mouse]] = r.value
    # Built in one go: adding a column at a time fragments the frame, which
    # pandas warns about once per column on a real batch.
    return pd.concat(
        [pd.DataFrame({"mouse": mice}), pd.DataFrame(data, columns=list(cols))],
        axis=1)


def run_batch(specs, config: Config | None = None, out_dir: str = "", preloaded=None,
              paradigm=None, library=None, on_progress=None,
              continue_on_error: bool = False) -> BatchResult:
    """Run every spec through analyze_session (or use `preloaded`) and aggregate.

    `specs` is a list of dicts. Recognised keys: session_name (required),
    dlc_path, preset_path, mouse, group, line, trial. With
    `continue_on_error` a session that fails is RECORDED in `errors` and the
    rest of the batch proceeds -- one unreadable file should not cost a
    twelve-session run."""
    n = len(specs)
    errors: dict = {}
    if preloaded is not None:
        if len(preloaded) != n:
            raise SphynxValueError(
                f"preloaded length {len(preloaded)} != specs length {n}"
            )
        results = list(preloaded)
        kept_specs = list(specs)
    else:
        results = []
        kept_specs = []
        base = config if config is not None else Config.default()
        for k, spec in enumerate(specs):
            name = str(_spec_get(spec, "session_name"))
            if on_progress is not None:
                on_progress(k + 1, n, name)
            cfg = copy.deepcopy(base)
            cfg.paths.dlc = _spec_get(spec, "dlc_path")
            cfg.paths.preset = _spec_get(spec, "preset_path")
            if out_dir:
                cfg.paths.out_dir = out_dir
                cfg.io.save_workspace = True
                cfg.io.session_name = name
            else:
                cfg.io.save_workspace = False
            _log.info("Batch %d/%d: %s", k + 1, n, name)
            try:
                results.append(analyze_session(cfg, paradigm=paradigm,
                                               library=library))
            except SphynxError as e:
                if not continue_on_error:
                    raise
                errors[name] = str(e)
                _log.warning("Session %s failed: %s", name, e)
                continue
            kept_specs.append(spec)

    tidy = _build_tidy(kept_specs, results)
    wide = _tidy_to_wide(tidy)
    return BatchResult(results=results, tidy=tidy, wide=wide, errors=errors)
