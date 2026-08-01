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
    # Session name per entry of `results`, same order. Deriving the names from
    # the tidy table instead loses any session that produced no acts and shifts
    # every later row onto the wrong result.
    session_names: list = field(default_factory=list)
    stopped: bool = False


def _spec_get(spec, name, default=""):
    v = spec.get(name, default)
    return default if v is None else v


def _build_tidy(specs, results) -> pd.DataFrame:
    """One row per measurement.

    Two sources: the per-act statistics, and the paradigm's NAMED metrics --
    which reached no export at all before, so every Barnes metric was
    unexportable. A metric that could not be computed still gets a row, with
    NaN and the reason, because a blank cell cannot be told apart from a
    measured zero."""
    rows = []
    for spec, result in zip(specs, results):
        common = {
            "session_name": str(_spec_get(spec, "session_name")),
            "mouse": str(_spec_get(spec, "mouse")),
            "group": str(_spec_get(spec, "group")),
            "line": str(_spec_get(spec, "line")),
            "trial": str(_spec_get(spec, "trial")),
        }
        for act in result.acts:
            for label, attr in _METRIC_ATTR.items():
                value = getattr(act.stats, attr, None) if act.stats is not None else None
                rows.append({**common, "metric_kind": "act_stat",
                             "act_name": str(act.name), "metric": label,
                             "value": np.nan if value is None else value,
                             "error": ""})

        metrics = getattr(result, "metrics", None)
        if metrics is None:
            continue
        for name, value in getattr(metrics, "values", {}).items():
            rows.append({**common, "metric_kind": "named", "act_name": "",
                         "metric": str(name), "value": value, "error": ""})
        for name, message in getattr(metrics, "errors", {}).items():
            rows.append({**common, "metric_kind": "named", "act_name": "",
                         "metric": str(name), "value": np.nan,
                         "error": str(message)})

    return pd.DataFrame(rows, columns=[
        "session_name", "mouse", "group", "line", "trial",
        "metric_kind", "act_name", "metric", "value", "error",
    ])


def _tidy_to_wide(tidy: pd.DataFrame) -> pd.DataFrame:
    if tidy.empty:
        return pd.DataFrame()
    keys = tidy.apply(
        lambda r: (f"{r['act_name']}_{r['metric']}" if r["act_name"]
                   else str(r["metric"])), axis=1)
    if (tidy["trial"] != "").any():
        keys = keys + "_" + tidy["trial"]
    t = tidy.assign(col_key=keys)
    # Without a mouse the sessions would all share one key and overwrite each
    # other, so fall back to the session name.
    t = t.assign(row_key=t["mouse"].where(t["mouse"] != "", t["session_name"]))
    mice = list(dict.fromkeys(t["row_key"]))
    cols = list(dict.fromkeys(t["col_key"]))
    data = {c: [np.nan] * len(mice) for c in cols}
    mouse_idx = {m: i for i, m in enumerate(mice)}
    for r in t.itertuples():
        data[r.col_key][mouse_idx[r.row_key]] = r.value
    # Built in one go: adding a column at a time fragments the frame, which
    # pandas warns about once per column on a real batch.
    return pd.concat(
        [pd.DataFrame({"mouse": mice}), pd.DataFrame(data, columns=list(cols))],
        axis=1)


def run_batch(specs, config: Config | None = None, out_dir: str = "", preloaded=None,
              paradigm=None, library=None, on_progress=None,
              continue_on_error: bool = False, should_stop=None) -> BatchResult:
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
        names = [str(_spec_get(s, "session_name")) for s in specs]
        stopped = False
    else:
        results = []
        kept_specs = []
        names = []
        stopped = False
        base = config if config is not None else Config.default()
        for k, spec in enumerate(specs):
            # Checked before every session, so Cancel stops the run rather than
            # only the queue that was built before it started.
            if should_stop is not None and should_stop():
                stopped = True
                break
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
            except Exception as e:      # noqa: BLE001 - a bug in one session
                if not continue_on_error:
                    raise
                errors[name] = f"unexpected {type(e).__name__}: {e}"
                _log.error("Session %s raised %s: %s", name, type(e).__name__, e)
                continue
            kept_specs.append(spec)
            names.append(name)

    tidy = _build_tidy(kept_specs, results)
    wide = _tidy_to_wide(tidy)
    return BatchResult(results=results, tidy=tidy, wide=wide, errors=errors,
                       session_names=names, stopped=stopped)
