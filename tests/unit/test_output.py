import numpy as np
import pandas as pd
import pytest

from sphynx.exceptions import SphynxIOError
from sphynx.pipeline.output import (
    OutputSelection, available_columns, export_tables, filter_tidy,
    wide_column_count,
)


def _tidy():
    return pd.DataFrame([
        {"session_name": "a", "mouse": "A", "group": "", "line": "",
         "trial": "1D", "metric_kind": "act_stat", "act_name": "rest",
         "metric": "ActPercent", "value": 10.0, "error": ""},
        {"session_name": "a", "mouse": "A", "group": "", "line": "",
         "trial": "1D", "metric_kind": "act_stat", "act_name": "rest",
         "metric": "ActNumber", "value": 3, "error": ""},
        {"session_name": "a", "mouse": "A", "group": "", "line": "",
         "trial": "1D", "metric_kind": "act_stat", "act_name": "walk",
         "metric": "ActPercent", "value": 20.0, "error": ""},
        {"session_name": "a", "mouse": "A", "group": "", "line": "",
         "trial": "1D", "metric_kind": "named", "act_name": "",
         "metric": "path_length", "value": 120.0, "error": ""},
    ])


def test_available_columns_lists_what_the_run_produced():
    got = available_columns(_tidy())
    assert got["acts"] == ["rest", "walk"]
    assert got["act_stats"] == ["ActNumber", "ActPercent"]
    assert got["named_metrics"] == ["path_length"]


def test_an_empty_selection_means_everything():
    tidy = _tidy()
    assert len(filter_tidy(tidy, OutputSelection())) == len(tidy)


def test_selecting_acts_filters_rows():
    got = filter_tidy(_tidy(), OutputSelection(acts=["rest"]))
    assert set(got[got["metric_kind"] == "act_stat"]["act_name"]) == {"rest"}


def test_selecting_stats_filters_rows():
    got = filter_tidy(_tidy(), OutputSelection(act_stats=["ActPercent"]))
    stats = got[got["metric_kind"] == "act_stat"]
    assert set(stats["metric"]) == {"ActPercent"}


def test_selecting_named_metrics_filters_them():
    got = filter_tidy(_tidy(), OutputSelection(named_metrics=["nothing"]))
    assert got[got["metric_kind"] == "named"].empty


def test_act_selection_does_not_drop_named_metrics():
    # The three lists are independent: narrowing the acts must not silently
    # remove the paradigm metrics as well.
    got = filter_tidy(_tidy(), OutputSelection(acts=["rest"]))
    assert not got[got["metric_kind"] == "named"].empty


def test_wide_column_count_reflects_the_selection():
    tidy = _tidy()
    assert wide_column_count(tidy, OutputSelection()) == 4
    assert wide_column_count(tidy, OutputSelection(acts=["rest"])) == 3


def test_csv_export_writes_both_tables(tmp_path):
    written = export_tables(_tidy(), pd.DataFrame({"mouse": ["A"]}),
                            tmp_path / "out.csv")
    assert len(written) == 2
    assert (tmp_path / "out_tidy.csv").is_file()
    assert (tmp_path / "out_wide.csv").is_file()


def test_csv_export_keeps_the_error_column(tmp_path):
    tidy = _tidy()
    tidy.loc[0, "error"] = "no target"
    export_tables(tidy, pd.DataFrame(), tmp_path / "out.csv")
    text = (tmp_path / "out_tidy.csv").read_text(encoding="utf-8")
    assert "no target" in text


def test_unknown_format_raises(tmp_path):
    with pytest.raises(SphynxIOError):
        export_tables(_tidy(), pd.DataFrame(), tmp_path / "out.xyz", fmt="xyz")


def test_excel_without_a_writer_says_which_package(tmp_path, monkeypatch):
    import sphynx.pipeline.output as output_module

    monkeypatch.setattr(output_module, "_excel_writer_available",
                        lambda: False)
    with pytest.raises(SphynxIOError) as exc:
        export_tables(_tidy(), pd.DataFrame(), tmp_path / "out.xlsx",
                      fmt="excel")
    assert "openpyxl" in str(exc.value)
