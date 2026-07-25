import pandas as pd
import pytest

from sphynx.pipeline.super_table import build_super_table, SuperTable
from sphynx.exceptions import SphynxValueError


def _batch():
    a1 = {"name": "rest", "percent": 30, "duration": 180, "count": 8, "meantime": 22.5}
    a2 = {"name": "walk", "percent": 50, "duration": 300, "count": 12, "meantime": 25.0}
    a3 = {"name": "locomotion", "percent": 20, "duration": 120, "count": 4, "meantime": 30.0}
    return [
        {"session_name": "WNOF_J01_1D", "acts": [a1, a2, a3], "distance": 1500, "velocity": 2.5},
        {"session_name": "WNOF_J01_2D", "acts": [a1, a2, a3], "distance": 1700, "velocity": 2.8},
        {"session_name": "WNOF_J05_1D", "acts": [a1, a2, a3], "distance": 1300, "velocity": 2.2},
    ]


def test_tidy_has_row_per_act_metric_session():
    st = build_super_table(_batch())
    assert isinstance(st, SuperTable)
    assert len(st.tidy) == 36   # 3 sessions * 3 acts * 4 metrics


def test_wide_has_mouse_column_and_two_rows():
    st = build_super_table(_batch())
    assert "mouse" in st.wide.columns
    assert len(st.wide) == 2


def test_wide_has_act_metric_session_columns():
    cols = list(build_super_table(_batch()).wide.columns)
    assert "rest_percent_1D" in cols
    assert "walk_count_2D" in cols


def test_distance_velocity_columns():
    cols = list(build_super_table(_batch()).wide.columns)
    assert "distance_cm_1D" in cols
    assert "velocity_cm_per_s_1D" in cols


def test_nan_zero_policy():
    st = build_super_table(_batch(), nan_policy="zero")
    j05 = st.wide[st.wide["mouse"] == "J05"]
    assert j05["rest_percent_2D"].iloc[0] == 0


def test_custom_metadata_adds_group_line():
    meta = pd.DataFrame({
        "session_name": ["WNOF_J01_1D", "WNOF_J01_2D", "WNOF_J05_1D"],
        "mouse": ["J01", "J01", "J05"],
        "session": ["1D", "2D", "1D"],
        "group": ["control", "control", "test"],
        "line": ["C57Bl6", "C57Bl6", "C57Bl6"],
    })
    st = build_super_table(_batch(), metadata=meta)
    assert "group" in st.wide.columns
    assert "line" in st.wide.columns


def test_invalid_nan_policy_raises():
    with pytest.raises(SphynxValueError):
        build_super_table(_batch(), nan_policy="bogus")
