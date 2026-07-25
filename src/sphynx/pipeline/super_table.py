"""Reshape a batch of session results into a wide, Prism-friendly table.
Port of sphynx.pipeline.buildSuperTable (pandas)."""

from __future__ import annotations

import re
from dataclasses import dataclass

import numpy as np
import pandas as pd

from sphynx.exceptions import SphynxValueError

_DEFAULT_PATTERN = r"^(?P<exp>[^_]+)_(?P<mouse>[^_]+)_(?P<session>.+)$"


@dataclass
class SuperTable:
    wide: pd.DataFrame
    tidy: pd.DataFrame
    meta: pd.DataFrame
    acts: list


def _parse_metadata(session_names, pattern):
    rows = []
    for sn in session_names:
        m = re.match(pattern, sn)
        mouse = m.group("mouse") if (m and "mouse" in m.groupdict()) else sn
        session = m.group("session") if (m and "session" in m.groupdict()) else ""
        rows.append({"session_name": sn, "mouse": mouse, "session": session})
    return pd.DataFrame(rows)


def build_super_table(
    batch_results, metadata=None,
    metrics=("percent", "duration", "count", "meantime"),
    nan_policy: str = "keep", name_pattern: str = _DEFAULT_PATTERN,
    general_distance_unit: str = "cm",
) -> SuperTable:
    if nan_policy not in ("keep", "zero"):
        raise SphynxValueError(f"nan_policy must be keep|zero; got {nan_policy}")

    session_names = [b["session_name"] for b in batch_results]
    if metadata is None:
        meta = _parse_metadata(session_names, name_pattern)
    else:
        meta = metadata.copy()
    by_name = {r["session_name"]: r for _, r in meta.iterrows()}

    act_names: list = []
    for b in batch_results:
        for a in b["acts"]:
            if a["name"] not in act_names:
                act_names.append(a["name"])

    # --- tidy (long) ---
    tidy_rows = []
    for b in batch_results:
        mr = by_name.get(b["session_name"], {"mouse": b["session_name"], "session": ""})
        for a in b["acts"]:
            for mt in metrics:
                tidy_rows.append({
                    "mouse": mr["mouse"], "session": mr["session"],
                    "act": a["name"], "metric": mt, "value": a.get(mt, np.nan),
                })
    tidy = pd.DataFrame(tidy_rows, columns=["mouse", "session", "act", "metric", "value"])

    # --- wide (pivot) ---
    sessions = list(dict.fromkeys(meta["session"]))
    mice = list(dict.fromkeys(meta["mouse"]))
    wide = pd.DataFrame({"mouse": mice})

    for col in meta.columns:
        if col in ("session_name", "mouse", "session"):
            continue
        first = {}
        for _, r in meta.iterrows():
            first.setdefault(r["mouse"], r[col])
        wide[col] = wide["mouse"].map(first)

    # act_metric_session value lookup
    lut = {(r.mouse, r.session, r.act, r.metric): r.value for r in tidy.itertuples()}
    for act in act_names:
        for mt in metrics:
            for sess in sessions:
                wide[f"{act}_{mt}_{sess}"] = [
                    lut.get((mo, sess, act, mt), np.nan) for mo in mice
                ]

    # per-session distance / velocity
    scal = {}
    for b in batch_results:
        mr = by_name.get(b["session_name"], {"mouse": b["session_name"], "session": ""})
        scal[(mr["mouse"], mr["session"])] = (b.get("distance", np.nan), b.get("velocity", np.nan))
    # TODO(polish): MATLAB rounds distance (cm->int, m->2dp) and velocity->1dp
    # in the wide table for Prism display. Values here are exact; parity-cosmetic.
    dscale = 0.01 if general_distance_unit.lower() == "m" else 1.0
    for sess in sessions:
        dcol = f"distance_{general_distance_unit}_{sess}"
        vcol = f"velocity_cm_per_s_{sess}"
        wide[dcol] = [
            (scal[(mo, sess)][0] * dscale) if (mo, sess) in scal else np.nan for mo in mice
        ]
        wide[vcol] = [scal[(mo, sess)][1] if (mo, sess) in scal else np.nan for mo in mice]

    if nan_policy == "zero":
        num_cols = wide.select_dtypes(include="number").columns
        wide[num_cols] = wide[num_cols].fillna(0)

    return SuperTable(wide=wide, tidy=tidy, meta=meta, acts=act_names)
