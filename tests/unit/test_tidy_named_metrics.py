import math

import numpy as np
import pandas as pd

from sphynx.acts.stats import act_stats
from sphynx.metrics.registry import MetricResults
from sphynx.pipeline.analyze import SessionAct
from sphynx.pipeline.batch import run_batch


class _Res:
    def __init__(self, metrics=None):
        mask = np.zeros(10)
        mask[2:6] = 1
        self.acts = [SessionAct("rest", mask, "builtin", act_stats(mask, 10.0))]
        self.metrics = metrics


def _spec(name="a"):
    return {"session_name": name, "mouse": "A", "trial": "1D"}


def _tidy(metrics):
    return run_batch([_spec()], preloaded=[_Res(metrics)]).tidy


def test_act_statistics_are_still_there():
    tidy = _tidy(None)
    acts = tidy[tidy["metric_kind"] == "act_stat"]
    assert set(acts["metric"]) >= {"ActPercent", "ActNumber", "ActDuration"}
    assert (acts["act_name"] == "rest").all()


def test_named_metrics_get_their_own_rows():
    tidy = _tidy(MetricResults(values={"path_length": 12.5, "mean_speed": 3.0}))
    named = tidy[tidy["metric_kind"] == "named"]
    assert set(named["metric"]) == {"path_length", "mean_speed"}
    assert float(named[named["metric"] == "path_length"]["value"].iloc[0]) == 12.5


def test_a_failed_metric_exports_as_nan_with_its_reason():
    tidy = _tidy(MetricResults(values={}, errors={"primary_errors": "no target"}))
    row = tidy[tidy["metric"] == "primary_errors"].iloc[0]
    assert math.isnan(float(row["value"]))
    assert "no target" in row["error"]
    assert row["metric_kind"] == "named"


def test_a_non_numeric_metric_value_survives():
    # visit_order is a list of holes and search_strategy a word; dropping them
    # would silently lose a result.
    tidy = _tidy(MetricResults(values={"search_strategy": "serial",
                                       "visit_order": ["h3", "h1"]}))
    values = dict(zip(tidy["metric"], tidy["value"]))
    assert values["search_strategy"] == "serial"
    assert values["visit_order"] == ["h3", "h1"]


def test_the_error_column_is_empty_for_a_good_row():
    tidy = _tidy(MetricResults(values={"path_length": 1.0}))
    assert (tidy["error"] == "").all()


def test_no_metrics_object_means_no_named_rows():
    tidy = _tidy(None)
    assert (tidy["metric_kind"] == "act_stat").all()


def test_the_columns_are_stable():
    tidy = _tidy(MetricResults(values={"path_length": 1.0}))
    assert list(tidy.columns) == [
        "session_name", "mouse", "group", "line", "trial",
        "metric_kind", "act_name", "metric", "value", "error"]


def test_named_rows_carry_the_session_metadata():
    tidy = _tidy(MetricResults(values={"path_length": 1.0}))
    row = tidy[tidy["metric_kind"] == "named"].iloc[0]
    assert row["mouse"] == "A"
    assert row["trial"] == "1D"
    assert row["act_name"] == ""


def test_two_sessions_of_one_mouse_and_day_do_not_overwrite_each_other():
    # S4c2 review (C1): the wide pivot wrote both into one cell and the last
    # silently won -- which DeepLabCut's raw and _filtered exports of one video
    # produce routinely.
    specs = [{"session_name": "raw", "mouse": "A", "trial": "1D"},
             {"session_name": "filtered", "mouse": "A", "trial": "1D"}]
    out = run_batch(specs, preloaded=[_Res(), _Res()])
    assert out.wide_row_key == "session_name"
    assert len(out.wide) == 2
    assert set(out.wide["session_name"]) == {"raw", "filtered"}


def test_one_row_per_mouse_when_nothing_clashes():
    specs = [{"session_name": "a", "mouse": "A", "trial": "1D"},
             {"session_name": "b", "mouse": "A", "trial": "2D"}]
    out = run_batch(specs, preloaded=[_Res(), _Res()])
    assert out.wide_row_key == "mouse"
    assert len(out.wide) == 1
